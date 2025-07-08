//  OBJScalerViewModel.swift
//  ViewModel for managing the state and logic related to scaling OBJ files.


import SwiftUI
import Combine

class OBJScalerViewModel: ObservableObject {
    @Published var objFile: URL? = nil         // Selected OBJ file
    @Published var uncalibrated: String = ""   // Uncalibrated measurement input as string (for text field binding)
    @Published var real: String = ""          // Real-world measurement input as string (for text field binding)
    @Published var overwrite: Bool = true      // Whether to overwrite the original file or not
    @Published var resultMessage: String = ""  // Message to display result or error
    
    // Stores Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Observe `lastGeneratedOBJ` from the shared PhotogrammetryManager
        // Automatically updates the selected OBJ file when a new one is generated
        PhotogrammetryManager.shared.$lastGeneratedOBJ
            .sink { [weak self] newOBJ in
                self?.objFile = newOBJ
            }
            .store(in: &cancellables)
    }
}
