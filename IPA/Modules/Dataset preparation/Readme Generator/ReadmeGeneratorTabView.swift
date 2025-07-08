//  ReadmeGeneratorTabView.swift
//  View providing a form to generate a README.txt file with dataset metadata, folder structure, and comments.

import SwiftUI
import UniformTypeIdentifiers

struct ReadmeGeneratorTabView: View {
    @EnvironmentObject var viewModel: ReadmeGeneratorViewModel
    private let readmeGenerator = ReadmeGenerator()
    
    let sexOptions = ["female", "male", "hermaphrodite", "unknown"]
    let lifeStageOptions = ["juvenile", "adult", "senescent", "unknown"]
    let languageOptions = ["ENG", "CAT", "CAS", "FRA"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 15) {
                // Folder selection
                VStack(alignment: .leading, spacing: 10) {
                    Text("Working folder")
                        .font(.headline)
                    
                    HStack {
                        if let folder = viewModel.folder {
                            Text(folder.lastPathComponent)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        } else {
                            Text("No folder selected.")
                                .foregroundColor(.gray)
                        }
                        Button("Choose") {
                            selectFolderAction()
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 2)
                    )
                    .onDrop(of: [UTType.folder.identifier], isTargeted: nil, perform: dropHandler)
                }
                
                // Metadata parameters
                Group {
                    HStack {
                        Text("Dataset Title:")
                        TextField("", text: $viewModel.datasetTitle)
                    }
                    HStack {
                        Text("Authorship:")
                        TextField("", text: $viewModel.authorship)
                    }
                    HStack {
                        Text("Contact:")
                        TextField("", text: $viewModel.contact)
                    }
                    HStack {
                        Text("Language:")
                        Picker("", selection: $viewModel.language) {
                            ForEach(languageOptions, id: \.self) { lang in
                                Text(lang).tag(lang)
                            }
                        }
                    }
                    HStack {
                        Text("Specimen:")
                        TextField("", text: $viewModel.specimen)
                    }
                    HStack {
                        Text("Sex:")
                        Picker("", selection: $viewModel.sex) {
                            ForEach(sexOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                    }
                    HStack {
                        Text("Life Stage:")
                        Picker("", selection: $viewModel.lifeStage) {
                            ForEach(lifeStageOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                    }
                    HStack {
                        Text("Number of Scanned Items:")
                        TextField("", text: $viewModel.scannedItems)
                    }
                    HStack {
                        Text("Technique Used:")
                        TextField("", text: $viewModel.technique)
                    }
                    HStack {
                        Text("Licence:")
                        TextField("", text: $viewModel.licence)
                    }
                    HStack {
                        Text("DOI:")
                        TextField("", text: $viewModel.doi)
                    }
                    HStack {
                        Text("Folder Size (Go):")
                        TextField("", text: $viewModel.fileSize)
                    }
                    HStack {
                        Text("Number of Files:")
                        TextField("", text: $viewModel.numFiles)
                    }
                }
                
                // Folder structure description
                VStack(alignment: .leading) {
                    Text("Structure:")
                    TextEditor(text: $viewModel.structure)
                        .frame(height: 80)
                        .border(Color.gray)
                }
                
                // Comments section
                VStack(alignment: .leading) {
                    Text("Comments:")
                    TextEditor(text: $viewModel.comments)
                        .frame(height: 80)
                        .border(Color.gray)
                }
                
                Button("Generate README") {
                    generateReadme()
                }
                Text(viewModel.resultMessage)
                    .foregroundColor(.blue)
            }
            .padding()
        }
    }
    
    // MARK: - Folder selection & drop handling
    
    private func dropHandler(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.folder.identifier, options: nil) { (item, error) in
                DispatchQueue.main.async {
                    if let url = item as? URL {
                        viewModel.folder = url
                        updateFolderInfo(for: url)
                    }
                }
            }
        }
        return true
    }
    
    private func selectFolderAction() {
        if let selectedFolder = selectFolder() {
            viewModel.folder = selectedFolder
            updateFolderInfo(for: selectedFolder)
        }
    }
    
    private func selectFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        return (panel.runModal() == .OK) ? panel.url : nil
    }
    
    private func updateFolderInfo(for folder: URL) {
        let fileManager = FileManager.default
        let folderName = folder.lastPathComponent
        
        var totalFileCount = 0
        var totalSize: Int64 = 0
        
        if let enumerator = fileManager.enumerator(at: folder,
                                                    includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                                                    options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                    if resourceValues.isRegularFile == true {
                        totalFileCount += 1
                        if let fileSizeValue = resourceValues.fileSize {
                            totalSize += Int64(fileSizeValue)
                        }
                    }
                } catch {
                    print("Error while reading file: \(error)")
                }
            }
        }
        
        var scannedDirCount = 0
        do {
            let contents = try fileManager.contentsOfDirectory(at: folder,
                                                               includingPropertiesForKeys: [.isDirectoryKey],
                                                               options: [.skipsHiddenFiles])
            scannedDirCount = contents.filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            }.count
        } catch {
            print("Error while reading folder: \(error)")
        }
        
        DispatchQueue.main.async {
            viewModel.datasetTitle = folderName
            viewModel.specimen = folderName
            viewModel.numFiles = "\(totalFileCount)"
            let sizeInGo = Double(totalSize) / 1073741824.0
            viewModel.fileSize = String(format: "%.2f", sizeInGo)
            viewModel.scannedItems = "\(scannedDirCount)"
        }
    }
    
    // Opens a save dialog and generates the README file
    private func generateReadme() {
        guard viewModel.folder != nil else {
            viewModel.resultMessage = "Select a folder."
            return
        }
        let savePanel = NSSavePanel()
        if #available(macOS 12.0, *) {
            savePanel.allowedContentTypes = [.plainText]
        } else {
            savePanel.allowedFileTypes = ["txt"]
        }
        savePanel.nameFieldStringValue = "README.txt"
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                let params: [String: String] = [
                    "datasetTitle": viewModel.datasetTitle,
                    "authorship": viewModel.authorship,
                    "contact": viewModel.contact,
                    "language": viewModel.language,
                    "specimen": viewModel.specimen,
                    "sex": viewModel.sex,
                    "lifeStage": viewModel.lifeStage,
                    "scannedItems": viewModel.scannedItems,
                    "technique": viewModel.technique,
                    "licence": viewModel.licence,
                    "doi": viewModel.doi,
                    "fileSize": viewModel.fileSize,
                    "numFiles": viewModel.numFiles
                ]
                do {
                    try readmeGenerator.generateReadme(parameters: params,
                                                       structure: viewModel.structure,
                                                       comments: viewModel.comments,
                                                       outputURL: url)
                    viewModel.resultMessage = "README generated: \(url.path)"
                } catch {
                    viewModel.resultMessage = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct ReadmeGeneratorTabView_Previews: PreviewProvider {
    static var previews: some View {
        ReadmeGeneratorTabView()
            .environmentObject(ReadmeGeneratorViewModel())
    }
}
