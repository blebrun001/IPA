//  Small helper that wraps NSRegularExpression to ignore files whose names
//  match a user-supplied pattern while traversing upload selections.
import Foundation

/// Case-sensitive exclusion filter powered by `NSRegularExpression`.
public struct RegexFilter {
    private let regex: NSRegularExpression?

    public init(pattern: String) {
        if pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.regex = nil
        } else {
            self.regex = try? NSRegularExpression(pattern: pattern)
        }
    }

    /// Returns `true` when the provided URL should be processed.
    public func accepts(_ url: URL) -> Bool {
        guard let regex = regex else { return true }
        // Evaluate only the last path component so directory names do not accidentally block files.
        let name = url.lastPathComponent
        let range = NSRange(location: 0, length: (name as NSString).length)
        return regex.firstMatch(in: name, options: [], range: range) == nil
    }
}
