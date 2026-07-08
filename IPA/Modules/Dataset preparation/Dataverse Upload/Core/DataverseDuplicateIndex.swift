//  DataverseDuplicateIndex.swift
//  Local lookup table for draft-file duplicate detection.

import Foundation

enum DataverseDuplicateMatch {
    case none
    case pathAndSize
    case pathAndChecksum
}

final class DataverseDuplicateIndex {
    private(set) var checksumTypesPresent: Set<String> = []
    private var existingByPathAndSize: Set<String> = []
    private var existingByPathAndChecksum: Set<String> = []

    init(files: [DVExistingFile]) {
        replace(with: files)
    }

    var canMatchChecksums: Bool {
        !existingByPathAndChecksum.isEmpty && !checksumTypesPresent.isEmpty
    }

    func replace(with files: [DVExistingFile]) {
        existingByPathAndSize.removeAll(keepingCapacity: true)
        existingByPathAndChecksum.removeAll(keepingCapacity: true)
        checksumTypesPresent.removeAll(keepingCapacity: true)

        for file in files {
            let pathKey = Self.pathKey(directoryLabel: file.directoryLabel, filename: file.filename)
            if let size = file.filesize {
                existingByPathAndSize.insert("\(pathKey)|\(size)")
            }
            if let checksum = file.checksum, !checksum.isEmpty {
                existingByPathAndChecksum.insert("\(pathKey)|\(checksum.lowercased())")
            }
            if let type = file.checksumType?.lowercased(), !type.isEmpty {
                checksumTypesPresent.insert(type)
            }
        }
    }

    func match(pathKey: String, size: Int64, checksum: String?) -> DataverseDuplicateMatch {
        let key = pathKey.lowercased()
        if existingByPathAndSize.contains("\(key)|\(size)") {
            return .pathAndSize
        }
        if let checksum = checksum?.lowercased(),
           existingByPathAndChecksum.contains("\(key)|\(checksum)") {
            return .pathAndChecksum
        }
        return .none
    }

    func markUploaded(pathKey: String, size: Int64) {
        existingByPathAndSize.insert("\(pathKey.lowercased())|\(size)")
    }

    static func pathKey(directoryLabel: String?, filename: String) -> String {
        let name = filename.lowercased()
        let dir = (directoryLabel ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        return dir.isEmpty ? name : "\(dir)/\(name)"
    }
}
