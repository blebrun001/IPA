//  OBJRenamer.swift
//  Utility class to batch rename files, folders, and references inside OBJ/MTL files.

import Foundation

public class OBJRenamer {
    public init() {}

    // Recursively renames files, folders, and text contents in .obj/.mtl files.
    public func renameModels(in folder: URL, oldName: String, newName: String) -> [String] {
        var results: [String] = []
        let fileManager = FileManager.default

        func processDirectory(_ url: URL) {
            guard let items = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return }

            for item in items {
                var newItemURL = item

                // Recursively process subdirectories
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory), isDirectory.boolValue {
                    processDirectory(item)
                }

                // Rename files and folders if their names contain the old string
                if item.lastPathComponent.contains(oldName) {
                    let newNameComponent = item.lastPathComponent.replacingOccurrences(of: oldName, with: newName)
                    newItemURL = item.deletingLastPathComponent().appendingPathComponent(newNameComponent)
                    do {
                        try fileManager.moveItem(at: item, to: newItemURL)
                        results.append("Renamed \(item.lastPathComponent) → \(newNameComponent)")
                    } catch {
                        results.append("Failed to rename \(item.lastPathComponent): \(error.localizedDescription)")
                        continue
                    }
                }

                // Replace text inside .obj and .mtl files
                if newItemURL.pathExtension.lowercased() == "obj" || newItemURL.pathExtension.lowercased() == "mtl" {
                    do {
                        var content = try String(contentsOf: newItemURL, encoding: .utf8)
                        if content.contains(oldName) {
                            content = content.replacingOccurrences(of: oldName, with: newName)
                            try content.write(to: newItemURL, atomically: true, encoding: .utf8)
                            results.append("Updated content in \(newItemURL.lastPathComponent)")
                        }
                    } catch {
                        results.append("Error updating file \(newItemURL.lastPathComponent): \(error.localizedDescription)")
                    }
                }
            }
        }

        processDirectory(folder)

        // Rename root folder if necessary
        if folder.lastPathComponent.contains(oldName) {
            let newFolderName = folder.lastPathComponent.replacingOccurrences(of: oldName, with: newName)
            let newFolderURL = folder.deletingLastPathComponent().appendingPathComponent(newFolderName)
            do {
                try fileManager.moveItem(at: folder, to: newFolderURL)
                results.append("Folder renamed into \(newFolderName)")
            } catch {
                results.append("Error while renaming folder: \(error.localizedDescription)")
            }
        }

        return results
    }
}
