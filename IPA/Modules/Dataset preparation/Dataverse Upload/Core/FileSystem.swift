//  File-system utility toolkit that flattens directory selections into files
//  and derives Dataverse-friendly relative paths for directory labels.
import Foundation

/// File-system helpers for flattening selections and deriving relative paths.
public enum FileSystem {
    /// Recursively resolve files contained in the provided URLs (files or directories).
    public static func flattenFiles(from urls: [URL]) -> [URL] {
        var out: [URL] = []
        let fm = FileManager.default

        func walk(_ u: URL) {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: u.path, isDirectory: &isDir) else { return }
            if !isDir.boolValue {
                out.append(u)
                return
            }
            // Directory: traverse immediate children while skipping hidden files to avoid noise.
            if let entries = try? fm.contentsOfDirectory(at: u, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                for child in entries { walk(child) }
            }
        }

        for u in urls { walk(u) }
        return out.sorted { $0.path < $1.path }
    }

    /// Break a file URL into a Dataverse directory label and filename, using the closest base URL candidate.
    public static func relativePath(baseCandidates: [URL], file: URL) -> (directoryLabel: String?, fileName: String, fullPath: String) {
        let filePath = file.standardizedFileURL.path
        var bestBase: URL?
        var bestLen = 0
        for base in baseCandidates {
            let basePath = base.standardizedFileURL.path
            if filePath.hasPrefix(basePath), basePath.count > bestLen {
                bestLen = basePath.count
                bestBase = base
            }
        }
        guard let base = bestBase else {
            return (nil, file.lastPathComponent, file.lastPathComponent)
        }
        let rel = String(filePath.dropFirst(base.standardizedFileURL.path.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if rel.isEmpty {
            return (nil, file.lastPathComponent, file.lastPathComponent)
        }
        // Split into directory and filename components.
        let comps = rel.split(separator: "/").map(String.init)
        if comps.count == 1 {
            return (nil, comps[0], rel)
        } else {
            let dir = comps.dropLast().joined(separator: "/")
            let name = comps.last!
            return (dir, name, rel)
        }
    }
}
