//  Networking client that talks to the Dataverse API, covering direct upload
//  initialization, S3 PUTs, multipart fallbacks, and draft file enumeration.
import Foundation

// MARK: - Protocol (to simplify dependency injection and testing)
protocol DVClient {
    init(server: URL, apiKey: String)
    var server: URL { get }
    var apiKey: String { get }

    func requestDirectUploadInit(persistentId: String,
                                 fileSize: Int64,
                                 fileName: String?,
                                 mime: String?) async throws -> DVDirectInitResponse

    func putFileToS3(preSignedURL: URL,
                     headers: [String:String]?,
                     fileURL: URL) async throws

    func finalizeDirectUpload(persistentId: String,
                              payload: DVFinalizeRequest) async throws

    /// Server-side multipart fallback streamed through the Dataverse API.
    func uploadMultipart(persistentId: String,
                         fileURL: URL,
                         directoryLabel: String?,
                         log: @escaping (String) -> Void,
                         progress: @escaping (String) -> Void,
                         shouldCancel: @escaping () -> Bool) async throws

    /// Fetch the list of files already present in the draft version to avoid duplicates.
    func listDraftFiles(persistentId: String) async throws -> [DVExistingFile]
}

// MARK: - Errors
enum DVError: Error, LocalizedError {
    case badStatusCode(Int)
    case serverError(String)
    case decodingError(Error)
    case invalidServerURL
    case notOKStatus(String)
    case initDidNotReturnURL
    case networkError(Int, String)

    var errorDescription: String? {
        switch self {
        case .badStatusCode(let c): return "HTTP \(c)"
        case .serverError(let s):   return s
        case .decodingError(let e): return "JSON decoding failed: \(e.localizedDescription)"
        case .invalidServerURL:     return "Invalid server URL"
        case .notOKStatus(let s):   return "API status not OK: \(s)"
        case .initDidNotReturnURL:  return "Direct-upload init did not provide a URL"
        case .networkError(let c, let s): return "Network error (\(c)): \(s)"
        }
    }
}

// MARK: - Models for the existing draft file listing
struct DVExistingFile: Hashable {
    let filename: String
    let directoryLabel: String?
    let filesize: Int64?
    let checksum: String?
    let checksumType: String?
}

// MARK: - Concrete client
struct DataverseClient: DVClient {
    let server: URL
    let apiKey: String

    init(server: URL, apiKey: String) {
        self.server = server
        self.apiKey = apiKey
    }

    /// Step 1: request the direct-upload presigned URL.
    func requestDirectUploadInit(persistentId: String,
                                 fileSize: Int64,
                                 fileName: String?,
                                 mime: String?) async throws -> DVDirectInitResponse {
        let url = try DataverseAPI.directUploadURL(server: server,
                                                   persistentId: persistentId,
                                                   fileSize: fileSize,
                                                   fileName: fileName,
                                                   mime: mime)
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue(apiKey, forHTTPHeaderField: "X-Dataverse-key")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch let e as URLError {
            print("Network error: \(e)")
            throw e
        } catch let e as POSIXError {
            print("POSIX error: \(e)")
            throw e
        } catch {
            throw error
        }
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(code) else { throw DVError.badStatusCode(code) }

        do {
            let out = try JSONDecoder().decode(DVDirectInitResponse.self, from: data)
            guard out.status.uppercased() == "OK" else { throw DVError.notOKStatus(out.status) }
            return out
        } catch {
            if let s = String(data: data, encoding: .utf8) { throw DVError.serverError(s) }
            throw DVError.decodingError(error)
        }
    }

