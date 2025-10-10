//  DataverseTabView.swift
//  View for configuring and uploading files to a Dataverse dataset with optional ZIP compression.

import SwiftUI
import AppKit

struct DataverseTabView: View {
    @EnvironmentObject var viewModel: DataverseViewModel
    let client = DataverseClient()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("Dataverse configuration", comment: "Section title for Dataverse settings")).font(.headline)
            
            // Dataverse server address
            HStack {
                (Text(NSLocalizedString("Dataverse Address", comment: "Label for Dataverse URL field")) + Text(":"))
                TextField(NSLocalizedString("Dataverse Address", comment: "Placeholder for Dataverse URL field"), text: $viewModel.dataverseAddress)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            // API token
            HStack {
                Text(NSLocalizedString("Token:", comment: "Label for API token field"))
                TextField(NSLocalizedString("API Token", comment: "Placeholder for API token field"), text: $viewModel.token)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            // Target dataset DOI
            HStack {
                Text(NSLocalizedString("Dataset DOI:", comment: "Label for dataset DOI field"))
                TextField(NSLocalizedString("DOI (e.g. https://doi.org/10.34810/data1785)", comment: "Placeholder example for dataset DOI"), text: $viewModel.datasetDOI)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            Divider()
            
            // File/folder selection
            HStack {
                Button(NSLocalizedString("Select folder/file", comment: "Button to select files or directories")) {
                    selectFiles()
                }
                Text(String(format: NSLocalizedString("%lld selected elements", comment: "Summary of selected items for upload"), viewModel.selectedFiles.count))
            }
            
            // ZIP compression toggle and name input
            Toggle(NSLocalizedString("ZIP compression", comment: "Toggle to enable ZIP compression"), isOn: $viewModel.compressFiles)
            if viewModel.compressFiles {
                HStack {
                    (Text(NSLocalizedString("ZIP file name", comment: "Label for ZIP file name input")) + Text(":"))
                    TextField(NSLocalizedString("ZIP file name", comment: "Placeholder for ZIP file name input"), text: $viewModel.zipFileName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            
            // Upload button with progress
            Button(action: uploadAction) {
                if viewModel.isUploading {
                    ProgressView(value: viewModel.uploadProgress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle())
                } else {
                    Text(NSLocalizedString("Upload", comment: "Button to start uploading"))
                }
            }
            .disabled(viewModel.selectedFiles.isEmpty ||
                      viewModel.datasetDOI.isEmpty ||
                      viewModel.dataverseAddress.isEmpty ||
                      viewModel.token.isEmpty ||
                      viewModel.isUploading)
            
            Divider()
            
            // API response display
            Text(NSLocalizedString("API response:", comment: "Label for API response field"))
            ScrollView {
                Text(viewModel.apiResponse)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 200)
        }
        .padding()
    }
    
    // File/folder selection handler
    func selectFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        if panel.runModal() == .OK {
            viewModel.selectedFiles = panel.urls
        }
    }
    
    // Upload button action handler
    func uploadAction() {
        viewModel.isUploading = true
        viewModel.apiResponse = ""
        viewModel.uploadProgress = 0.0
        
        DispatchQueue.global(qos: .userInitiated).async {
            var fileToUpload: URL?
            do {
                // Compress if requested and multiple files are selected
                if viewModel.compressFiles && viewModel.selectedFiles.count > 1 {
                    fileToUpload = try client.compressFiles(files: viewModel.selectedFiles, zipName: viewModel.zipFileName)
                } else {
                    fileToUpload = viewModel.selectedFiles.first
                }
                guard let fileURL = fileToUpload else {
                    DispatchQueue.main.async {
                        viewModel.apiResponse = NSLocalizedString("No file to upload.", comment: "Status when no file is available for upload")
                        viewModel.isUploading = false
                    }
                    return
                }
                
                // Upload to Dataverse
                client.uploadFile(fileURL: fileURL,
                                  dataverseAddress: viewModel.dataverseAddress,
                                  token: viewModel.token,
                                  datasetDOI: viewModel.datasetDOI,
                                  progressHandler: { progress in
                                      DispatchQueue.main.async {
                                          viewModel.uploadProgress = progress
                                      }
                                  },
                                  completion: { result in
                                      DispatchQueue.main.async {
                                          switch result {
                                          case .success(let response):
                                              viewModel.apiResponse = response
                                          case .failure(let error):
                                              let template = NSLocalizedString("Error: %@", comment: "Template for displaying upload errors")
                                              viewModel.apiResponse = String(format: template, error.localizedDescription)
                                          }
                                          viewModel.isUploading = false
                                      }
                                  })
            } catch {
                DispatchQueue.main.async {
                    let template = NSLocalizedString("Compression error: %@", comment: "Template for displaying compression errors")
                    viewModel.apiResponse = String(format: template, error.localizedDescription)
                    viewModel.isUploading = false
                }
            }
        }
    }
}

struct DataverseTabView_Previews: PreviewProvider {
    static var previews: some View {
        DataverseTabView()
            .environmentObject(DataverseViewModel())
    }
}
