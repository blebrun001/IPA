//  Handles security-scoped bookmark resolution so uploads can access sandboxed
//  files and guarantees the matching cleanup when operations finish.
import Foundation

/// Wraps the security-scoped bookmark dance so callers do not forget to stop access.
enum SecurityScopedAccess {
    /// Resolve security-scoped URLs from a list of upload items, requesting access for each.
    static func resolveURLs(for items: [UploadItem]) throws -> [URL] {
        var urls: [URL] = []
        for it in items {
            if let bm = it.bookmark, !bm.isEmpty {
                var stale = false
                let url = try URL(resolvingBookmarkData: bm,
                                  options: [.withSecurityScope],
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &stale)
                _ = url.startAccessingSecurityScopedResource()
                urls.append(url)
            } else {
                let url = URL(fileURLWithPath: it.path)
                _ = url.startAccessingSecurityScopedResource()
                urls.append(url)
            }
        }
        return urls
    }

    /// Stop using any security-scoped resources that were previously opened.
    static func stopAccess(to urls: [URL]) {
        for u in urls { u.stopAccessingSecurityScopedResource() }
    }
}
