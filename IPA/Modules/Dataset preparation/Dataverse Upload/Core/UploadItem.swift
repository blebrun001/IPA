//  Represents a file system item selected for upload with its security bookmark.
import Foundation

/// Represents a file system item selected for upload.
struct UploadItem: Identifiable, Hashable {
    /// Use the normalized path as the stable identifier so duplicates collapse.
    var id: String { path }
    let path: String
    let bookmark: Data?

    func hash(into hasher: inout Hasher) {
        // Normalize the path to avoid treating the same file with different casing as distinct entries.
        hasher.combine((path as NSString).standardizingPath.lowercased())
    }

    static func == (lhs: UploadItem, rhs: UploadItem) -> Bool {
        (lhs.path as NSString).standardizingPath.caseInsensitiveCompare(
            (rhs.path as NSString).standardizingPath
        ) == .orderedSame
    }
}
