//  OBJRenamerViewModel.swift
//  ViewModel for managing user input and logic related to the OBJ renaming process.

import Foundation
import SwiftUI

class OBJRenamerViewModel: ObservableObject {
    
    // Folder selected by the user
    @Published var folder: URL? = nil {
        didSet {
            
            // Automatically populate oldName with the folder name
            if let folder = folder {
                oldName = folder.lastPathComponent
            }
        }
    }
    @Published var oldName: String = ""
    @Published var newName: String = ""
    @Published var resultText: String = ""

    // Launches the renaming process and updates the result text.
    func rename() {
        guard let folder = folder else {
            resultText = "No folder selected."
            return
        }

        let renamer = OBJRenamer()
        let results = renamer.renameModels(in: folder, oldName: oldName, newName: newName)
        resultText = results.joined(separator: "\n")
    }
}
