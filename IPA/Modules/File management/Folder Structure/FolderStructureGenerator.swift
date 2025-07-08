//  FolderStructureGenerator.swift
//  Utility class to generate directory structures for a given list of terms and template structure.

import Foundation

public class FolderStructureGenerator {
    public init() {}
    
    // Creates folders for each term according to a provided structure template.
    public func generateFolderStructure(base: URL, terms: [String], structure: String) {
        let fileManager = FileManager.default
        for term in terms {
            let termPath = base.appendingPathComponent(term)
            for line in structure.components(separatedBy: .newlines)
                .map({ $0.trimmingCharacters(in: .whitespaces) }) where !line.isEmpty {
                    let folderPath = termPath.appendingPathComponent(line)
                    try? fileManager.createDirectory(at: folderPath, withIntermediateDirectories: true)
            }
        }
    }
}
