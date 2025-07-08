import SwiftUI
import UniformTypeIdentifiers

struct BoneFolderTabView: View {
    @EnvironmentObject var viewModel: BoneFolderViewModel
    @EnvironmentObject var photogrammetryVM: PhotogrammetryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox(label: Text("Working directory")) {
                Text(photogrammetryVM.mainFolder?.path ?? "no folder selected")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(4)
            }

            GroupBox(label: Text("Bone name (UBERON)")) {
                VStack(alignment: .leading) {
                    TextField("type bone name", text: $viewModel.query)
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

            Toggle("Create 'photos' subfolder", isOn: $viewModel.shouldCreatePhotosSubfolder)

            Button("Create folder") {
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
    
    func importPhotos(to destination: URL, viewModel: BoneFolderViewModel) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.image]
        panel.canChooseDirectories = false

        panel.begin { response in
            if response == .OK {
                for url in panel.urls {
                    let destURL = destination.appendingPathComponent(url.lastPathComponent)
                    do {
                        try FileManager.default.copyItem(at: url, to: destURL)
                        DispatchQueue.main.async {
                            viewModel.statusMessage = "Importé : \(url.lastPathComponent)"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                viewModel.statusMessage = ""
                            }
                        }
                    } catch {
                        DispatchQueue.main.async {
                            viewModel.statusMessage = "Erreur d'import : \(url.lastPathComponent)"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                viewModel.statusMessage = ""
                            }
                        }
                    }
                }
            }
        }
    }
}
