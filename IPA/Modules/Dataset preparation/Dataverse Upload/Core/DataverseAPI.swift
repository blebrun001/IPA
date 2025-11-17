//  DataverseAPI.swift
//  Helper utilities for constructing Dataverse endpoints and parsing responses.

import Foundation

enum DataverseAPI {
    static func directUploadURL(server: URL,
                                persistentId: String,
                                fileSize: Int64,
                                fileName: String?,
                                mime: String?) throws -> URL {
        guard var comps = URLComponents(url: server.appendingPathComponent("/api/datasets/:persistentId/uploadurls"),
                                        resolvingAgainstBaseURL: false) else {
            throw DVError.invalidServerURL
        }
        var query: [URLQueryItem] = [
            .init(name: "persistentId", value: persistentId),
            .init(name: "size", value: String(fileSize))
        ]
        if let fileName { query.append(.init(name: "filename", value: fileName)) }
        if let mime { query.append(.init(name: "mimeType", value: mime)) }
        comps.queryItems = query
        guard let url = comps.url else { throw DVError.invalidServerURL }
        return url
    }

    static func finalizeURL(server: URL, persistentId: String) throws -> URL {
        guard let url = URL(string: "/api/datasets/:persistentId/add", relativeTo: server) else {
            throw DVError.invalidServerURL
        }
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw DVError.invalidServerURL
        }
        comps.queryItems = [.init(name: "persistentId", value: persistentId)]
        guard let finalURL = comps.url else { throw DVError.invalidServerURL }
        return finalURL
    }

    static func listFilesURL(server: URL, persistentId: String) throws -> URL {
        guard let base = URL(string: "/api/datasets/:persistentId/versions/:draft/files", relativeTo: server) else {
            throw DVError.invalidServerURL
        }
        guard var comps = URLComponents(url: base, resolvingAgainstBaseURL: true) else {
            throw DVError.invalidServerURL
        }
        comps.queryItems = [.init(name: "persistentId", value: persistentId)]
        guard let finalURL = comps.url else { throw DVError.invalidServerURL }
        return finalURL
    }

    static func multipartUploadURL(server: URL, persistentId: String) throws -> URL {
        guard let base = URL(string: "/api/datasets/:persistentId/add", relativeTo: server) else {
            throw DVError.invalidServerURL
        }
        guard var comps = URLComponents(url: base, resolvingAgainstBaseURL: true) else {
            throw DVError.invalidServerURL
        }
        comps.queryItems = [.init(name: "persistentId", value: persistentId)]
        guard let finalURL = comps.url else { throw DVError.invalidServerURL }
        return finalURL
    }

    static func parseDraftFilesResponse(_ data: Data) throws -> [DVExistingFile] {
        do {
            let response = try JSONDecoder().decode(DVListFilesResponse.self, from: data)
            guard response.status.uppercased() == "OK" else { throw DVError.notOKStatus(response.status) }
            return response.data.map { item in
                DVExistingFile(
                    filename: item.dataFile.filename,
                    directoryLabel: item.dataFile.directoryLabel,
                    filesize: item.dataFile.filesize,
                    checksum: item.dataFile.checksum?.value,
                    checksumType: item.dataFile.checksum?.type
                )
            }
        } catch let error as DVError {
            throw error
        } catch {
            throw DVError.decodingError(error)
        }
    }
}

// MARK: - Internal response models
struct DVListFilesResponse: Decodable {
    let status: String
    let data: [DVListFileItem]
}
struct DVListFileItem: Decodable {
    let dataFile: DVListDataFile
}
struct DVListDataFile: Decodable {
    let filename: String
    let directoryLabel: String?
    let filesize: Int64?
    let checksum: DVListChecksum?
}
struct DVListChecksum: Decodable {
    let type: String?
    let value: String?
}
