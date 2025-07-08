//  OBJScalingTabView.swift
//  View for scaling OBJ files using uncalibrated and real-world measurements.

import SwiftUI
import UniformTypeIdentifiers

struct OBJScalingTabView: View {
    @EnvironmentObject var viewModel: OBJScalerViewModel
    private let objScaler = OBJScaler()
    
    var body: some View {
        VStack(spacing: 15) {
            // OBJ file selection
            HStack {
                Button("Select OBJ file") {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [UTType(filenameExtension: "obj")!]
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    if panel.runModal() == .OK {
                        viewModel.objFile = panel.url
                    }
                }
                if let url = viewModel.objFile {
                    Text(url.lastPathComponent)
                        .foregroundColor(.secondary)
                } else {
                    Text("No file selected")
                        .foregroundColor(.gray)
                }
            }
            
            // Uncalibrated measurement input
            HStack {
                Text("Uncalibrated measure:")
                TextField("Value", text: $viewModel.uncalibrated)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 100)
            }
            
            // Real-world measurement input
            HStack {
                Text("Calibrated measure (cm):")
                TextField("Value", text: $viewModel.real)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 100)
            }
            
            // Overwrite toggle option
            Toggle("Overwrite original file", isOn: $viewModel.overwrite)
                .padding(.top, 8)
            
            // Scaling action button
            Button("Start scaling") {
                guard let file = viewModel.objFile,
                      let realValue = Double(viewModel.real),
                      let uncalibratedValue = Double(viewModel.uncalibrated) else {
                    viewModel.resultMessage = "Please select a file and numerical value."
                    return
                }
                do {
                    let resultURL = try objScaler.scaleOBJ(
                        file: file,
                        uncalibrated: uncalibratedValue,
                        real: realValue,
                        overwrite: viewModel.overwrite
                    )
                    viewModel.resultMessage = "Scaled file: \(resultURL.lastPathComponent)"
                } catch {
                    viewModel.resultMessage = "Error: \(error.localizedDescription)"
                }
            }
            .padding(.top, 8)
            
            // Result or error message
            if !viewModel.resultMessage.isEmpty {
                Text(viewModel.resultMessage)
                    .foregroundColor(.blue)
                    .padding(.top, 10)
            }
            
            Spacer()
        }
        .padding()
    }
}
