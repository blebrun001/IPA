//  PhotogrammetryTabView.swift
//  View for launching and configuring photogrammetry 3D model generation.

import SwiftUI
import RealityKit
import UniformTypeIdentifiers

struct PhotogrammetryTabView: View {
    
    @EnvironmentObject var settings: SettingsManager
    
    @ObservedObject var viewModel: PhotogrammetryViewModel
    private let photogrammetry = PhotogrammetryManager.shared

    // Available export formats
    enum ExportFormat: String, CaseIterable {
        case usdz = "USDZ", obj = "OBJ"
    }

    // Texture compression levels
    enum TextureCompressionLevel: CaseIterable, Identifiable {
        case none, low, medium, high

        var id: Self { self }

        var localizedName: LocalizedStringKey {
            switch self {
            case .none: return "None"
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            }
        }
    }
    
    // Local toggles bound to shared deletion flags
    @State private var shouldDeleteUSDAFiles = true
    @State private var shouldDeleteAO = false
    @State private var shouldDeleteDisplacement = false
    @State private var shouldDeleteNormal = false
    @State private var shouldDeleteRoughness = false

    // Error alert state
    @State private var showErrorAlert = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Main folder selection (specimen root)
            VStack(alignment: .leading, spacing: 10) {
                Text(NSLocalizedString("Specimen", comment: "Section title for specimen selection"))
                    .font(.headline)
                HStack {
                    if let folder = viewModel.mainFolder {
                        Text(folder.lastPathComponent)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(NSLocalizedString("No folder selected.", comment: "Message when no folder is chosen"))
                            .foregroundColor(.gray)
                    }
                    Button(NSLocalizedString("Choose", comment: "Button to choose folder")) { selectMainFolder() }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 2))
                .onDrop(of: [UTType.folder.identifier], isTargeted: nil) { providers in
                    handleMainFolderDrop(providers: providers)
                }
            }

            // Subfolder selection (individual bone/photo set)
            if !viewModel.subFolders.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 10) {
                    Text(NSLocalizedString("Bone", comment: "Section title for bone selection"))
                        .font(.headline)

                    List(viewModel.subFolders.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }), id: \.self, selection: $viewModel.selectedSubFolder) { folder in
                        Text(folder.lastPathComponent)
                            .onTapGesture {
                                viewModel.selectedSubFolder = folder
                            }
                    }
                    .frame(maxHeight: 300) // Définit une hauteur maximale avec scroll intégré
                }
                    .onChange(of: viewModel.selectedSubFolder) {
                        if let sub = viewModel.selectedSubFolder {
                            viewModel.inputFolder = sub.appendingPathComponent("photos")
                            viewModel.fileName = sub.lastPathComponent
                            if viewModel.exportFormat == .obj {
                                viewModel.outputFolder = sub
                            }
                        }
                    }
                }
                .padding(.vertical)
            }

            // Parameters and export options
            HStack {
                (Text(NSLocalizedString("3D model name", comment: "Label for 3D model name field")) + Text(":"))
                TextField(NSLocalizedString("3D model name", comment: "Placeholder for 3D model name field"), text: $viewModel.fileName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            HStack {
                Picker(NSLocalizedString("Export format", comment: "Picker label for export format"), selection: $viewModel.exportFormat) {
                    Text(NSLocalizedString("USDZ", comment: "Export format USDZ" )).tag(ExportFormat.usdz)
                    Text(NSLocalizedString("OBJ", comment: "Export format OBJ" )).tag(ExportFormat.obj)
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: viewModel.exportFormat) {
                    if viewModel.exportFormat == .obj, let sub = viewModel.selectedSubFolder {
                        viewModel.outputFolder = sub
                    }
                }
            }

            HStack {
                Picker(NSLocalizedString("Detail level", comment: "Picker label for detail level"), selection: $viewModel.detail) {
                    Text(NSLocalizedString("Preview", comment: "Detail level preview" )).tag(PhotogrammetrySession.Request.Detail.preview)
                    Text(NSLocalizedString("Reduced", comment: "Detail level reduced" )).tag(PhotogrammetrySession.Request.Detail.reduced)
                    Text(NSLocalizedString("Medium", comment: "Detail level medium" )).tag(PhotogrammetrySession.Request.Detail.medium)
                    Text(NSLocalizedString("Full", comment: "Detail level full" )).tag(PhotogrammetrySession.Request.Detail.full)
                    Text(NSLocalizedString("Raw", comment: "Detail level raw" )).tag(PhotogrammetrySession.Request.Detail.raw)
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            HStack {
                Picker(NSLocalizedString("Photos order", comment: "Picker label for photos ordering"), selection: $viewModel.sampleOrdering) {
                    Text(NSLocalizedString("Unordered", comment: "Sample ordering unordered" )).tag(PhotogrammetrySession.Configuration.SampleOrdering.unordered)
                    Text(NSLocalizedString("Sequential", comment: "Sample ordering sequential" )).tag(PhotogrammetrySession.Configuration.SampleOrdering.sequential)
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            HStack {
                Picker(NSLocalizedString("Sensitivity:", comment: "Picker label for feature sensitivity"), selection: $viewModel.featureSensitivity) {
                    Text(NSLocalizedString("Normal", comment: "Feature sensitivity normal" )).tag(PhotogrammetrySession.Configuration.FeatureSensitivity.normal)
                    Text(NSLocalizedString("High", comment: "Feature sensitivity high" )).tag(PhotogrammetrySession.Configuration.FeatureSensitivity.high)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            HStack {
                Picker(NSLocalizedString("Mask:", comment: "Picker label for mask mode"), selection: $viewModel.maskMode) {
                    Text(NSLocalizedString("Isolate from environment", comment: "Mask option isolate from environment" )).tag(PhotogrammetryManager.MaskMode.isolate)
                    Text(NSLocalizedString("Include environment", comment: "Mask option include environment" )).tag(PhotogrammetryManager.MaskMode.include)
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            HStack {
                Picker(NSLocalizedString("Texture compression:", comment: "Picker label for texture compression"), selection: $viewModel.textureCompressionLevel) {
                    ForEach(TextureCompressionLevel.allCases, id: \.self) { level in
                        Text(level.localizedName).tag(level)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            // File cleanup options after export
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(NSLocalizedString("Files to delete after export", comment: "Label for cleanup toggles"))

                Toggle(NSLocalizedString("USDA", comment: "Toggle label for deleting USDA files"), isOn: Binding(
                    get: { PhotogrammetryManager.shared.shouldDeleteUSDAFiles },
                    set: { PhotogrammetryManager.shared.shouldDeleteUSDAFiles = $0 }
                ))
                Toggle(NSLocalizedString("AO", comment: "Toggle label for deleting ambient occlusion files"), isOn: Binding(
                    get: { PhotogrammetryManager.shared.shouldDeleteAO },
                    set: { PhotogrammetryManager.shared.shouldDeleteAO = $0 }
                ))
                Toggle(NSLocalizedString("Displacement", comment: "Toggle label for deleting displacement maps"), isOn: Binding(
                    get: { PhotogrammetryManager.shared.shouldDeleteDisplacement },
                    set: { PhotogrammetryManager.shared.shouldDeleteDisplacement = $0 }
                ))
                Toggle(NSLocalizedString("Normal", comment: "Toggle label for deleting normal maps"), isOn: Binding(
                    get: { PhotogrammetryManager.shared.shouldDeleteNormal },
                    set: { PhotogrammetryManager.shared.shouldDeleteNormal = $0 }
                ))
                Toggle(NSLocalizedString("Roughness", comment: "Toggle label for deleting roughness maps"), isOn: Binding(
                    get: { PhotogrammetryManager.shared.shouldDeleteRoughness },
                    set: { PhotogrammetryManager.shared.shouldDeleteRoughness = $0 }
                ))
            }.frame(maxWidth: .infinity, alignment: .leading)
            
            // Capture controls
            HStack(spacing: 20) {
                Button(NSLocalizedString("Start", comment: "Button to start photogrammetry")) {
                    if settings.enableSound {
                        SoundPlayer.playSound(named: "start_capture")
                    }
                    startCapture()
                }
                    .disabled(viewModel.isProcessing)
                
                Button(NSLocalizedString("Stop", comment: "Button to stop photogrammetry")) {
                    if settings.enableSound {
                        SoundPlayer.playSound(named: "stop_capture")
                    }
                    photogrammetry.stopCapture()
                    viewModel.isProcessing = false
                    viewModel.statusMessage = NSLocalizedString("Process stopped by user.", comment: "Status when user stops photogrammetry")
                }
                .disabled(!viewModel.isProcessing)
            }

            // Progress feedback
            if viewModel.isProcessing {
                VStack(spacing: 20) {
                    HStack {
                        ProgressView(value: viewModel.progress)
                            .frame(width: 300)
                        Text(String(format: NSLocalizedString("%lld%%", comment: "Progress percentage"), Int64(viewModel.progress * 100)))
                            .frame(width: 50, alignment: .leading)
                    }
                    
                    AnimatedLoader()
                        .frame(width: 30, height: 30)
                        .padding(.top, 1)
                        .opacity(1)
                }
            }

            // Status message
            Text(viewModel.statusMessage)
                .foregroundColor(.blue)
                .padding(.top, 10)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .alert(NSLocalizedString("Error", comment: "Generic error title"), isPresented: $showErrorAlert) {
            Button(NSLocalizedString("OK", comment: "Dismiss error alert"), role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Folder Selection Helpers
    
    // Opens folder picker for main specimen folder
    private func selectMainFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.mainFolder = url
            loadSubFolders(from: url)
        }
    }
    
    // Loads all visible subfolders inside the main folder
    private func loadSubFolders(from url: URL) {
        do {
            let items = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            viewModel.subFolders = items.filter { item in
                (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            }
        } catch {
            let template = NSLocalizedString("Main folder read error: %@", comment: "Status when reading main folder fails")
            viewModel.statusMessage = String(format: template, error.localizedDescription)
        }
    }
    
    // Handles folder drop into the UI
    private func handleMainFolderDrop(providers: [NSItemProvider]) -> Bool {
        if let provider = providers.first {
            provider.loadItem(forTypeIdentifier: UTType.folder.identifier, options: nil) { (urlData, error) in
                DispatchQueue.main.async {
                    if let url = urlData as? URL {
                        self.viewModel.mainFolder = url
                        self.loadSubFolders(from: url)
                    }
                }
            }
            return true
        }
        return false
    }
    
    // MARK: - Photogrammetry Start

    // Starts the photogrammetry process using the configured options
    private func startCapture() {
        guard let input = viewModel.inputFolder, let output = viewModel.outputFolder else {
            viewModel.statusMessage = NSLocalizedString("Please select main folder and sub-folder containing a 'photos' folder.", comment: "Status when folder selection is incomplete")
            return
        }
        guard FileManager.default.fileExists(atPath: input.path) else {
            viewModel.statusMessage = NSLocalizedString("No 'photos' folder in selected sub-folder.", comment: "Status when photos folder missing")
            return
        }
        viewModel.isProcessing = true
        viewModel.progress = 0.0
        viewModel.statusMessage = NSLocalizedString("Processing", comment: "Status while photogrammetry is running")
        viewModel.startTime = Date()
        
        Task {
            await photogrammetry.startCapture(
                inputFolder: input,
                outputFolder: output,
                fileName: viewModel.fileName,
                detail: viewModel.detail,
                sampleOrdering: viewModel.sampleOrdering,
                featureSensitivity: viewModel.featureSensitivity,
                exportFormat: viewModel.exportFormat.rawValue,
                maskMode: viewModel.maskMode,
                compressImages: viewModel.textureCompressionLevel != .none,
                compressionQuality: compressionQualityValue(for: viewModel.textureCompressionLevel),
                onProgressUpdate: { newProgress in
                    DispatchQueue.main.async { self.viewModel.progress = newProgress }
                },
                onCompletion: { fileURL in
                    DispatchQueue.main.async {
                        self.viewModel.isProcessing = false
                        let duration = Date().timeIntervalSince(self.viewModel.startTime ?? Date())
                        let durationString = String(format: NSLocalizedString("%.2f", comment: "Two-decimal duration"), duration)
                        let template = NSLocalizedString("Processed in %@ sec. File: %@", comment: "Status after photogrammetry completes")
                        self.viewModel.statusMessage = String(format: template, durationString, fileURL.lastPathComponent)
                    }
                },
                onError: { message in
                    DispatchQueue.main.async {
                        self.viewModel.isProcessing = false
                        self.errorMessage = message
                        self.viewModel.statusMessage = message
                        self.showErrorAlert = true
                    }
                }
            )
        }
    }
    
    // Maps compression level to JPEG compression quality
    private func compressionQualityValue(for level: TextureCompressionLevel) -> CGFloat {
        switch level {
        case .none:   return 1.0
        case .low:    return 0.8
        case .medium: return 0.5
        case .high:   return 0.3
        }
    }
}

// Preview with a sample ViewModel instance
struct PhotogrammetryTabView_Previews: PreviewProvider {
    static var previews: some View {
        // Pour le preview, vous pouvez créer une instance test du view model
        PhotogrammetryTabView(viewModel: PhotogrammetryViewModel())
    }
}
