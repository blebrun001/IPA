//  BoneFolderTabView.swift
//  UI for generating standardized bone folders with optional photos subdirectories.

import SwiftUI
import UniformTypeIdentifiers

struct BoneFolderTabView: View {
    @EnvironmentObject var viewModel: BoneFolderViewModel
    @EnvironmentObject var photogrammetryVM: PhotogrammetryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox(label: Text(NSLocalizedString("Working directory", comment: "Section title for working directory"))) {
                Text(photogrammetryVM.mainFolder?.path ?? NSLocalizedString("No folder selected.", comment: "Message when no folder is selected"))
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(4)
            }

            GroupBox(label: Text(NSLocalizedString("Bone name (UBERON)", comment: "Section title for bone name input"))) {
                VStack(alignment: .leading) {
                    TextField(NSLocalizedString("Type bone name", comment: "Placeholder for bone name input"), text: $viewModel.query)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if !viewModel.suggestions.isEmpty {
                        List(viewModel.suggestions.prefix(5), id: \.obo_id) { suggestion in
                            Button(action: {
                                viewModel.selectedSuggestion = suggestion
                                viewModel.query = "\(suggestion.obo_id)_\(suggestion.label)"
                                viewModel.suggestions = []
                            }) {
                                VStack(alignment: .leading) {
                                    Text(suggestion.label)
                                        .fontWeight(.medium)
                                    Text(suggestion.obo_id)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .frame(height: 150)
                    }
                }
            }

            Toggle(NSLocalizedString("Create 'photos' subfolder", comment: "Toggle to create photos subfolder"), isOn: $viewModel.shouldCreatePhotosSubfolder)

            Button(NSLocalizedString("Create folder", comment: "Button to create bone folder")) {
                viewModel.createFolder(at: photogrammetryVM.mainFolder)
            }
            .buttonStyle(.borderedProminent)
            
            Text(viewModel.statusMessage)
                .font(.callout)
                .foregroundColor(.blue)
                .padding(.top, 4)

            Spacer()
            
            
        }
        .padding()
        .frame(minWidth: 500)
    }
}
