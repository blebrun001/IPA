//  DataverseTabView.swift
//  View for configuring and uploading files to a Dataverse dataset with optional ZIP compression.

import SwiftUI
import AppKit

struct DataverseTabView: View {
    @EnvironmentObject var viewModel: DataverseViewModel
    let client = DataverseClient()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dataverse configuration").font(.headline)
            
            // Dataverse server address
            HStack {
                Text("Dataverse Addresse:")
                TextField("Dataverse Addresse", text: $viewModel.dataverseAddress)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            // API token
            HStack {
                Text("Token:")
                TextField("API Token", text: $viewModel.token)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            // Target dataset DOI
            HStack {
                Text("Dataset DOI:")
                TextField("DOI (ex: https://doi.org/10.34810/data1785)", text: $viewModel.datasetDOI)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            Divider()
            
            // File/folder selection
            HStack {
                Button("Select folder/file") {
                    selectFiles()
                }
                Text("\(viewModel.selectedFiles.count) selected elements")
            }
            
            // ZIP compression toggle and name input
            Toggle("ZIP compression", isOn: $viewModel.compressFiles)
            if viewModel.compressFiles {
                HStack {
                    Text("ZIP file name:")
                    TextField("ZIP file name", text: $viewModel.zipFileName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            
            // Upload button with progress
            Button(action: uploadAction) {
                if viewModel.isUploading {
                    ProgressView(value: viewModel.uploadProgress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle())
                } else {
                    Text("Upload")
                }
            }
            .disabled(viewModel.selectedFiles.isEmpty ||
                      viewModel.datasetDOI.isEmpty ||
                      viewModel.dataverseAddress.isEmpty ||
                      viewModel.token.isEmpty ||
                      viewModel.isUploading)
            
            Divider()
            
            // API response display
            Text("API response:")
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
                        viewModel.apiResponse = "No file to upload."
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
                                              viewModel.apiResponse = "Error: \(error.localizedDescription)"
                                          }
                                          viewModel.isUploading = false
                                      }
                                  })
            } catch {
                DispatchQueue.main.async {
                    viewModel.apiResponse = "Compression error: \(error.localizedDescription)"
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
