//  MIME type helper that leverages the system UTType database when possible and
//  falls back to a safe default, informing Dataverse of each file's content type.
import Foundation
import UniformTypeIdentifiers

/// Lightweight MIME type inference using the Uniform Type Identifier database when available.
public enum MimeType {
    public static func infer(url: URL) -> String? {
        if #available(macOS 11.0, *) {
            let ext = url.pathExtension
            if let ut = UTType(filenameExtension: ext),
               let mime = ut.preferredMIMEType {
                return mime
            }
        }
        // Fall back to a generic binary type.
        return "application/octet-stream"
    }
}
