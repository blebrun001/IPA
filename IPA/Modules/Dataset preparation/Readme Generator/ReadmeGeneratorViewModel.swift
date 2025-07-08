//  ReadmeGeneratorViewModel.swift
//  ViewModel storing form input and output message for the README generation feature.import Foundation

import SwiftUI

class ReadmeGeneratorViewModel: ObservableObject {
    @Published var folder: URL? = nil
    @Published var datasetTitle: String = ""
    @Published var authorship: String = "Brice Lebrun"
    @Published var contact: String = "blebrun@iphes.cat"
    @Published var language: String = "ENG"
    @Published var specimen: String = ""
    @Published var sex: String = "male"
    @Published var lifeStage: String = "adult"
    @Published var scannedItems: String = ""
    @Published var technique: String = "photogrammetry"
    @Published var licence: String = "CC BY-NC 4.0"
    @Published var doi: String = ""
    @Published var fileSize: String = ""
    @Published var numFiles: String = ""
    @Published var structure: String = """
    Item_name
        Item_name.OBJ
        Item_name.MTL
            baked_mesh_fileID_tex0.png
            baked_mesh_fileID_norm0.png
            baked_mesh_fileID_ao0.png
            baked_mesh_fileID_roughness0.png
            baked_mesh_fileID_disp0.exr
    """
    @Published var comments: String = ""
    @Published var resultMessage: String = ""
}
