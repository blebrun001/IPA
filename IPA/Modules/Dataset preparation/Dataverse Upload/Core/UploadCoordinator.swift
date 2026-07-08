//  Core orchestration layer that uploads files to Dataverse, refreshes the
//  remote index to avoid duplicates, and drives retries across direct and
//  multipart strategies while reporting progress to the UI.
import Foundation

/// Orchestrates uploads against the Dataverse API with duplicate detection and retry policies.
final class UploadCoordinator {
    private let client: DVClient
    private let settings: any SettingsProviding

    init(client: DVClient,
         settings: any SettingsProviding) {
        self.client = client
        self.settings = settings
    }

    /// Upload the provided items, logging progress and applying the configured retry strategy.
    func uploadItems(_ items: [UploadItem],
                     log: @escaping (String) -> Void,
                     progress: @escaping (String) -> Void,
                     byteProgress: @escaping (String) -> Void) async throws {
        let filter = RegexFilter(pattern: settings.excludeRegex)
        let policy = UploadRetryPolicy(
            maxAttempts: settings.resumeOnFailure ? settings.maxRetryAttempts : 1,
            baseBackoff: Double(settings.initialBackoffSeconds)
        )
        let persistentId = settings.persistentId
        let allURLs = try SecurityScopedAccess.resolveURLs(for: items)
        defer { SecurityScopedAccess.stopAccess(to: allURLs) }

        let existingFiles = try await client.listDraftFiles(persistentId: persistentId)
        let duplicateIndex = DataverseDuplicateIndex(files: existingFiles)
        let refreshPolicy = DataverseIndexRefreshPolicy(
            interval: TimeInterval(settings.indexRefreshIntervalSeconds),
            everyFiles: max(1, settings.indexRefreshEveryNFiles)
        )

        let files = Self.uniqueFiles(from: allURLs)
        var progressIndex = 0

        for file in files {
            defer { refreshPolicy.recordProcessedFile() }
            if !filter.accepts(file) {
                log("Ignored by regex: \(file.path)")
                continue
            }

            var uploadFile = try await makeUploadFile(file,
                                                      baseCandidates: allURLs,
                                                      duplicateIndex: duplicateIndex,
                                                      log: log)
            progressIndex += 1
            progress("File \(progressIndex)/\(files.count)")

            if settings.useDirectUpload {
                try await uploadDirectWithRetry(uploadFile,
                                                persistentId: persistentId,
                                                duplicateIndex: duplicateIndex,
                                                refreshPolicy: refreshPolicy,
                                                retryPolicy: policy,
                                                log: log,
                                                byteProgress: byteProgress)
            } else {
                try await uploadMultipartWithRetry(&uploadFile,
                                                   persistentId: persistentId,
                                                   duplicateIndex: duplicateIndex,
                                                   refreshPolicy: refreshPolicy,
                                                   retryPolicy: policy,
                                                   log: log,
                                                   byteProgress: byteProgress,
                                                   mode: .multipartOnly)
            }
        }
    }

    private static func uniqueFiles(from urls: [URL]) -> [URL] {
        let flat = FileSystem.flattenFiles(from: urls)
        let uniquePaths = Array(Set(flat.map { ($0.path as NSString).standardizingPath.lowercased() })).sorted()
        return uniquePaths.map { URL(fileURLWithPath: $0) }
    }

    private func makeUploadFile(_ file: URL,
                                baseCandidates: [URL],
                                duplicateIndex: DataverseDuplicateIndex,
                                log: @escaping (String) -> Void) async throws -> DataverseUploadFile {
        let attrs = try FileManager.default.attributesOfItem(atPath: file.path)
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        let rel = FileSystem.relativePath(baseCandidates: baseCandidates, file: file)
        let pathKey = DataverseDuplicateIndex.pathKey(directoryLabel: rel.directoryLabel,
                                                      filename: file.lastPathComponent)
        var checksum: String? = nil

        if settings.useChecksumForDuplicates && duplicateIndex.canMatchChecksums {
            checksum = await computeLocalChecksum(for: file, types: duplicateIndex.checksumTypesPresent, log: log)
        }

        return DataverseUploadFile(
            url: file,
            size: size,
            relativePath: rel,
            pathKey: pathKey,
            checksum: checksum,
            mime: MimeType.infer(url: file)
        )
    }

