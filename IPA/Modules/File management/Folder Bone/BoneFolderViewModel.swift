import Foundation
import SwiftUI
import Combine

class BoneFolderViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var suggestions: [UBERONDocument] = []
    @Published var shouldCreatePhotosSubfolder: Bool = true
    @Published var selectedSuggestion: UBERONDocument?
    @Published var statusMessage: String = ""
    @Published var photosFolderURL: URL?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        $query
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] newValue in
                self?.fetchSuggestions(for: newValue)
            }
            .store(in: &cancellables)
    }
    
    func fetchSuggestions(for text: String) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            self.suggestions = []
            return
        }

        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://www.ebi.ac.uk/ols/api/search?q=\(encodedText)&ontology=uberon&rows=10"
        
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else { return }
            do {
                let decoded = try JSONDecoder().decode(UBERONResponse.self, from: data)
                DispatchQueue.main.async {
                    self.suggestions = decoded.response.docs.filter { $0.label != nil && $0.obo_id != nil }
                }
            } catch {
                print("DDecoding failed: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    func createFolder(at parentURL: URL?) {
        guard let parent = parentURL, let suggestion = selectedSuggestion else {
            DispatchQueue.main.async {
                self.statusMessage = "Missing folder or selected bone."
            }
            return
        }

        let oboID = (suggestion.obo_id ?? "").replacingOccurrences(of: ":", with: "")
        let label = (suggestion.label ?? "").replacingOccurrences(of: " ", with: "_")
        let folderName = "\(oboID)_\(label)"

        let newFolder = parent.appendingPathComponent(folderName)

        do {
            try FileManager.default.createDirectory(at: newFolder, withIntermediateDirectories: true)
            
            if shouldCreatePhotosSubfolder {
                let photosFolder = newFolder.appendingPathComponent("photos")
                try FileManager.default.createDirectory(at: photosFolder, withIntermediateDirectories: true)
            }

            // Affichage du message de succès
            DispatchQueue.main.async {
                self.statusMessage = "Folder created: \(folderName)"
                // Efface le message après 3 secondes
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.statusMessage = ""
                }
            }

            print("Folder created : \(newFolder.path)")

        } catch {
            // Affichage du message d'erreur
            DispatchQueue.main.async {
                self.statusMessage = "Error: \(error.localizedDescription)"
                // Efface le message après 5 secondes
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self.statusMessage = ""
                }
            }

            print("Error while creating the folder : \(error.localizedDescription)")
        }
        DispatchQueue.main.async {
            self.photosFolderURL = newFolder.appendingPathComponent("photos")
            print("photosFolderURL set to:", self.photosFolderURL!.path)
        }
    }
}
