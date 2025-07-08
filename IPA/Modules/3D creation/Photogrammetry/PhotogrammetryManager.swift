//  PhotogrammetryManager.swift
//  Singleton manager that handles photogrammetry sessions, file exports, compression, and cleanup logic.

import Foundation
import Combine
import RealityKit
import AppKit

public class PhotogrammetryManager: ObservableObject {
    
    // Shared singleton instance
    static let shared = PhotogrammetryManager()
    
    // Flags for post-processing cleanup
    var shouldDeleteUSDAFiles = true
    var shouldDeleteAO = false
    var shouldDeleteDisplacement = false
    var shouldDeleteNormal = false
    var shouldDeleteRoughness = false

    // Reference to the last generated OBJ file
    @Published var lastGeneratedOBJ: URL?

    private var currentSession: PhotogrammetrySession?

    // Enum defining how the masking is handled during export
    public enum MaskMode: String {
        case isolate = "Isolate from environment"
        case include = "Include environment"
    }

    private init() { }  // Prevent multiple instances

    // Launches a photogrammetry session with specified configuration
    public func startCapture(inputFolder: URL, outputFolder: URL, fileName: String,
                             detail: PhotogrammetrySession.Request.Detail,
                             sampleOrdering: PhotogrammetrySession.Configuration.SampleOrdering,
                             featureSensitivity: PhotogrammetrySession.Configuration.FeatureSensitivity,
                             exportFormat: String,
                             maskMode: MaskMode,
                             compressImages: Bool,
                             compressionQuality: CGFloat,
                             onProgressUpdate: @escaping (Double) -> Void,
                             onCompletion: @escaping (URL) -> Void) async {
        guard PhotogrammetrySession.isSupported else {
            print("Photogrammetry unsupported by this machine.")
            return
        }
        do {
            var config = PhotogrammetrySession.Configuration()
            config.sampleOrdering = sampleOrdering
            config.featureSensitivity = featureSensitivity
            
            let session = try PhotogrammetrySession(input: inputFolder, configuration: config)
            self.currentSession = session
            
            let request: PhotogrammetrySession.Request
            var outputURL: URL
            
            if exportFormat == "OBJ" {
                let objFolder = outputFolder.appendingPathComponent(fileName, isDirectory: true)
                try FileManager.default.createDirectory(at: objFolder, withIntermediateDirectories: true)
                request = makeModelFileRequest(url: objFolder, detail: detail, mask: maskMode)
                outputURL = objFolder.appendingPathComponent("\(fileName).obj")
                print("Export OBJ file to: \(objFolder.path) with mask: \(maskMode.rawValue)")
            } else {
                outputURL = outputFolder.appendingPathComponent("\(fileName).usdz")
                request = makeModelFileRequest(url: outputURL, detail: detail, mask: maskMode)
                print("Export USDZ file to: \(outputURL.path) with mask: \(maskMode.rawValue)")
            }
            
            Task {
                do {
                    for try await output in session.outputs {
                        switch output {
                        case .processingComplete:
                            print("Process complete")
                            self.currentSession = nil
                            
                            await MainActor.run {
                                if SettingsManager.instance.enableSound {
                                    SoundPlayer.playSound(named: "success_capture")
                                }
                            }
                            
                            if self.shouldDeleteUSDAFiles && exportFormat == "OBJ" {
                                let objFolder = outputFolder.appendingPathComponent(fileName, isDirectory: true)
                                print("Suppression activée, tentative de suppression dans : \(objFolder.path)")
                                deleteFiles(in: objFolder)
                            }
                            if exportFormat == "OBJ" {
                                let objFolder = outputFolder.appendingPathComponent(fileName, isDirectory: true)
                                var foundOBJ: URL?
                                var waitTime = 0
                                while foundOBJ == nil && waitTime < 10 {
                                    let files = try FileManager.default.contentsOfDirectory(at: objFolder, includingPropertiesForKeys: nil)
                                    foundOBJ = files.first(where: { $0.pathExtension.lowercased() == "obj" })
                                    if foundOBJ == nil {
                                        try await Task.sleep(nanoseconds: 500_000_000)
                                        waitTime += 1
                                    }
                                }
                                
                                if let originalOBJ = foundOBJ {
                                    print("OBJ file found: \(originalOBJ.path)")
                                    let renamedOBJ = try self.renameGeneratedOBJ(fileURL: originalOBJ, newName: fileName)
                                    if compressImages {
                                        do {
                                            try self.compressImages(in: objFolder, quality: compressionQuality)
                                        } catch {
                                            print("Compression image error: \(error.localizedDescription)")
                                        }
                                    }
                                    PhotogrammetryManager.shared.lastGeneratedOBJ = renamedOBJ
                                    print("lastGeneratedOBJ updated: \(renamedOBJ.path)")
                                    onCompletion(renamedOBJ)
                                } else {
                                    print("No OBJ file found in \(objFolder.path)")
                                    onCompletion(objFolder)
                                }
                            } else {
                                PhotogrammetryManager.shared.lastGeneratedOBJ = outputURL
                                print("lastGeneratedOBJ updated (USDZ): \(outputURL.path)")
                                onCompletion(outputURL)
                            }
                        case .requestError(_, let error):
                            print("Error: \(error.localizedDescription)")
                        case .requestProgress(_, let fractionComplete):
                            DispatchQueue.main.async {
                                onProgressUpdate(fractionComplete)
                            }
                        default:
                            break
                        }
                    }
                } catch {
                    print("Processing error: \(error.localizedDescription)")
                    self.currentSession = nil
                }
            }
            
            try session.process(requests: [request])
        } catch {
            print("Session initialization error: \(error.localizedDescription)")
        }
    }
    
