//  ReadmeGeneratorTabView.swift
//  View providing a form to generate a README.txt file with dataset metadata, folder structure, and comments.

import SwiftUI
import UniformTypeIdentifiers

struct ReadmeGeneratorTabView: View {
    @EnvironmentObject var viewModel: ReadmeGeneratorViewModel
    @EnvironmentObject var settings: SettingsManager
    private let readmeGenerator = ReadmeGenerator()
    
    let sexOptions = ["female", "male", "hermaphrodite", "unknown"]
    let lifeStageOptions = ["juvenile", "adult", "senescent", "unknown"]
    let languageOptions = ["ENG", "CAT", "CAS", "FRA"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 15) {
                // Folder selection
                VStack(alignment: .leading, spacing: 10) {
                    Text(NSLocalizedString("Working folder", comment: "Section title for working folder selection"))
                        .font(.headline)
                    
                    HStack {
                        if let folder = viewModel.folder {
                            Text(folder.lastPathComponent)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        } else {
                            Text(NSLocalizedString("No folder selected.", comment: "Message when no folder is selected"))
                                .foregroundColor(.gray)
                        }
                        Button(NSLocalizedString("Choose", comment: "Button to choose folder")) {
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
                        Text(NSLocalizedString("Dataset Title:", comment: "Label for dataset title field"))
                        TextField("", text: $viewModel.datasetTitle)
                    }
                    HStack {
                        Text(NSLocalizedString("Authorship:", comment: "Label for authorship field"))
                        TextField("", text: $viewModel.authorship)
                    }
                    HStack {
                        Text(NSLocalizedString("Contact:", comment: "Label for contact field"))
                        TextField("", text: $viewModel.contact)
                    }
                    HStack {
                        Text(NSLocalizedString("Language:", comment: "Label for language field"))
                        Picker("", selection: $viewModel.language) {
                            ForEach(languageOptions, id: \.self) { lang in
                                Text(localizedLanguageLabel(for: lang)).tag(lang)
                            }
                        }
                    }
                    HStack {
                        (Text(NSLocalizedString("Specimen", comment: "Label for specimen field")) + Text(":"))
                        TextField("", text: $viewModel.specimen)
                    }
                    HStack {
                        Text(NSLocalizedString("Sex:", comment: "Label for sex field"))
                        Picker("", selection: $viewModel.sex) {
                            ForEach(sexOptions, id: \.self) { option in
                                Text(localizedSexLabel(for: option)).tag(option)
                            }
                        }
                    }
                    HStack {
                        Text(NSLocalizedString("Life Stage:", comment: "Label for life stage field"))
                        Picker("", selection: $viewModel.lifeStage) {
                            ForEach(lifeStageOptions, id: \.self) { option in
                                Text(localizedLifeStageLabel(for: option)).tag(option)
                            }
                        }
                    }
                    HStack {
                        Text(NSLocalizedString("Number of Scanned Items:", comment: "Label for scanned items field"))
                        TextField("", text: $viewModel.scannedItems)
                    }
                    HStack {
                        Text(NSLocalizedString("Technique Used:", comment: "Label for technique field"))
                        TextField("", text: $viewModel.technique)
                    }
                    HStack {
                        Text(NSLocalizedString("Licence:", comment: "Label for licence field"))
                        TextField("", text: $viewModel.licence)
                    }
                    HStack {
                        Text(NSLocalizedString("DOI:", comment: "Label for DOI field"))
                        TextField("", text: $viewModel.doi)
                    }
                    Button {
                        openDataverseUpload()
                    } label: {
                        Label(NSLocalizedString("Open Dataverse upload", comment: "Button to open Dataverse upload module"), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    HStack {
                        Text(NSLocalizedString("Folder Size (GB):", comment: "Label for folder size field"))
                        TextField("", text: $viewModel.fileSize)
                    }
                    HStack {
                        Text(NSLocalizedString("Number of Files:", comment: "Label for file count field"))
                        TextField("", text: $viewModel.numFiles)
                    }
                }
                
                // Folder structure description
                VStack(alignment: .leading) {
                    Text(NSLocalizedString("Structure:", comment: "Label for structure text area"))
                    TextEditor(text: $viewModel.structure)
                        .frame(height: 80)
                        .border(Color.gray)
                }
                
                // Comments section
                VStack(alignment: .leading) {
                    Text(NSLocalizedString("Comments:", comment: "Label for comments text area"))
                    TextEditor(text: $viewModel.comments)
                        .frame(height: 80)
                        .border(Color.gray)
                }
                
                Button(NSLocalizedString("Generate README", comment: "Button to generate README file")) {
                    generateReadme()
                }
                Text(viewModel.resultMessage)
                    .foregroundColor(.blue)
            }
            .padding()
        }
    }
    
    // MARK: - Folder selection & drop handling

    private func localizedLanguageLabel(for code: String) -> String {
        switch code {
        case "ENG":
            return NSLocalizedString("English (ENG)", comment: "Language option English")
        case "CAT":
            return NSLocalizedString("Catalan (CAT)", comment: "Language option Catalan")
        case "CAS":
            return NSLocalizedString("Spanish (CAS)", comment: "Language option Spanish")
        case "FRA":
            return NSLocalizedString("French (FRA)", comment: "Language option French")
        default:
            return code
        }
    }

    private func localizedSexLabel(for value: String) -> String {
        switch value {
        case "female":
            return NSLocalizedString("Female", comment: "Sex option female")
        case "male":
            return NSLocalizedString("Male", comment: "Sex option male")
        case "hermaphrodite":
            return NSLocalizedString("Hermaphrodite", comment: "Sex option hermaphrodite")
        case "unknown":
            return NSLocalizedString("Unknown", comment: "Sex option unknown")
        default:
            return value
        }
    }

    private func localizedLifeStageLabel(for value: String) -> String {
        switch value {
        case "juvenile":
            return NSLocalizedString("Juvenile", comment: "Life stage option juvenile")
        case "adult":
            return NSLocalizedString("Adult", comment: "Life stage option adult")
        case "senescent":
            return NSLocalizedString("Senescent", comment: "Life stage option senescent")
        case "unknown":
            return NSLocalizedString("Unknown", comment: "Life stage option unknown")
        default:
            return value
        }
    }
    
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
    
    private func openDataverseUpload() {
        let candidate = viewModel.doi.trimmingCharacters(in: .whitespacesAndNewlines)
        if !candidate.isEmpty {
            settings.dataversePersistentId = candidate
        }
        NotificationCenter.default.post(name: .openDataverseUpload, object: nil)
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
            viewModel.resultMessage = NSLocalizedString("Select a folder.", comment: "Warning when no folder selected")
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
                    let template = NSLocalizedString("README generated: %@", comment: "Message when README has been generated")
                    viewModel.resultMessage = String(format: template, url.path)
                } catch {
                    let template = NSLocalizedString("Error: %@", comment: "Template for displaying generation errors")
                    viewModel.resultMessage = String(format: template, error.localizedDescription)
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
