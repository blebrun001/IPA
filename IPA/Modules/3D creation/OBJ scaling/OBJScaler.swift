//  OBJScaler.swift
//  Scales the vertices and normals of a .obj 3D model file using a given factor.

import Foundation

public class OBJScaler {
    public init() {}

    // Scales the given OBJ file based on uncalibrated and real-world values.
    // - Parameters:
    //   - file: The URL of the OBJ file to be scaled.
    //   - uncalibrated: The original (uncalibrated) size.
    //   - real: The target real-world size.
    //   - overwrite: Whether to overwrite the original file or create a new one.
    // - Returns: URL of the resulting scaled OBJ file.
    public func scaleOBJ(file: URL, uncalibrated: Double, real: Double, overwrite: Bool) throws -> URL {
        let scaleFactor = real / uncalibrated
        let fileManager = FileManager.default
        
        print("Scaling of OBJ file: \(file.lastPathComponent)")
        print("Applied scaling factor: \(scaleFactor)")
        
        // Vérify that hte file exist
        guard fileManager.fileExists(atPath: file.path) else {
            throw NSError(domain: "OBJScaler", code: 0, userInfo: [NSLocalizedDescriptionKey: "Can't find file."])
        }
        
        // read obj content
        let originalContent = try String(contentsOf: file, encoding: .utf8)
        let lines = originalContent.split(separator: "\n", omittingEmptySubsequences: false)
        
        var scaledLines: [String] = []
        for line in lines {
            // use only lines "v " et "vn "
            if line.hasPrefix("v ") || line.hasPrefix("vn ") {
                let components = line.split(separator: " ")
                if components.count >= 4 {
                    // Parse x, y, z
                    guard let x = Double(components[1]),
                          let y = Double(components[2]),
                          let z = Double(components[3]) else {
                        scaledLines.append(String(line))
                        continue
                    }
                    let newX = x * scaleFactor
                    let newY = y * scaleFactor
                    let newZ = z * scaleFactor
                    let prefix = components[0]  // "v" ou "vn"
                    scaledLines.append("\(prefix) \(newX) \(newY) \(newZ)")
                } else {
                    scaledLines.append(String(line))
                }
            } else {
                scaledLines.append(String(line))
            }
        }
        
        let newOBJContent = scaledLines.joined(separator: "\n")
        
        // if overwrite is true, erase existing content
        let destination: URL
        if overwrite {
            try newOBJContent.write(to: file, atomically: true, encoding: .utf8)
            destination = file
        } else {
            //if not, create a new file (ex: "scaled_myfile.obj")
            let newFileName = "scaled_" + file.lastPathComponent
            let newFileURL = file.deletingLastPathComponent().appendingPathComponent(newFileName)
            if fileManager.fileExists(atPath: newFileURL.path) {
                try fileManager.removeItem(at: newFileURL)
            }
            try newOBJContent.write(to: newFileURL, atomically: true, encoding: .utf8)
            destination = newFileURL
        }

        // update last generated obj file
        PhotogrammetryManager.shared.lastGeneratedOBJ = destination
        print("lastGeneratedOBJ updated : \(destination.path)")

        return destination
    }
}
