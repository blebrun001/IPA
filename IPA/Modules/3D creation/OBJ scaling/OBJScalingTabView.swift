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
                Button(NSLocalizedString("Select OBJ file", comment: "Button to pick OBJ file for scaling")) {
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
                    Text(NSLocalizedString("No file selected", comment: "Placeholder when no OBJ file is selected"))
                        .foregroundColor(.gray)
                }
            }
            
            // Uncalibrated measurement input
            HStack {
                Text(NSLocalizedString("Uncalibrated measure:", comment: "Label for uncalibrated measurement input"))
                TextField(NSLocalizedString("Value", comment: "Placeholder for measurement input"), text: $viewModel.uncalibrated)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 100)
            }
            
            // Real-world measurement input
            HStack {
                Text(NSLocalizedString("Calibrated measure (cm):", comment: "Label for real-world measurement input"))
                TextField(NSLocalizedString("Value", comment: "Placeholder for measurement input"), text: $viewModel.real)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 100)
            }
            
            // Overwrite toggle option
            Toggle(NSLocalizedString("Overwrite original file", comment: "Toggle to overwrite original OBJ"), isOn: $viewModel.overwrite)
                .padding(.top, 8)

            // Scaling action button
            Button(NSLocalizedString("Start scaling", comment: "Button to start scaling process")) {
                guard let file = viewModel.objFile,
                      let realValue = Double(viewModel.real),
                      let uncalibratedValue = Double(viewModel.uncalibrated) else {
                    viewModel.resultMessage = NSLocalizedString("Please select a file and numerical value.", comment: "Error when input values are invalid")
                    return
                }
                do {
                    let resultURL = try objScaler.scaleOBJ(
                        file: file,
                        uncalibrated: uncalibratedValue,
                        real: realValue,
                        overwrite: viewModel.overwrite
                    )
                    let template = NSLocalizedString("Scaled file: %@", comment: "Message after successful scaling")
                    viewModel.resultMessage = String(format: template, resultURL.lastPathComponent)
                } catch {
                    let template = NSLocalizedString("Error: %@", comment: "Template for displaying scaling errors")
                    viewModel.resultMessage = String(format: template, error.localizedDescription)
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
