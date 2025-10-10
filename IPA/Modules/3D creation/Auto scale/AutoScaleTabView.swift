//  AutoScaleTabView.swift
//  UI for semi-automatic scaling of OBJ models using Micro QR detection on textures.

import SwiftUI
import AppKit
import Foundation
import UniformTypeIdentifiers

struct AutoScaleTabView: View {
    @EnvironmentObject var viewModel: AutoScaleViewModel
    @State private var zoomTarget: ZoomTarget? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                fileSelectionSection
                textureSelectionSection
                detectionOptionsSection
                markerTypeSection
                texturePreviewSection
                recognizedTextsSection
                regionPreviewSection
                measurementSection
                scalingSection

                if !viewModel.statusMessage.isEmpty {
                    Text(viewModel.statusMessage)
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .frame(minWidth: 720, minHeight: 600)
        .sheet(item: $zoomTarget) { target in
            switch target {
            case .texture:
                if let image = viewModel.textureImage {
                    ImageInspectorView(title: NSLocalizedString("Texture Preview", comment: "Title for enlarged texture preview"), image: image)
                } else {
                    Text(NSLocalizedString("No texture available", comment: "Message when no texture is available for preview"))
                        .frame(minWidth: 300, minHeight: 200)
                }
            case .target:
                if let preview = viewModel.selectedRegionPreview {
                    ImageInspectorView(title: NSLocalizedString("Target Preview", comment: "Title for enlarged target preview"), image: preview)
                } else {
                    Text(NSLocalizedString("No target selected", comment: "Message when no target is selected"))
                        .frame(minWidth: 300, minHeight: 200)
                }
            }
        }
    }

    private var fileSelectionSection: some View {
        GroupBox(label: Text(NSLocalizedString("OBJ File", comment: "Section title for selecting OBJ file"))) {
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.objURL?.path ?? NSLocalizedString("No file selected", comment: "Placeholder when no OBJ file is selected"))
                    .font(.caption)
                    .foregroundColor(.gray)

                Button(NSLocalizedString("Select OBJ File", comment: "Button to pick an OBJ file")) {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [UTType(filenameExtension: "obj")!]
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    if panel.runModal() == .OK, let url = panel.url {
                        viewModel.setOBJ(url: url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isProcessing)
            }
        }
    }

