//  AutoScaleViewModel.swift
//  ViewModel powering the Auto Scale module.

import SwiftUI
import AppKit
import Combine

@MainActor
final class AutoScaleViewModel: ObservableObject {
    struct MarkerOption: Identifiable, Hashable {
        let id: UUID
        let name: String
        let sideLengthCentimeters: Double
        let isCustom: Bool

        init(id: UUID = UUID(), name: String, sideLengthCentimeters: Double, isCustom: Bool) {
            self.id = id
            self.name = name
            self.sideLengthCentimeters = sideLengthCentimeters
            self.isCustom = isCustom
        }

        var diagonalLengthCentimeters: Double {
            sideLengthCentimeters * sqrt(2.0)
        }

        static var defaults: [MarkerOption] {
            [
                MarkerOption(name: "Type 0.5", sideLengthCentimeters: 0.5, isCustom: false),
                MarkerOption(name: "Type 1", sideLengthCentimeters: 1.0, isCustom: false),
                MarkerOption(name: "Type 2", sideLengthCentimeters: 2.0, isCustom: false),
                MarkerOption(name: "Type 3", sideLengthCentimeters: 3.0, isCustom: false)
            ]
        }
    }

    enum DetectionMode: String, CaseIterable, Identifiable {
        case automatic = "Automatic"
        case singlePass = "Single Pass"
        case tiled = "Tiled"

        var id: String { rawValue }

        var description: String {
            switch self {
            case .automatic:
                return NSLocalizedString("Auto", comment: "Detection mode automatic label")
            case .singlePass:
                return NSLocalizedString("Standard", comment: "Detection mode standard label")
            case .tiled:
                return NSLocalizedString("Tiling", comment: "Detection mode tiling label")
            }
        }
    }

    @Published var markerOptions: [MarkerOption]
    @Published var selectedMarker: MarkerOption {
        didSet { updateRealWorldValueFromSelection() }
    }
    @Published var customSideLength: String = ""
    @Published var objURL: URL?
    @Published var textureURL: URL?
    @Published var textureImage: NSImage?
    @Published var recognizedRegions: [OCRTextRegion] = []
    @Published var selectedRegion: OCRTextRegion?
    @Published var uncalibratedDistance: Double?
    @Published var realWorldValue: String = ""
    @Published var statusMessage: String = ""
    @Published var isProcessing: Bool = false
    @Published var manualOverride: String = ""
    @Published var selectedRegionPreview: NSImage?
    @Published var detectionMode: DetectionMode = .automatic
    @Published var detectionSummary: String = ""

    private let analyzer = OBJMeshAnalyzer()
    private let barcodeDetector = BarcodeDetector()
    private var cancellables = Set<AnyCancellable>()

    init() {
        let defaults = MarkerOption.defaults
        markerOptions = defaults
        selectedMarker = defaults[0]
        realWorldValue = AutoScaleViewModel.formatLength(defaults[0].diagonalLengthCentimeters)

        PhotogrammetryManager.shared.$lastGeneratedOBJ
            .sink { [weak self] newOBJ in
                if let url = newOBJ {
                    self?.setOBJ(url: url)
                }
            }
            .store(in: &cancellables)
    }

    private static let lengthFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 3
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    private static func formatLength(_ value: Double) -> String {
        lengthFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private static func parseLength(from string: String) -> Double? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let number = lengthFormatter.number(from: trimmed) {
            return number.doubleValue
        }
        return Double(trimmed)
    }

    private static func makeDetectionSummary(outcome: BarcodeDetector.DetectionOutcome) -> String {
        guard !outcome.regions.isEmpty else {
            return NSLocalizedString("No codes detected.", comment: "Detection summary when nothing found")
        }
        if outcome.options.useTiling {
            return String(format: NSLocalizedString("Tiled detection – %d code(s) • %d tile(s).", comment: "Detection summary for tiled mode"), outcome.regions.count, outcome.tilesScanned)
        } else {
            return String(format: NSLocalizedString("Standard detection – %d code(s).", comment: "Detection summary for single pass"), outcome.regions.count)
        }
    }

    private func updateRealWorldValueFromSelection() {
        realWorldValue = AutoScaleViewModel.formatLength(selectedMarker.diagonalLengthCentimeters)
    }

    var currentDiagonalValue: Double? {
        AutoScaleViewModel.parseLength(from: realWorldValue)
    }

