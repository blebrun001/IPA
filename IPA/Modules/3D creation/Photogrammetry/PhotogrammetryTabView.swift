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

    
    
    var body: some View {
        VStack(spacing: 15) {
            // Main folder selection (specimen root)
            VStack(alignment: .leading, spacing: 10) {
                Text("Specimen")
                    .font(.headline)
                HStack {
                    if let folder = viewModel.mainFolder {
                        Text(folder.lastPathComponent)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("No folder selected.")
                            .foregroundColor(.gray)
                    }
                    Button("Choose") { selectMainFolder() }
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
                    Text("Bone")
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
                Text("3D model name:")
                TextField("3D model name", text: $viewModel.fileName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            HStack {
                Picker("Export format", selection: $viewModel.exportFormat) {
                    Text("USDZ").tag(ExportFormat.usdz)
                    Text("OBJ").tag(ExportFormat.obj)
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: viewModel.exportFormat) {
                    if viewModel.exportFormat == .obj, let sub = viewModel.selectedSubFolder {
                        viewModel.outputFolder = sub
                    }
                }
            }

            HStack {
                Picker("Detail level", selection: $viewModel.detail) {
                    Text("Preview").tag(PhotogrammetrySession.Request.Detail.preview)
                    Text("Reduced").tag(PhotogrammetrySession.Request.Detail.reduced)
                    Text("Medium").tag(PhotogrammetrySession.Request.Detail.medium)
                    Text("Full").tag(PhotogrammetrySession.Request.Detail.full)
                    Text("Raw").tag(PhotogrammetrySession.Request.Detail.raw)
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            HStack {
                Picker("Photos order", selection: $viewModel.sampleOrdering) {
                    Text("no").tag(PhotogrammetrySession.Configuration.SampleOrdering.unordered)
                    Text("sequential").tag(PhotogrammetrySession.Configuration.SampleOrdering.sequential)
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            HStack {
                Picker("Sensitivity:", selection: $viewModel.featureSensitivity) {
                    Text("Normal").tag(PhotogrammetrySession.Configuration.FeatureSensitivity.normal)
                    Text("High").tag(PhotogrammetrySession.Configuration.FeatureSensitivity.high)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            HStack {
                Picker("Mask:", selection: $viewModel.maskMode) {
                    Text("Isolate from environment").tag(PhotogrammetryManager.MaskMode.isolate)
                    Text("Include environment").tag(PhotogrammetryManager.MaskMode.include)
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            HStack {
                Picker("Texture compression:", selection: $viewModel.textureCompressionLevel) {
                    ForEach(TextureCompressionLevel.allCases, id: \.self) { level in
                        Text(level.localizedName).tag(level)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            // File cleanup options after export
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text("Fichiers à supprimer après export")

                Toggle("Usda", isOn: Binding(
                    get: { PhotogrammetryManager.shared.shouldDeleteUSDAFiles },
                    set: { PhotogrammetryManager.shared.shouldDeleteUSDAFiles = $0 }
                ))
                Toggle("AO", isOn: Binding(
                    get: { PhotogrammetryManager.shared.shouldDeleteAO },
                    set: { PhotogrammetryManager.shared.shouldDeleteAO = $0 }
                ))
                Toggle("Disp", isOn: Binding(
                    get: { PhotogrammetryManager.shared.shouldDeleteDisplacement },
                    set: { PhotogrammetryManager.shared.shouldDeleteDisplacement = $0 }
                ))
                Toggle("Normal", isOn: Binding(
                    get: { PhotogrammetryManager.shared.shouldDeleteNormal },
                    set: { PhotogrammetryManager.shared.shouldDeleteNormal = $0 }
                ))
                Toggle("Rough", isOn: Binding(
                    get: { PhotogrammetryManager.shared.shouldDeleteRoughness },
                    set: { PhotogrammetryManager.shared.shouldDeleteRoughness = $0 }
                ))
            }.frame(maxWidth: .infinity, alignment: .leading)
            
            // Capture controls
            HStack(spacing: 20) {
                Button("Start") {
                    if settings.enableSound {
                        SoundPlayer.playSound(named: "start_capture")
                    }
                    startCapture()
                }
                    .disabled(viewModel.isProcessing)
                
                Button("Stop") {
                    if settings.enableSound {
                        SoundPlayer.playSound(named: "stop_capture")
                    }
                    photogrammetry.stopCapture()
                    viewModel.isProcessing = false
                    viewModel.statusMessage = "Process stoped by user."
                }
                .disabled(!viewModel.isProcessing)
            }

            // Progress feedback
            if viewModel.isProcessing {
                VStack(spacing: 20) {
                    HStack {
                        ProgressView(value: viewModel.progress)
                            .frame(width: 300)
                        Text("\(Int(viewModel.progress * 100))%")
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
            viewModel.statusMessage = "Main folder read error: \(error.localizedDescription)"
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
            viewModel.statusMessage = "Please select main folder and sub-folder containing a 'photos' folder."
            return
        }
        guard FileManager.default.fileExists(atPath: input.path) else {
            viewModel.statusMessage = "No 'photos' folder in selected sub-folder."
            return
        }
        viewModel.isProcessing = true
        viewModel.progress = 0.0
        viewModel.statusMessage = "Processing"
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
                        self.viewModel.statusMessage = "Processed in \(String(format: "%.2f", duration)) sec. File : \(fileURL.lastPathComponent)"
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
