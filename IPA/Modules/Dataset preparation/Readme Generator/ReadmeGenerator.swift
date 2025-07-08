//  ReadmeGenerator.swift
//  Utility class for generating a README.txt file summarizing dataset metadata, structure, and comments.

import Foundation

public class ReadmeGenerator {
    public init() {}
    
    // Generates a README.txt file with provided metadata and writes it to the given URL.
    public func generateReadme(parameters: [String: String], structure: String, comments: String, outputURL: URL) throws {
        var content = ""
        content.append("GENERAL INFORMATION\n-------------------\n")
        content.append("Dataset Title: \(parameters["datasetTitle"] ?? "")\n")
        content.append("Authorship: \(parameters["authorship"] ?? "")\n")
        content.append("Contact: \(parameters["contact"] ?? "")\n")
        content.append("Language: \(parameters["language"] ?? "")\n")
        content.append("Specimen: \(parameters["specimen"] ?? "")\n")
        content.append("Sex: \(parameters["sex"] ?? "")\n")
        content.append("Life Stage: \(parameters["lifeStage"] ?? "")\n")
        content.append("Number of Scanned Items: \(parameters["scannedItems"] ?? "")\n")
        content.append("Technique Used: \(parameters["technique"] ?? "")\n")
        content.append("Licence: \(parameters["licence"] ?? "")\n")
        content.append("DOI: \(parameters["doi"] ?? "")\n")
        content.append("Folder Size (Go): \(parameters["fileSize"] ?? "")\n")
        content.append("Number of Files: \(parameters["numFiles"] ?? "")\n")
        content.append("\nSTRUCTURE\n---------\n")
        content.append("\(structure)\n")
        content.append("\nCOMMENTS\n--------\n")
        content.append("\(comments)")
        
        try content.write(to: outputURL, atomically: true, encoding: .utf8)
    }
}