    /// Step 2: upload the file directly to the storage provider using the presigned URL.
    func putFileToS3(preSignedURL: URL,
                     headers: [String:String]?,
                     fileURL: URL) async throws {
        var req = URLRequest(url: preSignedURL)
        req.httpMethod = "PUT"
        if let h = headers {
            for (k, v) in h { req.setValue(v, forHTTPHeaderField: k) }
        } else {
            req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        }
        let size = try fileSize(at: fileURL)
        req.setValue(String(size), forHTTPHeaderField: "Content-Length")

        let resp: URLResponse
        do {
            (_, resp) = try await URLSession.shared.upload(for: req, fromFile: fileURL)
        } catch let e as URLError {
            print("Network error: \(e)")
            throw e
        } catch let e as POSIXError {
            print("POSIX error: \(e)")
            throw e
        } catch {
            throw error
        }
        guard let code = (resp as? HTTPURLResponse)?.statusCode, (200...299).contains(code) else {
            throw DVError.badStatusCode((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }

    /// Step 3: finalize the upload so Dataverse registers the file in the dataset.
    func finalizeDirectUpload(persistentId: String, payload: DVFinalizeRequest) async throws {
        let finalizeURL = try DataverseAPI.finalizeURL(server: server, persistentId: persistentId)
        var req = URLRequest(url: finalizeURL)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "X-Dataverse-key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(payload)

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch let e as URLError {
            print("Network error: \(e)")
            throw e
        } catch let e as POSIXError {
            print("POSIX error: \(e)")
            throw e
        } catch {
            throw error
        }
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(code) else {
            if let s = String(data: data, encoding: .utf8) { throw DVError.serverError(s) }
            throw DVError.badStatusCode(code)
        }
    }

    /// Fetch the current draft files to build a local duplicate-detection index.
    func listDraftFiles(persistentId: String) async throws -> [DVExistingFile] {
        let listURL = try DataverseAPI.listFilesURL(server: server, persistentId: persistentId)
        var req = URLRequest(url: listURL)
        req.httpMethod = "GET"
        req.setValue(apiKey, forHTTPHeaderField: "X-Dataverse-key")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch let e as URLError {
            print("Network error: \(e)")
            throw e
        } catch let e as POSIXError {
            print("POSIX error: \(e)")
            throw e
        } catch {
            throw error
        }
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(code) else {
            if let s = String(data: data, encoding: .utf8) { throw DVError.serverError(s) }
            throw DVError.badStatusCode(code)
        }

        do {
            return try DataverseAPI.parseDraftFilesResponse(data)
        } catch {
            if let s = String(data: data, encoding: .utf8) { throw DVError.serverError(s) }
            throw error
        }
    }

    // MARK: - Multipart fallback streamed to the server
    func uploadMultipart(persistentId: String,
                         fileURL: URL,
                         directoryLabel: String?,
                         log: @escaping (String) -> Void,
                         progress: @escaping (String) -> Void,
                         shouldCancel: @escaping () -> Bool) async throws {
        let uploadURL = try DataverseAPI.multipartUploadURL(server: server, persistentId: persistentId)
        var req = URLRequest(url: uploadURL)
        req.httpMethod = "POST"
        req.timeoutInterval = 60 * 60 * 6
        req.setValue(apiKey, forHTTPHeaderField: "X-Dataverse-key")

        let boundary = "----dv-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue("100-continue", forHTTPHeaderField: "Expect")
        req.setValue("close", forHTTPHeaderField: "Connection")

        let fileSz = try fileSize(at: fileURL)
        let parts = MultipartBodyStream.parts(boundary: boundary,
                                               fileName: fileURL.lastPathComponent,
                                               directoryLabel: directoryLabel)
        let contentLength = Int64(parts.head.count) + fileSz + Int64(parts.tail.count)
        req.setValue(String(contentLength), forHTTPHeaderField: "Content-Length")

        let body = try MultipartBodyStream.make(head: parts.head,
                                                fileURL: fileURL,
                                                tail: parts.tail,
                                                log: log,
                                                progress: progress,
                                                shouldCancel: shouldCancel)
        req.httpBodyStream = body.input

        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 60 * 60 * 6
        cfg.timeoutIntervalForResource = 60 * 60 * 6
        cfg.httpShouldUsePipelining = false
        cfg.httpShouldSetCookies = false
        let session = URLSession(configuration: cfg)

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await session.data(for: req)
        } catch let e as URLError {
            print("Network error: \(e)")
            throw e
        } catch let e as POSIXError {
            print("POSIX error: \(e)")
            throw e
        } catch {
            throw error
        }
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(code) else {
            if let s = String(data: data, encoding: .utf8) { throw DVError.serverError(s) }
            throw DVError.badStatusCode(code)
        }
    }
}

// MARK: - Local helpers

/// Retrieve the file size in bytes.
private func fileSize(at url: URL) throws -> Int64 {
    let attr = try FileManager.default.attributesOfItem(atPath: url.path)
    return (attr[.size] as? NSNumber)?.int64Value ?? 0
}
