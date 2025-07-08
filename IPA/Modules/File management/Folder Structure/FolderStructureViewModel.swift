//  FolderStructureViewModel.swift
//  ViewModel for managing user input and configuration for folder structure generation.

import Foundation
import SwiftUI

class FolderStructureViewModel: ObservableObject {
    @Published var baseDir: URL? = nil
    @Published var terms: [String] = []
    @Published var newTerm: String = ""
    @Published var structure: [String] = []
    @Published var newStructure: String = ""
    @Published var resultMessage: String = ""
    
    // Option to generate folders based on a single base term repeated with suffixes
    @Published var useSingleTerm: Bool = false
    @Published var singleTerm: String = ""
    @Published var termCount: String = ""
}
