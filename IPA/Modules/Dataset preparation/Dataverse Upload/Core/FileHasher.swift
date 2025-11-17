//  Streaming hashing utilities used to fingerprint large files without
//  overloading memory, supporting Dataverse duplicate detection workflows.
import Foundation
import CryptoKit

/// Streaming hashing helpers for large files without loading them into memory.
public enum FileHasher {
    /// SHA-256 digest emitted as a lowercase hexadecimal string.
    public static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let data = try? handle.read(upToCount: 1024 * 1024) // 1 MiB chunks
            if let data, !data.isEmpty {
                hasher.update(data: data)
                return true
            }
            return false
        }) {}
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// MD5 digest (hex). Handy when a Dataverse instance relies on it for duplicate detection.
    public static func md5(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var context = Insecure.MD5()
        while autoreleasepool(invoking: {
            let data = try? handle.read(upToCount: 1024 * 1024)
            if let data, !data.isEmpty {
                context.update(data: data)
                return true
            }
            return false
        }) {}
        let digest = context.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// SHA-1 digest (hex) for compatibility with older deployments.
    public static func sha1(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = Insecure.SHA1()
        while autoreleasepool(invoking: {
            let data = try? handle.read(upToCount: 1024 * 1024)
            if let data, !data.isEmpty {
                hasher.update(data: data)
                return true
            }
            return false
        }) {}
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