    private func uploadDirectWithRetry(_ file: DataverseUploadFile,
                                       persistentId: String,
                                       duplicateIndex: DataverseDuplicateIndex,
                                       refreshPolicy: DataverseIndexRefreshPolicy,
                                       retryPolicy: UploadRetryPolicy,
                                       log: @escaping (String) -> Void,
                                       byteProgress: @escaping (String) -> Void) async throws {
        var attempt = 0

        while attempt < retryPolicy.maxAttempts {
            try await refreshIndexIfNeeded(duplicateIndex, refreshPolicy: refreshPolicy, persistentId: persistentId, log: log)
            if logDuplicateIfPresent(file, duplicateIndex: duplicateIndex, log: log, context: "before upload") {
                return
            }

            do {
                try await uploadDirect(file, persistentId: persistentId, log: log)
                duplicateIndex.markUploaded(pathKey: file.pathKey, size: file.size)
                return
            } catch let e as DVError {
                if case .badStatusCode(404) = e {
                    log("Direct upload unavailable (404) → switching to multipart fallback…")
                    var fallback = file
                    try await uploadMultipartWithRetry(&fallback,
                                                       persistentId: persistentId,
                                                       duplicateIndex: duplicateIndex,
                                                       refreshPolicy: refreshPolicy,
                                                       retryPolicy: retryPolicy,
                                                       log: log,
                                                       byteProgress: byteProgress,
                                                       mode: .fallback)
                    return
                }
                throw e
            } catch {
                let action = try await handleUploadFailure(error,
                                                           attempt: &attempt,
                                                           retryPolicy: retryPolicy,
                                                           duplicateIndex: duplicateIndex,
                                                           refreshPolicy: refreshPolicy,
                                                           persistentId: persistentId,
                                                           file: file,
                                                           log: log,
                                                           retryMessage: "retry",
                                                           resumeMessage: "Resuming direct upload")
                if action == .retry {
                    continue
                }
                return
            }
        }
    }

    private func uploadDirect(_ file: DataverseUploadFile,
                              persistentId: String,
                              log: @escaping (String) -> Void) async throws {
        log("Init direct upload: \(file.url.lastPathComponent) (\(file.size) bytes)")
        let initResp = try await client.requestDirectUploadInit(
            persistentId: persistentId,
            fileSize: file.size,
            fileName: file.relativePath.fileName,
            mime: file.mime
        )

        guard let urlStr = initResp.data.url,
              let putURL = URL(string: urlStr) else {
            throw DVError.initDidNotReturnURL
        }

        log("PUT S3 → \(putURL.host ?? "")")

        try await client.putFileToS3(preSignedURL: putURL,
                                     headers: initResp.data.headers,
                                     fileURL: file.url)
        let payload = DVFinalizeRequest(
            storageIdentifier: initResp.data.storageIdentifier,
            fileName: file.relativePath.fileName,
            mimeType: file.mime,
            directoryLabel: file.relativePath.directoryLabel,
            description: nil
        )
        log("Finalizing Dataverse…")
        try await client.finalizeDirectUpload(persistentId: persistentId, payload: payload)

        log("✓ Completed (direct): \(file.relativePath.fullPath)")
    }

    private enum MultipartMode {
        case multipartOnly
        case fallback
    }

    private func uploadMultipartWithRetry(_ file: inout DataverseUploadFile,
                                          persistentId: String,
                                          duplicateIndex: DataverseDuplicateIndex,
                                          refreshPolicy: DataverseIndexRefreshPolicy,
                                          retryPolicy: UploadRetryPolicy,
                                          log: @escaping (String) -> Void,
                                          byteProgress: @escaping (String) -> Void,
                                          mode: MultipartMode) async throws {
        var attempt = 0

        while attempt < retryPolicy.maxAttempts {
            try await refreshIndexIfNeeded(duplicateIndex, refreshPolicy: refreshPolicy, persistentId: persistentId, log: log)
            let context = mode == .fallback ? "before upload (multipart fallback)" : "before upload"
            if logDuplicateIfPresent(file, duplicateIndex: duplicateIndex, log: log, context: context) {
                return
            }

            do {
                log("== Multipart upload == \(file.url.lastPathComponent)")
                if mode == .multipartOnly {
                    log("Uploading via server: \(file.url.lastPathComponent) (\(file.size) bytes)")
                }
                try await client.uploadMultipart(persistentId: persistentId,
                                                 fileURL: file.url,
                                                 directoryLabel: file.relativePath.directoryLabel,
                                                 log: log,
                                                 progress: byteProgress,
                                                 shouldCancel: { Task.isCancelled })
                log("✓ Completed (multipart): \(file.relativePath.fullPath)")
                duplicateIndex.markUploaded(pathKey: file.pathKey, size: file.size)
                return
            } catch {
                let retryMessage = mode == .fallback ? "multipart fallback retry" : "retry"
                let resumeMessage = mode == .fallback ? "Resuming multipart fallback" : "Resuming multipart upload"
                let action = try await handleUploadFailure(error,
                                                           attempt: &attempt,
                                                           retryPolicy: retryPolicy,
                                                           duplicateIndex: duplicateIndex,
                                                           refreshPolicy: refreshPolicy,
                                                           persistentId: persistentId,
                                                           file: file,
                                                           log: log,
                                                           retryMessage: retryMessage,
                                                           resumeMessage: resumeMessage)
                if action == .retry {
                    continue
                }
                return
            }
        }
    }

