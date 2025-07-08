//  DataverseClient.swift
//  Utility class for compressing and uploading files to a Dataverse dataset using the API.

import Foundation

class DataverseClient {
    
    // Converts a DOI from "https://doi.org/..." to "doi:..."
    private func transformDOI(_ doi: String) -> String {
        if doi.lowercased().hasPrefix("https://doi.org/") {
            let suffix = doi.dropFirst("https://doi.org/".count)
            return "doi:" + suffix
        }
        return doi
    }
    
    // Compresses a list of files/folders into a ZIP archive using the system's zip command
    func compressFiles(files: [URL], zipName: String) throws -> URL {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        
        var copiedFileNames: [String] = []
        for file in files {
            let destinationURL = tempDir.appendingPathComponent(file.lastPathComponent)
            try fileManager.copyItem(at: file, to: destinationURL)
            copiedFileNames.append(file.lastPathComponent)
        }
        
        let zipFileURL = tempDir.appendingPathComponent(zipName)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", zipFileURL.path] + copiedFileNames
        process.currentDirectoryURL = tempDir
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw NSError(domain: "DataverseClient", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "Compression error"])
        }
        return zipFileURL
    }
    
    // Uploads a file to Dataverse using multipart/form-data and tracks upload progress
    func uploadFile(fileURL: URL,
                    dataverseAddress: String,
                    token: String,
                    datasetDOI: String,
                    progressHandler: ((Double) -> Void)?,
                    completion: @escaping (Result<String, Error>) -> Void) {
        
        let baseAddress = dataverseAddress.hasSuffix("/") ? dataverseAddress : dataverseAddress + "/"
        let transformedDOI = transformDOI(datasetDOI)
        let endpoint = "\(baseAddress)api/datasets/:persistentId/add?persistentId=\(transformedDOI)"
        print("URL d'upload utilisée : \(endpoint)")
        
        guard let url = URL(string: endpoint) else {
            completion(.failure(NSError(domain: "DataverseClient", code: 0,
                                        userInfo: [NSLocalizedDescriptionKey: "Invalid Dataverse addresse."])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(token, forHTTPHeaderField: "X-Dataverse-key")
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        let filename = fileURL.lastPathComponent
        let mimetype = "application/octet-stream"
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        body.append("Content-Type: \(mimetype)\r\n\r\n")
        do {
            let fileData = try Data(contentsOf: fileURL)
            body.append(fileData)
        } catch {
            completion(.failure(error))
            return
        }
        body.append("\r\n")
        body.append("--\(boundary)--\r\n")
        request.httpBody = body
        
        // Delegate to track upload progress
        let uploadDelegate = UploadTaskDelegate()
        uploadDelegate.progressHandler = progressHandler
        
        let session = URLSession(configuration: .default, delegate: uploadDelegate, delegateQueue: nil)
        let uploadTask = session.uploadTask(with: request, from: body) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "DataverseClient", code: 0,
                                            userInfo: [NSLocalizedDescriptionKey: "No answer recieved."])))
                return
            }
            print("Code HTTP : \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                completion(.failure(NSError(domain: "DataverseClient", code: httpResponse.statusCode,
                                            userInfo: [NSLocalizedDescriptionKey: "Erreur HTTP: \(httpResponse.statusCode)"])))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "DataverseClient", code: 0,
                                            userInfo: [NSLocalizedDescriptionKey: "No data recieved."])))
                return
            }
            let responseString = String(data: data, encoding: .utf8) ?? "Invalid answer"
            completion(.success(responseString))
        }
        uploadTask.resume()
    }
}

// Delegate class used to report upload progress
class UploadTaskDelegate: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate {
    var progressHandler: ((Double) -> Void)?
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        if totalBytesExpectedToSend > 0 {
            let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
            progressHandler?(progress)
        }
    }
}

// Extension to append string to Data as UTF-8
extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
