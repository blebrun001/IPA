//  Core orchestration layer that uploads files to Dataverse, refreshes the
//  remote index to avoid duplicates, and drives retries across direct and
//  multipart strategies while reporting progress to the UI.
import Foundation
import UniformTypeIdentifiers

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
        let maxAttemptsSetting = settings.maxRetryAttempts
        let baseBackoff = Double(settings.initialBackoffSeconds)
        let resume = settings.resumeOnFailure
        let useDirectUpload = settings.useDirectUpload
        let refreshInterval: TimeInterval = TimeInterval(settings.indexRefreshIntervalSeconds)
        let refreshEveryFiles = max(1, settings.indexRefreshEveryNFiles)
        let persistentId = settings.persistentId

        let allURLs = try SecurityScopedAccess.resolveURLs(for: items)

        // Build an index of existing draft files (case-insensitive) to aggressively skip duplicates.
        let existingFiles = try await client.listDraftFiles(persistentId: persistentId)
        var existingByPathAndSize = Set<String>()
        var existingByPathAndChecksum = Set<String>()
        var checksumTypesPresent = Set<String>()
        for e in existingFiles {
            let name = e.filename.lowercased()
            let dir = (e.directoryLabel ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
            let pathKey = dir.isEmpty ? name : "\(dir)/\(name)"
            if let sz = e.filesize { existingByPathAndSize.insert("\(pathKey)|\(sz)") }
            if let ck = e.checksum, !ck.isEmpty { existingByPathAndChecksum.insert("\(pathKey)|\(ck.lowercased())") }
            if let t = e.checksumType?.lowercased(), !t.isEmpty { checksumTypesPresent.insert(t) }
        }

        // Periodic index refresh to reflect new files uploaded from this or another client.
        var lastIndexRefresh = Date()
        var processedSinceRefresh = 0

        enum DuplicateMatch { case none, pathAndSize, pathAndChecksum }
        // Lookup helper that checks if a path is already present based on size or checksum.
        @inline(__always) func matchInIndex(pathKey: String, size: Int64, checksum: String?) -> DuplicateMatch {
            let key = pathKey.lowercased()
            if existingByPathAndSize.contains("\(key)|\(size)") { return .pathAndSize }
            if let c = checksum?.lowercased(), existingByPathAndChecksum.contains("\(key)|\(c)") { return .pathAndChecksum }
            return .none
        }

        // Refresh the cached server index if enough time or files have elapsed.
        func refreshIndexIfNeeded(force: Bool = false) async {
            let shouldRefresh = force || Date().timeIntervalSince(lastIndexRefresh) > refreshInterval || processedSinceRefresh >= refreshEveryFiles
            guard shouldRefresh else { return }
            do {
                let refreshed = try await client.listDraftFiles(persistentId: persistentId)
                existingByPathAndSize.removeAll(keepingCapacity: true)
                existingByPathAndChecksum.removeAll(keepingCapacity: true)
                for e in refreshed {
                    let name = e.filename.lowercased()
                    let dir = (e.directoryLabel ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
                    let pathKey = dir.isEmpty ? name : "\(dir)/\(name)"
                    if let sz = e.filesize { existingByPathAndSize.insert("\(pathKey)|\(sz)") }
                    if let ck = e.checksum, !ck.isEmpty { existingByPathAndChecksum.insert("\(pathKey)|\(ck.lowercased())") }
                }
                lastIndexRefresh = Date()
                processedSinceRefresh = 0
            } catch {
                log("⚠️ Failed to refresh remote index: \(error.localizedDescription)")
                lastIndexRefresh = Date()
                processedSinceRefresh = 0
            }
        }

        // Normalize the source URLs and deduplicate by path.
        let flat = FileSystem.flattenFiles(from: allURLs)
        let uniquePaths = Array(Set(flat.map { ($0.path as NSString).standardizingPath.lowercased() })).sorted()
        let files = uniquePaths.map { URL(fileURLWithPath: $0) }

        let total = files.count
        var index = 0

        for file in files {
            defer { processedSinceRefresh += 1 }
            if !filter.accepts(file) { log("Ignored by regex: \(file.path)"); continue }

            let filenameOnly = file.lastPathComponent
            let attrs = try FileManager.default.attributesOfItem(atPath: file.path)
            let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
            var checksum: String? = nil

            // Compute the Dataverse-friendly relative path once for reuse.
            let rel = FileSystem.relativePath(baseCandidates: allURLs, file: file)
            let dirLabel = rel.directoryLabel
            let fileName = rel.fileName
            let pathKeyLocal: String
            if let dir = rel.directoryLabel?.lowercased(), !dir.isEmpty {
                pathKeyLocal = "\(dir)/\(filenameOnly.lowercased())"
            } else {
                pathKeyLocal = filenameOnly.lowercased()
            }

            // Optionally compute the checksum so we can skip duplicates by hash as well as size.
            if settings.useChecksumForDuplicates && !existingByPathAndChecksum.isEmpty && !checksumTypesPresent.isEmpty {
                checksum = await computeLocalChecksum(for: file, types: checksumTypesPresent, log: log)
            }

            index += 1
            progress("File \(index)/\(total)")

            let mime = MimeType.infer(url: file)

            if !useDirectUpload {
                // Force the legacy multipart path (no direct upload attempt).
                var attempt = 0
                let maxAttempts = resume ? maxAttemptsSetting : 1
                while attempt < maxAttempts {
                    await refreshIndexIfNeeded()
                    let dup = matchInIndex(pathKey: pathKeyLocal, size: size, checksum: checksum)
                    if dup != .none {
                        let r = (dup == .pathAndSize ? "path+size" : "path+checksum")
                        log("✓ Already present before upload (\(r)), skipping: \(rel.fullPath)")
                        break
                    }
                    do {
                        log("== Multipart upload == \(file.lastPathComponent)")
                        log("Uploading via server: \(file.lastPathComponent) (\(size) bytes)")
                        try await client.uploadMultipart(persistentId: persistentId,
                                                         fileURL: file,
                                                         directoryLabel: dirLabel,
                                                         log: log,
                                                         progress: byteProgress,
                                                         shouldCancel: { Task.isCancelled })
                        log("✓ Completed (multipart): \(rel.fullPath)")
                        existingByPathAndSize.insert("\(pathKeyLocal)|\(size)")
                        break
                    } catch {
                        if let urlError = error as? URLError {
                            if UploadCoordinator.isTransient(urlError) && attempt < maxAttempts - 1 {
                                attempt += 1
                                log("Transient network error: code=\(urlError.code.rawValue), retry \(attempt)/\(maxAttempts)…")
                                await refreshIndexIfNeeded()
                                let dupA = matchInIndex(pathKey: pathKeyLocal, size: size, checksum: checksum)
                                if dupA != .none {
                                    let r = (dupA == .pathAndSize ? "path+size" : "path+checksum")
                                    log("✓ Already present after network error (\(r)), skipping: \(rel.fullPath)")
                                    break
                                }
                                await UploadCoordinator.backoffSleep(attempt: attempt, base: baseBackoff)
                                log("Resuming multipart upload, attempt \(attempt)/\(maxAttempts)…")
                                continue
                            } else {
                                log("Network error: code=\(urlError.code.rawValue)")
                                throw urlError
                            }
                        }
                        if let posixError = error as? POSIXError {
                            if UploadCoordinator.isTransient(posixError) && attempt < maxAttempts - 1 {
                                attempt += 1
                                log("Transient POSIX error: code=\(posixError.code.rawValue), retry \(attempt)/\(maxAttempts)…")
                                await refreshIndexIfNeeded()
                                let dupB = matchInIndex(pathKey: pathKeyLocal, size: size, checksum: checksum)
                                if dupB != .none {
                                    let r = (dupB == .pathAndSize ? "path+size" : "path+checksum")
                                    log("✓ Already present after network error (\(r)), skipping: \(rel.fullPath)")
                                    break
                                }
                                await UploadCoordinator.backoffSleep(attempt: attempt)
                                log("Resuming multipart upload, attempt \(attempt)/\(maxAttempts)…")
                                continue
                            } else {
                                log("POSIX network error: code=\(posixError.code.rawValue)")
                                throw posixError
                            }
                        }
                        attempt += 1
                        await refreshIndexIfNeeded()
                        let dupC = matchInIndex(pathKey: pathKeyLocal, size: size, checksum: checksum)
                        if dupC != .none {
                            let r = (dupC == .pathAndSize ? "path+size" : "path+checksum")
                            log("✓ Already present after network error (\(r)), skipping: \(rel.fullPath)")
                            break
                        }
                        if attempt >= maxAttempts || !UploadCoordinator.isTransient(error) {
                            throw error
                        }
                        log("Network error, retry \(attempt)/\(maxAttempts)…")
                        await UploadCoordinator.backoffSleep(attempt: attempt, base: baseBackoff)
                    }
                }
                continue
            }

            // Try direct upload first, then fall back to multipart on a 404.
            do {
                var attempt = 0
                let maxAttempts = resume ? maxAttemptsSetting : 1
                while attempt < maxAttempts {
                    await refreshIndexIfNeeded()
                    let dup0 = matchInIndex(pathKey: pathKeyLocal, size: size, checksum: checksum)
                    if dup0 != .none {
                        let r = (dup0 == .pathAndSize ? "path+size" : "path+checksum")
                        log("✓ Already present before upload (\(r)), skipping: \(rel.fullPath)")
                        break
                    }
                    do {
                        log("Init direct upload: \(file.lastPathComponent) (\(size) bytes)")
                        let initResp = try await client.requestDirectUploadInit(
                            persistentId: persistentId,
                            fileSize: size,
                            fileName: fileName,
                            mime: mime
                        )

                        guard let urlStr = initResp.data.url,
                              let putURL = URL(string: urlStr) else {
                            throw DVError.initDidNotReturnURL
                        }

                        log("PUT S3 → \(putURL.host ?? "")")

                        try await client.putFileToS3(preSignedURL: putURL,
                                                     headers: initResp.data.headers,
                                                     fileURL: file)
                        let payload = DVFinalizeRequest(
                            storageIdentifier: initResp.data.storageIdentifier,
                            fileName: fileName,
                            mimeType: mime,
                            directoryLabel: dirLabel,
                            description: nil
                        )
                        log("Finalizing Dataverse…")
                        try await client.finalizeDirectUpload(persistentId: persistentId, payload: payload)

                        log("✓ Completed (direct): \(rel.fullPath)")
                        existingByPathAndSize.insert("\(pathKeyLocal)|\(size)")
                        break
                    } catch let e as DVError {
                        if case .badStatusCode(404) = e {
                            log("Direct upload unavailable (404) → switching to multipart fallback…")
                            var mpAttempt = 0
                            while mpAttempt < maxAttempts {
                                await refreshIndexIfNeeded()
                                let dup = matchInIndex(pathKey: pathKeyLocal, size: size, checksum: checksum)
                                if dup != .none {
                                    let r = (dup == .pathAndSize ? "path+size" : "path+checksum")
                                    log("✓ Already present before upload (multipart fallback, \(r)), skipping: \(rel.fullPath)")
                                    break
                                }
                                do {
                                    log("== Multipart upload == \(file.lastPathComponent)")
                                    try await client.uploadMultipart(persistentId: persistentId,
                                                                     fileURL: file,
                                                                     directoryLabel: dirLabel,
                                                                     log: log,
                                                                     progress: byteProgress,
                                                                     shouldCancel: { Task.isCancelled })
                                    log("✓ Completed (multipart): \(rel.fullPath)")
                                    existingByPathAndSize.insert("\(pathKeyLocal)|\(size)")
                                    break
                                } catch {
                                    if let urlError = error as? URLError {
                                        if UploadCoordinator.isTransient(urlError) && mpAttempt < maxAttempts - 1 {
                                            mpAttempt += 1
                                            log("Transient network error: code=\(urlError.code.rawValue), multipart fallback retry \(mpAttempt)/\(maxAttempts)…")
                                            await refreshIndexIfNeeded()
                                            let dup = matchInIndex(pathKey: pathKeyLocal, size: size, checksum: checksum)
                                            if dup != .none {
                                                let r = (dup == .pathAndSize ? "path+size" : "path+checksum")
                                                log("✓ Already present after network error (\(r)), skipping: \(rel.fullPath)")
                                                break
                                            }
                                            await UploadCoordinator.backoffSleep(attempt: mpAttempt, base: baseBackoff)
                                            log("Resuming multipart fallback, attempt \(mpAttempt)/\(maxAttempts)…")
                                            continue
                                        } else {
                                            log("Network error: code=\(urlError.code.rawValue)")
                                            throw urlError
                                        }
                                    }
                                    if let posixError = error as? POSIXError {
                                        if UploadCoordinator.isTransient(posixError) && mpAttempt < maxAttempts - 1 {
                                            mpAttempt += 1
                                            log("Transient POSIX error: code=\(posixError.code.rawValue), multipart fallback retry \(mpAttempt)/\(maxAttempts)…")
                                            await refreshIndexIfNeeded()
                                            let dup = matchInIndex(pathKey: pathKeyLocal, size: size, checksum: checksum)
                                            if dup != .none {
                                                let r = (dup == .pathAndSize ? "path+size" : "path+checksum")
                                                log("✓ Already present after network error (\(r)), skipping: \(rel.fullPath)")
                                                break
                                            }
                                            await UploadCoordinator.backoffSleep(attempt: mpAttempt)
                                            log("Resuming multipart fallback, attempt \(mpAttempt)/\(maxAttempts)…")
                                            continue
                                        } else {
                                            log("POSIX network error: code=\(posixError.code.rawValue)")
                                            throw posixError
                                        }
                                    }
                                    mpAttempt += 1
                                    await refreshIndexIfNeeded()
                                    let dup = matchInIndex(pathKey: pathKeyLocal, size: size, checksum: checksum)
                                    if dup != .none {
                                        let r = (dup == .pathAndSize ? "path+size" : "path+checksum")
                                        log("✓ Already present after network error (\(r)), skipping: \(rel.fullPath)")
                                        break
                                    }
                                    if mpAttempt >= maxAttempts || !UploadCoordinator.isTransient(error) {
                                        throw error
                                    }
                                    log("Network error, retry \(mpAttempt)/\(maxAttempts)…")
                                    await UploadCoordinator.backoffSleep(attempt: mpAttempt, base: baseBackoff)
                                }
                            }
                            break
                        } else {
                            throw e
                        }
                    } catch {
                        if let urlError = error as? URLError {
                            if UploadCoordinator.isTransient(urlError) && attempt < maxAttempts - 1 {
                                attempt += 1
                                log("Transient network error: code=\(urlError.code.rawValue), retry \(attempt)/\(maxAttempts)…")
                                await refreshIndexIfNeeded()
                                let dupF = matchInIndex(pathKey: pathKeyLocal, size: size, checksum: checksum)
                                if dupF != .none {
                                    let r = (dupF == .pathAndSize ? "path+size" : "path+checksum")
                                    log("✓ Already present after network error (\(r)), skipping: \(rel.fullPath)")
                                    break
                                }
                                await UploadCoordinator.backoffSleep(attempt: attempt, base: baseBackoff)
                                log("Resuming direct upload, attempt \(attempt)/\(maxAttempts)…")
                                continue
                            } else {
                                log("Network error: code=\(urlError.code.rawValue)")
                                throw urlError
                            }
                        }
                        if let posixError = error as? POSIXError {
                            if UploadCoordinator.isTransient(posixError) && attempt < maxAttempts - 1 {
                                attempt += 1
                                log("Transient POSIX error: code=\(posixError.code.rawValue), retry \(attempt)/\(maxAttempts)…")
                                await refreshIndexIfNeeded()
                                let dupG = matchInIndex(pathKey: pathKeyLocal, size: size, checksum: checksum)
                                if dupG != .none {
                                    let r = (dupG == .pathAndSize ? "path+size" : "path+checksum")
                                    log("✓ Already present after network error (\(r)), skipping: \(rel.fullPath)")
                                    break
                                }
                                await UploadCoordinator.backoffSleep(attempt: attempt, base: baseBackoff)
                                log("Resuming direct upload, attempt \(attempt)/\(maxAttempts)…")
                                continue
                            } else {
                                log("POSIX network error: code=\(posixError.code.rawValue)")
                                throw posixError
                            }
                        }
                        attempt += 1
                        await refreshIndexIfNeeded()
                        let dup = matchInIndex(pathKey: pathKeyLocal, size: size, checksum: checksum)
                        if dup != .none {
                            let r = (dup == .pathAndSize ? "path+size" : "path+checksum")
                            log("✓ Already present after network error (\(r)), skipping: \(rel.fullPath)")
                            break
                        }
                        if attempt >= maxAttempts || !UploadCoordinator.isTransient(error) {
                            throw error
                        }
                        log("Network error, retry \(attempt)/\(maxAttempts)…")
                        await UploadCoordinator.backoffSleep(attempt: attempt, base: baseBackoff)
                    }
                }
            } catch {
                throw error
            }
        }

        SecurityScopedAccess.stopAccess(to: allURLs)
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

    /// Returns `true` when the error is likely transient and worth retrying.
    private static func isTransient(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .networkConnectionLost,
                 .dnsLookupFailed,
                 .notConnectedToInternet,
                 .internationalRoamingOff,
                 .callIsActive,
                 .dataNotAllowed,
                 .requestBodyStreamExhausted,
                 .cannotLoadFromNetwork,
                 .resourceUnavailable:
                return true
            default:
                return false
            }
        }
        if let posixError = error as? POSIXError {
            switch posixError.code {
            case .ECONNRESET, .ENETDOWN, .EPIPE, .ETIMEDOUT:
                return true
            default:
                return false
            }
        }
        return false
    }

    /// Sleep using exponential backoff where the first attempt waits `base` seconds.
    private static func backoffSleep(attempt: Int, base: Double = 1.0, factor: Double = 2.0) async {
        let delay = base * pow(factor, Double(attempt - 1))
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }
}