    private enum FailureAction {
        case retry
        case finished
    }

    private func handleUploadFailure(_ error: Error,
                                     attempt: inout Int,
                                     retryPolicy: UploadRetryPolicy,
                                     duplicateIndex: DataverseDuplicateIndex,
                                     refreshPolicy: DataverseIndexRefreshPolicy,
                                     persistentId: String,
                                     file: DataverseUploadFile,
                                     log: @escaping (String) -> Void,
                                     retryMessage: String,
                                     resumeMessage: String) async throws -> FailureAction {
        if let urlError = error as? URLError {
            guard retryPolicy.shouldRetry(urlError, attempt: attempt) else {
                log("Network error: code=\(urlError.code.rawValue)")
                throw urlError
            }
            attempt += 1
            log("Transient network error: code=\(urlError.code.rawValue), \(retryMessage) \(attempt)/\(retryPolicy.maxAttempts)…")
        } else if let posixError = error as? POSIXError {
            guard retryPolicy.shouldRetry(posixError, attempt: attempt) else {
                log("POSIX network error: code=\(posixError.code.rawValue)")
                throw posixError
            }
            attempt += 1
            log("Transient POSIX error: code=\(posixError.code.rawValue), \(retryMessage) \(attempt)/\(retryPolicy.maxAttempts)…")
        } else {
            attempt += 1
            if attempt >= retryPolicy.maxAttempts || !UploadRetryPolicy.isTransient(error) {
                throw error
            }
            log("Network error, retry \(attempt)/\(retryPolicy.maxAttempts)…")
        }

        try await refreshIndexIfNeeded(duplicateIndex, refreshPolicy: refreshPolicy, persistentId: persistentId, log: log, force: true)
        if logDuplicateIfPresent(file, duplicateIndex: duplicateIndex, log: log, context: "after network error") {
            return .finished
        }

        await retryPolicy.sleep(attempt: attempt)
        log("\(resumeMessage), attempt \(attempt)/\(retryPolicy.maxAttempts)…")
        return .retry
    }

    private func refreshIndexIfNeeded(_ duplicateIndex: DataverseDuplicateIndex,
                                      refreshPolicy: DataverseIndexRefreshPolicy,
                                      persistentId: String,
                                      log: @escaping (String) -> Void,
                                      force: Bool = false) async throws {
        guard refreshPolicy.shouldRefresh(force: force) else { return }
        do {
            let refreshed = try await client.listDraftFiles(persistentId: persistentId)
            duplicateIndex.replace(with: refreshed)
            refreshPolicy.recordRefresh()
        } catch {
            log("⚠️ Failed to refresh remote index: \(error.localizedDescription)")
            refreshPolicy.recordRefresh()
        }
    }

    private func logDuplicateIfPresent(_ file: DataverseUploadFile,
                                       duplicateIndex: DataverseDuplicateIndex,
                                       log: @escaping (String) -> Void,
                                       context: String) -> Bool {
        let match = duplicateIndex.match(pathKey: file.pathKey, size: file.size, checksum: file.checksum)
        guard match != .none else { return false }

        let reason = match == .pathAndSize ? "path+size" : "path+checksum"
        log("✓ Already present \(context) (\(reason)), skipping: \(file.relativePath.fullPath)")
        return true
    }

    /// Compute a checksum using whichever algorithms the server already exposes.
    private func computeLocalChecksum(for url: URL, types: Set<String>, log: @escaping (String) -> Void) async -> String? {
        let lowered = types.map { $0.lowercased() }
        do {
            if lowered.contains("md5") {
                return try FileHasher.md5(of: url)
            } else if lowered.contains("sha-256") || lowered.contains("sha256") {
                return try FileHasher.sha256(of: url)
            } else if lowered.contains("sha-1") || lowered.contains("sha1") {
                return try FileHasher.sha1(of: url)
            }
        } catch {
            log("⚠️ Failed to compute local checksum: \(error.localizedDescription)")
        }
        return nil
    }
}

private struct DataverseUploadFile {
    let url: URL
    let size: Int64
    let relativePath: (directoryLabel: String?, fileName: String, fullPath: String)
    let pathKey: String
    let checksum: String?
    let mime: String?
}