    private var textureSelectionSection: some View {
        GroupBox(label: Text(NSLocalizedString("Texture", comment: "Section title for selecting texture"))) {
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.textureURL?.path ?? NSLocalizedString("No texture selected", comment: "Placeholder when no texture is selected"))
                    .font(.caption)
                    .foregroundColor(.gray)

                Button(NSLocalizedString("Select Texture", comment: "Button to pick a texture file")) {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = textureFileTypes
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    if let objURL = viewModel.objURL {
                        panel.directoryURL = objURL.deletingLastPathComponent()
                    }
                    if panel.runModal() == .OK, let url = panel.url {
                        viewModel.setTexture(url: url)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isProcessing)
            }
        }
    }

    private var detectionOptionsSection: some View {
        GroupBox(label: Text(NSLocalizedString("Micro QR Detection", comment: "Section title for Micro QR detection"))) {
            VStack(alignment: .leading, spacing: 12) {
                Picker(NSLocalizedString("Mode", comment: "Picker label for detection mode"), selection: $viewModel.detectionMode) {
                    ForEach(AutoScaleViewModel.DetectionMode.allCases) { mode in
                        Text(mode.description).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(NSLocalizedString("Standard scans the full texture. Tiling splits the texture into tiles to detect tiny QR codes. Auto chooses for you.", comment: "Description of detection modes"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button {
                    viewModel.analyzeTexture()
                } label: {
                    HStack {
                        if viewModel.isProcessing {
                            ProgressView()
                        }
                        Text(NSLocalizedString("Detect Micro QR Codes", comment: "Button to launch Micro QR detection"))
                    }
                }
                .disabled(viewModel.isProcessing || viewModel.objURL == nil || viewModel.textureURL == nil)

                if !viewModel.detectionSummary.isEmpty {
                    Text(viewModel.detectionSummary)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var markerTypeSection: some View {
        GroupBox(label: Text(NSLocalizedString("Marker Type", comment: "Section title for marker selection"))) {
            VStack(alignment: .leading, spacing: 10) {
                Picker(NSLocalizedString("Marker", comment: "Picker label for marker type"), selection: $viewModel.selectedMarker) {
                    ForEach(viewModel.markerOptions) { option in
                        Text(viewModel.markerDisplayName(for: option)).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                if !viewModel.defaultMarkerLegend.isEmpty {
                    Text(viewModel.defaultMarkerLegend)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        TextField(NSLocalizedString("Side (cm)", comment: "Text field placeholder for marker side length"), text: $viewModel.customSideLength)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(maxWidth: 140)
                            .onSubmit {
                                if viewModel.canAddCustomMarker {
                                    viewModel.addCustomMarker()
                                }
                            }

                        Button(NSLocalizedString("Add this size", comment: "Button to add custom marker size")) {
                            viewModel.addCustomMarker()
                        }
                        .disabled(!viewModel.canAddCustomMarker)
                    }

                    Text(NSLocalizedString("Enter the QR code side length in centimeters. The diagonal is computed automatically.", comment: "Help text for marker size input"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var texturePreviewSection: some View {
        if let image = viewModel.textureImage {
            GroupBox(label: Text(NSLocalizedString("Texture Preview", comment: "Section title for texture preview"))) {
                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        zoomTarget = .texture
                    } label: {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 160)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Text(NSLocalizedString("Click to zoom and inspect the texture.", comment: "Hint for texture zoom"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var recognizedTextsSection: some View {
        if !viewModel.recognizedRegions.isEmpty {
            GroupBox(label: Text(NSLocalizedString("Detected Micro QR Codes", comment: "Section title listing detected codes"))) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.recognizedRegions, id: \.id) { region in
                        Button {
                            viewModel.select(region: region)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(region.text.isEmpty ? NSLocalizedString("Micro QR", comment: "Default label for detected micro QR") : region.text)
                                        .font(.headline)
                                    Text(String(format: NSLocalizedString("Confidence: %.0f%%", comment: "Confidence percentage"), region.confidence * 100))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(String(format: NSLocalizedString("Area: %d px^2", comment: "Area in pixels squared"), Int(region.area)))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isProcessing)
                        .background(viewModel.selectedRegion == region ? Color.accentColor.opacity(0.15) : Color.clear)
                        .cornerRadius(8)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var regionPreviewSection: some View {
        if let preview = viewModel.selectedRegionPreview {
            GroupBox(label: Text(NSLocalizedString("Target Preview", comment: "Section title for target preview"))) {
                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        zoomTarget = .target
                    } label: {
                        Image(nsImage: preview)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(height: 140)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Text(NSLocalizedString("Click to inspect the target in detail.", comment: "Hint for inspecting detected target"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var measurementSection: some View {
        GroupBox(label: Text(NSLocalizedString("Uncalibrated Measurement", comment: "Section title for measurement results"))) {
            VStack(alignment: .leading, spacing: 10) {
                if viewModel.isProcessing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                }

                if let selected = viewModel.selectedRegion {
                    Text(String(format: NSLocalizedString("Selected target: %@", comment: "Label for selected detection"), selected.text.isEmpty ? NSLocalizedString("Micro QR", comment: "Default label for detected micro QR") : selected.text))
                        .font(.subheadline)
                }

                if let distance = viewModel.uncalibratedDistance {
                    Text(String(format: NSLocalizedString("Computed distance: %.3f units", comment: "Computed distance label"), distance))
                        .font(.title3)
                        .fontWeight(.semibold)
                } else {
                    Text(NSLocalizedString("Select a detected target to start the computation.", comment: "Instruction when no target selected"))
                        .foregroundColor(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("Manual measurement (3D units)", comment: "Title for manual measurement override"))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    HStack {
                        TextField(NSLocalizedString("e.g. 12.5", comment: "Placeholder for manual measurement input"), text: $viewModel.manualOverride)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 120)
                        Button(NSLocalizedString("Use this measurement", comment: "Button to apply manual measurement")) {
                            viewModel.applyManualOverride()
                        }
                        .disabled(viewModel.manualOverride.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    private var scalingSection: some View {
        GroupBox(label: Text(NSLocalizedString("Scaling", comment: "Section title for scaling actions"))) {
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.selectedMarkerSummary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    Button(NSLocalizedString("Create new file (_scaled)", comment: "Button to save scaled copy")) {
                        viewModel.scale(overwrite: false)
                    }
                    .disabled(viewModel.uncalibratedDistance == nil || viewModel.isProcessing || !viewModel.isDiagonalInputValid)

                    Button(NSLocalizedString("Overwrite original", comment: "Button to overwrite the original file")) {
                        viewModel.scale(overwrite: true)
                    }
                    .disabled(viewModel.uncalibratedDistance == nil || viewModel.isProcessing || !viewModel.isDiagonalInputValid)
                }
            }
        }
    }
}

private extension AutoScaleTabView {
    var textureFileTypes: [UTType] {
        ["png", "jpg", "jpeg", "tif", "tiff", "bmp", "exr"]
            .compactMap { UTType(filenameExtension: $0) }
    }
}

private enum ZoomTarget: Identifiable {
    case texture
    case target

    var id: Int {
        switch self {
        case .texture: return 0
        case .target: return 1
        }
    }
}

struct ImageInspectorView: View {
    let title: String
    let image: NSImage

    private let minScale: CGFloat = 0.5
    private let maxScale: CGFloat = 8.0

    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var storedScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var storedOffset: CGSize = .zero

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            GeometryReader { _ in
                ZStack {
                    Color(nsColor: .windowBackgroundColor)
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.none)
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(dragGesture)
                        .simultaneousGesture(magnificationGesture)
                        .onTapGesture(count: 2, perform: toggleZoom)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .clipped()
            controlBar
        }
        .frame(minWidth: 720, minHeight: 520)
    }

    private var header: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Button {
                withAnimation(.easeInOut) {
                    resetView()
                }
            } label: {
                Label(NSLocalizedString("Reset", comment: "Button to reset zoom and offset"), systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.borderless)
            .disabled(scale == 1.0 && offset == .zero)

            Button {
                dismiss()
            } label: {
                Label(NSLocalizedString("Close", comment: "Button to close inspector view"), systemImage: "xmark.circle.fill")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var controlBar: some View {
        VStack(spacing: 10) {
            Slider(
                value: Binding(
                    get: { Double(scale) },
                    set: { updateScale(CGFloat($0)) }
                ),
                in: Double(minScale)...Double(maxScale)
            )
            HStack {
                Text(String(format: NSLocalizedString("%.2fx", comment: "Zoom scale indicator"), scale))
                    .font(.caption)
                    .monospacedDigit()
                Spacer()
                Text(NSLocalizedString("Pinch or use the slider to zoom. Drag to pan. Double-click to reset.", comment: "Instructions for zoom controls"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = clampScale(storedScale * value)
                scale = newScale
                if newScale <= 1.0 {
                    offset = .zero
                    storedOffset = .zero
                }
            }
            .onEnded { _ in
                storedScale = scale
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1.0 else {
                    offset = .zero
                    return
                }
                offset = CGSize(
                    width: storedOffset.width + value.translation.width,
                    height: storedOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                guard scale > 1.0 else {
                    storedOffset = .zero
                    offset = .zero
                    return
                }
                storedOffset = offset
            }
    }

    private func toggleZoom() {
        if abs(scale - 1.0) < 0.01 {
            withAnimation(.easeInOut) {
                updateScale(2.0)
            }
        } else {
            withAnimation(.easeInOut) {
                resetView()
            }
        }
    }

    private func resetView() {
        scale = 1.0
        storedScale = 1.0
        offset = .zero
        storedOffset = .zero
    }

    private func updateScale(_ newValue: CGFloat) {
        let clamped = clampScale(newValue)
        scale = clamped
        storedScale = clamped
        if clamped <= 1.0 {
            offset = .zero
            storedOffset = .zero
        }
    }

    private func clampScale(_ value: CGFloat) -> CGFloat {
        min(max(value, minScale), maxScale)
    }
}

#if DEBUG
struct AutoScaleTabView_Previews: PreviewProvider {
    static var previews: some View {
        AutoScaleTabView()
            .environmentObject(AutoScaleViewModel())
            .frame(width: 900, height: 700)
    }
}
#endif
