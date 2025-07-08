//  PhotogrammetryViewModel.swift
//  ViewModel for managing folder selection, capture settings, and progress tracking for photogrammetry.


import SwiftUI
import RealityKit
import UniformTypeIdentifiers

class PhotogrammetryViewModel: ObservableObject {
    
    // Folder selection
    @Published var mainFolder: URL? = nil                   // Root folder containing specimens
    @Published var subFolders: [URL] = []                   // Subfolders (e.g. individual bones)
    @Published var selectedSubFolder: URL? = nil            // Selected bone folder
    @Published var inputFolder: URL? = nil                  // Folder containing the "photos" to process
    @Published var outputFolder: URL? = nil                 // Output folder for the exported model

    // Capture parameters
    @Published var fileName: String = "model"
    @Published var detail: PhotogrammetrySession.Request.Detail = .full
    @Published var sampleOrdering: PhotogrammetrySession.Configuration.SampleOrdering = .unordered
    @Published var featureSensitivity: PhotogrammetrySession.Configuration.FeatureSensitivity = .normal

    // Format and additional options
    @Published var exportFormat: PhotogrammetryTabView.ExportFormat = .obj
    @Published var maskMode: PhotogrammetryManager.MaskMode = .isolate
    @Published var textureCompressionLevel: PhotogrammetryTabView.TextureCompressionLevel = .none

    // Progress tracking
    @Published var progress: Double = 0.0
    @Published var isProcessing: Bool = false
    @Published var statusMessage: String = "Select main working folder."
    @Published var startTime: Date? = nil
    
    // Timer for refreshing subfolder list
    private var timer: Timer?

    init() {
        // Set default main folder to user's Documents
        mainFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        startAutoRefresh()
    }

    // Start timer to refresh subfolders every second
    func startAutoRefresh() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.refreshSubFolders()
        }
    }

    deinit {
        timer?.invalidate()
    }

    // Reloads subfolders from the main folder
    func refreshSubFolders() {
        if let mainFolder = mainFolder {
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: mainFolder, includingPropertiesForKeys: nil)
                self.subFolders = contents.filter { $0.hasDirectoryPath }
            } catch {
                print("Sub-folder loading error : \(error)")
            }
        }
    }
}

