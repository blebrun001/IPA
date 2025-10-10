//  FolderStructureTabView.swift
//  View for defining and generating folder structures, either from a list of terms or a repeated base term.

import SwiftUI

struct FolderStructureTabView: View {
    @EnvironmentObject var viewModel: FolderStructureViewModel
    private let folderStructureGenerator = FolderStructureGenerator()
    
    var body: some View {
        VStack(spacing: 15) {
            // Base folder selection
            HStack {
                Button(NSLocalizedString("Select base directory", comment: "Button to choose root folder")) {
                    viewModel.baseDir = selectFolder()
                }
                if let url = viewModel.baseDir {
                    Text(url.lastPathComponent)
                        .foregroundColor(.secondary)
                }
            }
            
            // Toggle between unique term mode and manual list
            Toggle(NSLocalizedString("Automatically generate unique term", comment: "Toggle to build repeated folder names"), isOn: $viewModel.useSingleTerm)
                .padding(.vertical, 5)

            if viewModel.useSingleTerm {
                // Inputs for single term and number of folders
                TextField(NSLocalizedString("Term name (e.g. Rib)", comment: "Placeholder for base term"), text: $viewModel.singleTerm)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField(NSLocalizedString("Number of folders", comment: "Placeholder for number of folders"), text: $viewModel.termCount)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            } else {
                // Manual term list input
                VStack(alignment: .leading) {
                    Text(NSLocalizedString("Terms:", comment: "Heading for manual term list"))
                        .font(.headline)
                    
                    ForEach(viewModel.terms, id: \.self) { term in
                        HStack {
                            Text(term)
                            Spacer()
                            Button(action: { removeTerm(term) }) {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    HStack {
                        TextField(NSLocalizedString("Add a term", comment: "Placeholder for term input"), text: $viewModel.newTerm, onCommit: addTerm)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button(action: addTerm) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
            }
            
            // Subfolder structure input
            VStack(alignment: .leading) {
                Text(NSLocalizedString("Structure (one folder per line):", comment: "Heading for structure list"))
                    .font(.headline)
                
                ForEach(viewModel.structure, id: \.self) { folder in
                    HStack {
                        Text(folder)
                        Spacer()
                        Button(action: { removeStructure(folder) }) {
                            Image(systemName: "minus.circle")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                HStack {
                    TextField(NSLocalizedString("Add a folder", comment: "Placeholder for subfolder input"), text: $viewModel.newStructure, onCommit: addStructure)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button(action: addStructure) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            
            // Generate folder structure
            Button(NSLocalizedString("Generate structure", comment: "Button to create folder structure")) {
                generateStructure()
            }
            Text(viewModel.resultMessage)
                .foregroundColor(.blue)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Private functions
    
    private func addTerm() {
        let trimmed = viewModel.newTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.terms.append(trimmed)
        viewModel.newTerm = ""
    }
    
    private func removeTerm(_ term: String) {
        viewModel.terms.removeAll { $0 == term }
    }
    
    private func addStructure() {
        let trimmed = viewModel.newStructure.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.structure.append(trimmed)
        viewModel.newStructure = ""
    }
    
    private func removeStructure(_ folder: String) {
        viewModel.structure.removeAll { $0 == folder }
    }
    
    private func selectFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        return (panel.runModal() == .OK) ? panel.url : nil
    }
    
    private func generateStructure() {
        guard let base = viewModel.baseDir, !viewModel.structure.isEmpty else {
            viewModel.resultMessage = NSLocalizedString("Fill all fields.", comment: "Error when folder structure form incomplete")
            return
        }
        
        let termList: [String]
        if viewModel.useSingleTerm {
            // Build folder names from a single base term + roman numerals
            guard !viewModel.singleTerm.isEmpty,
                  let count = Int(viewModel.termCount),
                  count > 0 else {
                viewModel.resultMessage = NSLocalizedString("Fill term and number.", comment: "Error when single term inputs missing")
                return
            }
            termList = (1...count).map { index in
                "\(viewModel.singleTerm)_\(romanNumeral(from: index))"
            }
        } else {
            guard !viewModel.terms.isEmpty else {
                viewModel.resultMessage = NSLocalizedString("Fill terms.", comment: "Error when no manual terms provided")
                return
            }
            termList = viewModel.terms
        }
        
        // Generate folders using structure
        folderStructureGenerator.generateFolderStructure(base: base,
                                                         terms: termList,
                                                         structure: viewModel.structure.joined(separator: "\n"))
        viewModel.resultMessage = NSLocalizedString("Folder structure generated successfully.", comment: "Status after creating folder structure")
    }
    
    // Convert an integer to a Roman numeral string
    private func romanNumeral(from number: Int) -> String {
        let romanMapping: [(Int, String)] = [
            (1000, "M"), (900, "CM"), (500, "D"), (400, "CD"),
            (100, "C"), (90, "XC"), (50, "L"), (40, "XL"),
            (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")
        ]
        var num = number
        var result = ""
        for (arabic, roman) in romanMapping {
            let count = num / arabic
            if count != 0 {
                result += String(repeating: roman, count: count)
                num -= arabic * count
            }
        }
        return result
    }
}

struct FolderStructureTabView_Previews: PreviewProvider {
    static var previews: some View {
        FolderStructureTabView()
            .environmentObject(FolderStructureViewModel())
    }
}