    var selectedMarkerSummary: String {
        let name = markerDisplayName(for: selectedMarker)
        let side = AutoScaleViewModel.formatLength(selectedMarker.sideLengthCentimeters)
        let diagonal = AutoScaleViewModel.formatLength(selectedMarker.diagonalLengthCentimeters)
        return String(format: NSLocalizedString("%@ – side %@ cm • diagonal %@ cm", comment: "Summary of current marker selection"), name, side, diagonal)
    }

    var defaultMarkerLegend: String {
        markerOptions
            .filter { !$0.isCustom }
            .map { option in
                let name = markerDisplayName(for: option)
                let side = AutoScaleViewModel.formatLength(option.sideLengthCentimeters)
                let diagonal = AutoScaleViewModel.formatLength(option.diagonalLengthCentimeters)
                return String(format: NSLocalizedString("%@ = %@ cm (diag. %@ cm)", comment: "Legend entry describing marker type"), name, side, diagonal)
            }
            .joined(separator: " • ")
    }

    var isDiagonalInputValid: Bool {
        guard let value = currentDiagonalValue else { return false }
        return value > 0
    }

    var canAddCustomMarker: Bool {
        guard let value = AutoScaleViewModel.parseLength(from: customSideLength) else { return false }
        return value > 0
    }

    func markerDisplayName(for option: MarkerOption) -> String {
        if option.isCustom {
            return markerDisplayName(forCustomSide: option.sideLengthCentimeters)
        }
        return String(format: NSLocalizedString("Type %@ cm", comment: "Preset marker name"), AutoScaleViewModel.formatLength(option.sideLengthCentimeters))
    }

    func addCustomMarker() {
        guard let side = AutoScaleViewModel.parseLength(from: customSideLength), side > 0 else {
            statusMessage = AutoScaleError.invalidRealWorldValue.localizedDescription
            return
        }

        if let index = markerOptions.firstIndex(where: { abs($0.sideLengthCentimeters - side) < 0.0001 }) {
            selectedMarker = markerOptions[index]
            statusMessage = String(format: NSLocalizedString("Existing marker selected: side %@ cm.", comment: "Status when selecting an existing marker"), AutoScaleViewModel.formatLength(side))
        } else {
            let label = markerDisplayName(forCustomSide: side)
            let newOption = MarkerOption(name: label, sideLengthCentimeters: side, isCustom: true)
            markerOptions.append(newOption)
            markerOptions.sort { $0.sideLengthCentimeters < $1.sideLengthCentimeters }
            selectedMarker = newOption
            statusMessage = String(format: NSLocalizedString("Custom marker added: side %@ cm (diag. %@ cm).", comment: "Status when a custom marker is added"), AutoScaleViewModel.formatLength(side), AutoScaleViewModel.formatLength(newOption.diagonalLengthCentimeters))
        }

        customSideLength = ""
    }

    func setOBJ(url: URL) {
        objURL = url
        textureURL = nil
        textureImage = nil
        recognizedRegions = []
        selectedRegion = nil
        uncalibratedDistance = nil
        manualOverride = ""
        selectedRegionPreview = nil
        statusMessage = String(format: NSLocalizedString("OBJ selected: %@. Select a texture to continue.", comment: "Status after selecting OBJ"), url.lastPathComponent)
    }

