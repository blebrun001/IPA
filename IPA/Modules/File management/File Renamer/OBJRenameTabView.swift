//  OBJRenameTabView.swift
//  View providing a UI for renaming folders, files, and OBJ/MTL content by replacing a given string.

import SwiftUI

struct OBJRenameTabView: View {
    @EnvironmentObject var viewModel: OBJRenamerViewModel

    var body: some View {
        VStack(spacing: 15) {
            // Folder selection
            HStack {
                Button("Select Folder") {
                    viewModel.folder = selectFolder()
                }
                if let url = viewModel.folder {
                    Text(url.lastPathComponent)
                        .foregroundColor(.secondary)
                }
            }

            // Old name input
            HStack {
                Text("Old name:")
                TextField("Old name", text: $viewModel.oldName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            // New name input
            HStack {
                Text("New name:")
                TextField("New name", text: $viewModel.newName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            // Rename button
            Button("Rename") {
                viewModel.rename()
            }
            .padding(.top)

            // Display renaming results
            ScrollView {
                Text(viewModel.resultText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()
        }
        .padding()
    }

    // Opens a folder selection dialog
    private func selectFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        return (panel.runModal() == .OK) ? panel.url : nil
    }
}