    // Cancels an active photogrammetry session
    public func stopCapture() {
        currentSession?.cancel()
        currentSession = nil
        print("Process stoped by user")
    }

    // Renames the exported OBJ file to match the desired filename
    private func renameGeneratedOBJ(fileURL: URL, newName: String) throws -> URL {
        let newFileURL = fileURL.deletingLastPathComponent().appendingPathComponent("\(newName).obj")
        print("Try to rename: \(fileURL.path) → \(newFileURL.path)")
        
        if FileManager.default.fileExists(atPath: newFileURL.path) {
            try FileManager.default.removeItem(at: newFileURL)
        }
        try FileManager.default.moveItem(at: fileURL, to: newFileURL)
        print("File successfully renamed: \(newFileURL.path)")
        return newFileURL
    }

    // Builds a model export request with specified mask mode
    private func makeModelFileRequest(url: URL, detail: PhotogrammetrySession.Request.Detail, mask: MaskMode) -> PhotogrammetrySession.Request {
        print("Mask use: \(mask.rawValue)")
        return .modelFile(url: url, detail: detail)
    }

    // Compresses texture images in the export folder.
    private func compressImages(in folder: URL, quality: CGFloat) throws {
        let fileManager = FileManager.default
        let imageExtensions: Set<String> = ["png", "tif", "tiff", "bmp", "jpeg", "jpg"]
        let files = try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        var mapping: [String: String] = [:]
        
        for file in files {
            let ext = file.pathExtension.lowercased()
            if imageExtensions.contains(ext) {
                guard let image = NSImage(contentsOf: file) else {
                    print("Can't load photo: \(file.path)")
                    continue
                }
                guard let tiffData = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiffData),
                      let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality]) else {
                    print("Compression failed: \(file.path)")
                    continue
                }
                if ext == "jpg" || ext == "jpeg" {
                    try jpegData.write(to: file, options: .atomic)
                } else {
                    let newFile = file.deletingPathExtension().appendingPathExtension("jpg")
                    if fileManager.fileExists(atPath: newFile.path) {
                        try fileManager.removeItem(at: newFile)
                    }
                    try jpegData.write(to: newFile, options: .atomic)
                    try fileManager.removeItem(at: file)
                    mapping[file.lastPathComponent] = newFile.lastPathComponent
                }
            }
        }
        
        // Update MTL file with new texture names
        if let mtlFile = files.first(where: { $0.pathExtension.lowercased() == "mtl" }) {
            var mtlContent = try String(contentsOf: mtlFile, encoding: .utf8)
            for (oldName, newName) in mapping {
                mtlContent = mtlContent.replacingOccurrences(of: oldName, with: newName)
            }
            try mtlContent.write(to: mtlFile, atomically: true, encoding: .utf8)
        }
    }
    
    // Deletes unnecessary files after export, based on user settings
    private func deleteFiles(in folder: URL) {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else {
            print("Erreur : impossible de lire le contenu de \(folder.path)")
            return
        }

        for file in files {
            let name = file.lastPathComponent.lowercased()
            let ext = file.pathExtension.lowercased()

            if ext == "usda", shouldDeleteUSDAFiles {
                print("Suppression .usda : \(name)")
                try? fileManager.removeItem(at: file)
            } else if name.contains("ao0"), shouldDeleteAO {
                print("Suppression Ambient Occlusion : \(name)")
                try? fileManager.removeItem(at: file)
            } else if name.contains("disp0"), shouldDeleteDisplacement {
                print("Suppression Displacement : \(name)")
                try? fileManager.removeItem(at: file)
            } else if name.contains("norm0"), shouldDeleteNormal {
                print("Suppression Normal Map : \(name)")
                try? fileManager.removeItem(at: file)
            } else if name.contains("roughness"), shouldDeleteRoughness {
                print("Suppression Roughness Map : \(name)")
                try? fileManager.removeItem(at: file)
            }
        }
    }
}