    func setTexture(url: URL) {
        do {
            let data = try Data(contentsOf: url)
            guard let image = NSImage(data: data) else {
                statusMessage = AutoScaleError.textureLoadingFailed.localizedDescription
                return
            }
            textureURL = url
            textureImage = image
            recognizedRegions = []
            selectedRegion = nil
            uncalibratedDistance = nil
            manualOverride = ""
            selectedRegionPreview = nil
            updateRealWorldValueFromSelection()
            statusMessage = String(format: NSLocalizedString("Texture selected: %@. Run Micro QR detection to proceed.", comment: "Status after selecting texture"), url.lastPathComponent)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func analyzeTexture() {
        guard let textureURL else {
            statusMessage = AutoScaleError.missingTexture.localizedDescription
            return
        }

        isProcessing = true
        detectionSummary = ""
        statusMessage = NSLocalizedString("Analyzing texture...", comment: "Status while analyzing texture")

        Task(priority: .userInitiated) {
            do {
                let textureData = try Data(contentsOf: textureURL)
                guard let cgImage = textureData.makeCGImage() else {
                    throw AutoScaleError.textureLoadingFailed
                }

                let detectionOptions = BarcodeDetector.DetectionOptions.recommended(
                    for: cgImage,
                    mode: self.detectionMode
                )
                let detectionOutcome = try barcodeDetector.detectBarcodes(
                    in: cgImage,
                    symbologies: [.microQR],
                    options: detectionOptions
                )

                try Task.checkCancellation()

                await MainActor.run {
                    applyDetectionOutcome(detectionOutcome, textureData: textureData, textureName: textureURL.lastPathComponent)
                }
            } catch {
                let errorMessage = error.localizedDescription
                await MainActor.run {
                    self.isProcessing = false
                    self.uncalibratedDistance = nil
                    self.statusMessage = errorMessage
                    self.detectionSummary = String(format: NSLocalizedString("Detection error: %@", comment: "Detection summary error"), errorMessage)
                }
            }
        }
    }

    func select(region: OCRTextRegion) {
        guard let objURL, let textureSize = textureImage?.size else {
            statusMessage = AutoScaleError.missingOBJ.localizedDescription
            return
        }

        isProcessing = true
        selectedRegion = region
        selectedRegionPreview = makePreview(for: region)
        statusMessage = NSLocalizedString("Computing 3D distance...", comment: "Status while computing distance")

        Task(priority: .userInitiated) {
            do {
                let measurement = try analyzer.measureDistance(
                    objURL: objURL,
                    boundingBox: region.boundingBox,
                    textureSize: textureSize
                )
                await MainActor.run {
                    self.uncalibratedDistance = measurement.distance
                    if let distance = self.uncalibratedDistance {
                        self.statusMessage = String(format: NSLocalizedString("Uncalibrated measurement: %.3f units", comment: "Status showing uncalibrated distance"), distance)
                        self.manualOverride = String(format: "%.3f", distance)
                    }
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.statusMessage = error.localizedDescription
                }
            }
        }
    }

    func scale(overwrite: Bool) {
        guard let objURL, let uncalibrated = uncalibratedDistance else {
            statusMessage = AutoScaleError.missingOBJ.localizedDescription
            return
        }
        guard uncalibrated > 0 else {
            statusMessage = AutoScaleError.invalidUncalibratedDistance.localizedDescription
            return
        }
        guard let real = currentDiagonalValue, real > 0 else {
            statusMessage = AutoScaleError.invalidRealWorldValue.localizedDescription
            return
        }

        isProcessing = true
        statusMessage = NSLocalizedString("Scaling model...", comment: "Status while scaling")

        Task(priority: .userInitiated) {
            do {
                let scaler = OBJScaler()
                let resultURL = try scaler.scaleOBJ(
                    file: objURL,
                    uncalibrated: uncalibrated,
                    real: real,
                    overwrite: overwrite
                )
                await MainActor.run {
                    self.isProcessing = false
                    self.statusMessage = String(format: NSLocalizedString("Scaled model saved: %@", comment: "Status after scaling"), resultURL.lastPathComponent)
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.statusMessage = error.localizedDescription
                }
            }
        }
    }

    func applyManualOverride() {
        guard let value = AutoScaleViewModel.parseLength(from: manualOverride), value > 0 else {
            statusMessage = AutoScaleError.invalidUncalibratedDistance.localizedDescription
            return
        }
        uncalibratedDistance = value
        manualOverride = AutoScaleViewModel.formatLength(value)
        statusMessage = String(format: NSLocalizedString("Uncalibrated measurement set manually: %@ units", comment: "Status after manual override"), AutoScaleViewModel.formatLength(value))
    }

    private func markerDisplayName(forCustomSide side: Double) -> String {
        return String(format: NSLocalizedString("Custom %@ cm", comment: "Label for custom marker"), AutoScaleViewModel.formatLength(side))
    }

    private func applyDetectionOutcome(_ outcome: BarcodeDetector.DetectionOutcome, textureData: Data, textureName: String) {
        if let image = NSImage(data: textureData) {
            textureImage = image
        }
        recognizedRegions = outcome.regions.sorted {
            if $0.confidence == $1.confidence {
                return $0.area > $1.area
            }
            return $0.confidence > $1.confidence
        }
        selectedRegion = nil
        uncalibratedDistance = nil
        manualOverride = ""
        selectedRegionPreview = nil
        detectionSummary = Self.makeDetectionSummary(outcome: outcome)

        if outcome.regions.isEmpty {
            statusMessage = AutoScaleError.noRegionMatches.localizedDescription
        } else {
            let modeSuffix: String
            if outcome.options.useTiling {
                modeSuffix = String(format: NSLocalizedString(" (tiled scan, %d tile(s))", comment: "Suffix for tiled detection status"), outcome.tilesScanned)
            } else {
                modeSuffix = ""
            }
            statusMessage = String(format: NSLocalizedString("Texture: %@ – %d Micro QR code(s) detected%@.", comment: "Status after detection"), textureName, outcome.regions.count, modeSuffix)
        }
        isProcessing = false
    }
}
