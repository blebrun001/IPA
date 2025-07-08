//  DataverseViewModel.swift
//  ViewModel storing user input and upload state for interacting with a Dataverse repository.


import Foundation
import SwiftUI

class DataverseViewModel: ObservableObject {
    @AppStorage("dataverseAddress") var dataverseAddress: String = ""        // Default Dataverse base URL
    @AppStorage("dataverseToken") var token: String = ""                     // API token for authentication
    
    @Published var datasetDOI: String = ""                                   // Target dataset DOI
    @Published var selectedFiles: [URL] = []                                 // Files or folders selected by the user
    @Published var compressFiles: Bool = false                               // Whether to zip selected files before upload
    @Published var zipFileName: String = "archive.zip"                       // Name of the generated ZIP file
    @Published var apiResponse: String = ""                                  // Server response after upload
    @Published var isUploading: Bool = false                                 // Upload in progress flag
    @Published var uploadProgress: Double = 0.0                              // Upload progress (0.0 to 1.0)
}
