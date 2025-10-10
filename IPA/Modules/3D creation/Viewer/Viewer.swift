//  Viewer.swift
//  Simple ViewModel that holds the URL of the external 3D viewer.

import SwiftUI

class Viewer: ObservableObject {
    // URL of the online 3D viewer
    @Published var viewerURL: URL = URL(string: "https://3dviewer.net")!
}
