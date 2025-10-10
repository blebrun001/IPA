//  AutoScaleViewModel.swift
//  ViewModel powering the Auto Scale module: Micro QR detection and scaling pipeline.

import SwiftUI
import Vision
import AppKit
import ImageIO
import simd
import Combine

struct OCRTextRegion: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let confidence: Float
    let boundingBox: CGRect  // Pixel coordinates with origin at top-left
    let area: Double
}

struct AutoScaleMeasurement {
    let distance: Double
    let uv1: SIMD2<Double>?
    let uv2: SIMD2<Double>?
}

enum AutoScaleError: LocalizedError {
    case missingOBJ
    case missingTexture
    case textureLoadingFailed
    case ocrFailed
    case noRegionMatches
    case noVerticesInRegion
    case invalidUncalibratedDistance
    case invalidRealWorldValue

    var errorDescription: String? {
        switch self {
        case .missingOBJ:
            return NSLocalizedString("Please select an OBJ file.", comment: "Auto Scale error for missing OBJ")
        case .missingTexture:
            return NSLocalizedString("Please select a texture file.", comment: "Auto Scale error for missing texture")
        case .textureLoadingFailed:
            return NSLocalizedString("Unable to load the selected texture.", comment: "Auto Scale error when texture fails to load")
        case .ocrFailed:
            return NSLocalizedString("Micro QR detection failed on the texture.", comment: "Auto Scale error when barcode detection fails")
        case .noRegionMatches:
            return NSLocalizedString("No Micro QR markers detected with the current settings.", comment: "Auto Scale error when nothing detected")
        case .noVerticesInRegion:
            return NSLocalizedString("No mesh vertices overlap with the detected region.", comment: "Auto Scale error when mesh has no vertices in region")
        case .invalidRealWorldValue:
            return NSLocalizedString("The real-world measurement must be a valid number.", comment: "Auto Scale error for invalid manual real-world value")
        case .invalidUncalibratedDistance:
            return NSLocalizedString("The detected distance is invalid.", comment: "Auto Scale error for invalid uncalibrated distance")
        }
    }
}

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

    private var cancellables = Set<AnyCancellable>()
    init() {
        let defaults = MarkerOption.defaults
        markerOptions = defaults
        selectedMarker = defaults[0]
        realWorldValue = AutoScaleViewModel.formatLength(defaults[0].diagonalLengthCentimeters)

        // Subscribe Auto Scale to the last OBJ generated by Photogrammetry
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
        guard !outcome.regions.isEmpty else { return NSLocalizedString("No codes detected.", comment: "Detection summary when nothing found") }
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

    private func markerDisplayName(forCustomSide side: Double) -> String {
        return String(format: NSLocalizedString("Custom %@ cm", comment: "Label for custom marker"), AutoScaleViewModel.formatLength(side))
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
    
    
    private let analyzer = OBJMeshAnalyzer()
    private let barcodeDetector = BarcodeDetector()

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

                let summary = Self.makeDetectionSummary(outcome: detectionOutcome)

                await MainActor.run {
                    if let image = NSImage(data: textureData) {
                        self.textureImage = image
                    }
                    self.recognizedRegions = detectionOutcome.regions.sorted {
                        if $0.confidence == $1.confidence {
                            return $0.area > $1.area
                        }
                        return $0.confidence > $1.confidence
                    }
                    self.selectedRegion = nil
                    self.uncalibratedDistance = nil
                    self.manualOverride = ""
                    self.selectedRegionPreview = nil
                    if detectionOutcome.regions.isEmpty {
                        self.statusMessage = AutoScaleError.noRegionMatches.localizedDescription
                    } else {
                        let modeSuffix: String
                        if detectionOutcome.options.useTiling {
                            modeSuffix = String(format: NSLocalizedString(" (tiled scan, %d tile(s))", comment: "Suffix for tiled detection status"), detectionOutcome.tilesScanned)
                        } else {
                            modeSuffix = ""
                        }
                        self.statusMessage = String(format: NSLocalizedString("Texture: %@ – %d Micro QR code(s) detected%@.", comment: "Status after detection"), textureURL.lastPathComponent, detectionOutcome.regions.count, modeSuffix)
                    }
                    self.isProcessing = false
                }

                await MainActor.run {
                    self.detectionSummary = summary
                }
            } catch {
                let errorMessage = error.localizedDescription
                await MainActor.run {
                    self.isProcessing = false
                    self.uncalibratedDistance = nil
                    self.statusMessage = errorMessage
                }
                await MainActor.run {
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

}

final class BarcodeDetector {

    struct DetectionOptions {
        let useTiling: Bool
        let tileDimension: Int
        let overlap: Int
        let deduplicationTolerance: CGFloat

        static func recommended(for image: CGImage, mode: AutoScaleViewModel.DetectionMode) -> DetectionOptions {
            let longestSide = max(image.width, image.height)

            switch mode {
            case .singlePass:
                return DetectionOptions(useTiling: false,
                                        tileDimension: longestSide,
                                        overlap: 0,
                                        deduplicationTolerance: 24)
            case .tiled:
                let tileDimension = suggestedTileSize(for: longestSide)
                let overlap = max(64, tileDimension / 5)
                return DetectionOptions(useTiling: true,
                                        tileDimension: tileDimension,
                                        overlap: overlap,
                                        deduplicationTolerance: 32)
            case .automatic:
                let enableTiling = longestSide > 2048
                if enableTiling {
                    let tileDimension = suggestedTileSize(for: longestSide)
                    let overlap = max(64, tileDimension / 5)
                    return DetectionOptions(useTiling: true,
                                            tileDimension: tileDimension,
                                            overlap: overlap,
                                            deduplicationTolerance: 32)
                } else {
                    return DetectionOptions(useTiling: false,
                                            tileDimension: longestSide,
                                            overlap: 0,
                                            deduplicationTolerance: 24)
                }
            }
        }

        private static func suggestedTileSize(for longestSide: Int) -> Int {
            if longestSide >= 8192 {
                return 1536
            } else if longestSide >= 4096 {
                return 1024
            } else {
                return 768
            }
        }
    }

    struct DetectionOutcome {
        let regions: [OCRTextRegion]
        let tilesScanned: Int
        let options: DetectionOptions
    }

    func detectBarcodes(
        in cgImage: CGImage,
        symbologies: [VNBarcodeSymbology],
        options: DetectionOptions
    ) throws -> DetectionOutcome {
        guard !symbologies.isEmpty else {
            return DetectionOutcome(regions: [], tilesScanned: 0, options: options)
        }

        if !options.useTiling {
            let regions = try detect(on: cgImage, symbologies: symbologies, offset: .zero)
            return DetectionOutcome(regions: regions, tilesScanned: 1, options: options)
        }

        let tileSize = max(1, options.tileDimension)
        let overlap = max(0, min(options.overlap, tileSize - 1))
        let stride = max(1, tileSize - overlap)
        let width = cgImage.width
        let height = cgImage.height

        var aggregated: [OCRTextRegion] = []
        var tileCount = 0

        var y = 0
        while y < height {
            let tileHeight = min(tileSize, height - y)
            var x = 0
            while x < width {
                let tileWidth = min(tileSize, width - x)
                let tileRect = CGRect(x: x, y: y, width: tileWidth, height: tileHeight)
                if let tileImage = makeTileImage(from: cgImage, rect: tileRect) {
                    let offset = CGPoint(x: CGFloat(x), y: CGFloat(y))
                    let regions = try detect(on: tileImage, symbologies: symbologies, offset: offset)
                    aggregated.append(contentsOf: regions)
                    tileCount += 1
                }
                x += stride
            }
            y += stride
        }

        let deduplicated = deduplicate(aggregated, tolerance: options.deduplicationTolerance)
        return DetectionOutcome(regions: deduplicated,
                                tilesScanned: max(tileCount, 1),
                                options: options)
    }

    private func detect(on cgImage: CGImage, symbologies: [VNBarcodeSymbology], offset: CGPoint) throws -> [OCRTextRegion] {
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        var regions: [OCRTextRegion] = []

        let request = VNDetectBarcodesRequest { request, error in
            guard error == nil,
                  let observations = request.results as? [VNBarcodeObservation] else { return }

            for observation in observations where observation.confidence > 0 {
                guard symbologies.contains(observation.symbology) else { continue }
                let localRect = VNImageRectForNormalizedRect(observation.boundingBox,
                                                             Int(imageSize.width),
                                                             Int(imageSize.height)).integral
                    .clamped(to: CGRect(origin: .zero, size: imageSize))
                guard localRect.width > 0, localRect.height > 0 else { continue }

                let payload = observation.payloadStringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Micro QR"
                let globalRect = localRect.offsetBy(dx: offset.x, dy: offset.y)

                regions.append(
                    OCRTextRegion(
                        text: payload.isEmpty ? "Micro QR" : payload,
                        confidence: observation.confidence,
                        boundingBox: globalRect,
                        area: Double(globalRect.width * globalRect.height)
                    )
                )
            }
        }

        request.symbologies = symbologies
        request.revision = VNDetectBarcodesRequest.currentRevision

        do {
            try autoreleasepool {
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
                try handler.perform([request])
            }
        } catch {
            throw AutoScaleError.ocrFailed
        }

        return regions
    }

    private func deduplicate(_ regions: [OCRTextRegion], tolerance: CGFloat) -> [OCRTextRegion] {
        guard regions.count > 1, tolerance > 0 else { return regions }

        var filtered: [OCRTextRegion] = []

        for region in regions {
            let center = CGPoint(x: region.boundingBox.midX, y: region.boundingBox.midY)
            if let existingIndex = filtered.firstIndex(where: { center.distance(to: CGPoint(x: $0.boundingBox.midX, y: $0.boundingBox.midY)) <= tolerance }) {
                let existing = filtered[existingIndex]
                let shouldReplace = region.confidence > existing.confidence ||
                    (abs(region.confidence - existing.confidence) < 0.01 && region.area > existing.area)
                if shouldReplace {
                    filtered[existingIndex] = region
                }
            } else {
                filtered.append(region)
            }
        }

        return filtered
    }

    private func makeTileImage(from baseImage: CGImage, rect: CGRect) -> CGImage? {
        guard rect.width > 0, rect.height > 0 else { return nil }

        guard let colorSpace = baseImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let width = Int(rect.width)
        let height = Int(rect.height)
        guard width > 0, height > 0 else { return nil }

        let bytesPerPixel = 4
        let bitsPerComponent = 8
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.union(.init(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue))

        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: bitsPerComponent,
                                      bytesPerRow: bytesPerPixel * width,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfo.rawValue) else {
            return nil
        }

        context.interpolationQuality = .high
        let drawRect = CGRect(x: -rect.origin.x,
                              y: -rect.origin.y,
                              width: CGFloat(baseImage.width),
                              height: CGFloat(baseImage.height))
        context.draw(baseImage, in: drawRect)
        return context.makeImage()
    }
}

final class OBJMeshAnalyzer {

    struct Candidate {
        let vertex: SIMD3<Double>
        let uv: SIMD2<Double>
    }

    func measureDistance(objURL: URL, boundingBox: CGRect, textureSize: CGSize) throws -> AutoScaleMeasurement {
        let mesh = try parseMesh(at: objURL)

        let width = Double(textureSize.width)
        let height = Double(textureSize.height)

        let uMin = Double(boundingBox.minX) / width
        let uMax = Double(boundingBox.maxX) / width
        let vMax = 1.0 - Double(boundingBox.minY) / height
        let vMin = 1.0 - Double(boundingBox.maxY) / height

        let candidates = collectCandidates(mesh: mesh, uMin: uMin, uMax: uMax, vMin: vMin, vMax: vMax)
        guard candidates.count >= 2 else {
            throw AutoScaleError.noVerticesInRegion
        }

        var maxDistance: Double = 0
        var bestPair: (SIMD2<Double>, SIMD2<Double>)?

        for i in 0..<(candidates.count - 1) {
            for j in (i + 1)..<candidates.count {
                let v1 = candidates[i].vertex
                let v2 = candidates[j].vertex
                let distance = (v1 - v2).length
                if distance > maxDistance {
                    maxDistance = distance
                    bestPair = (candidates[i].uv, candidates[j].uv)
                }
            }
        }

        return AutoScaleMeasurement(distance: maxDistance, uv1: bestPair?.0, uv2: bestPair?.1)
    }

    private func collectCandidates(mesh: OBJMesh, uMin: Double, uMax: Double, vMin: Double, vMax: Double) -> [Candidate] {
        var candidates: [Candidate] = []
        for face in mesh.faces {
            for (vertexIndex, texIndex) in zip(face.vertexIndices, face.textureIndices) {
                guard let texIndex else { continue }
                guard texIndex < mesh.texcoords.count else { continue }
                let uv = mesh.texcoords[texIndex]
                if uv.x >= uMin && uv.x <= uMax && uv.y >= vMin && uv.y <= vMax {
                    let vertex = mesh.vertices[vertexIndex]
                    candidates.append(Candidate(vertex: vertex, uv: uv))
                }
            }
        }
        return candidates
    }

    private func parseMesh(at url: URL) throws -> OBJMesh {
        let content = try String(contentsOf: url, encoding: .utf8)
        var vertices: [SIMD3<Double>] = []
        var texcoords: [SIMD2<Double>] = []
        var faces: [OBJFace] = []

        let lines = content.split(whereSeparator: { $0.isNewline })
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            if line.hasPrefix("v ") {
                let components = line.split(separator: " ")
                guard components.count >= 4,
                      let x = Double(components[1]),
                      let y = Double(components[2]),
                      let z = Double(components[3]) else { continue }
                vertices.append(SIMD3<Double>(x, y, z))
            } else if line.hasPrefix("vt ") {
                let components = line.split(separator: " ")
                guard components.count >= 3,
                      let u = Double(components[1]),
                      let v = Double(components[2]) else { continue }
                texcoords.append(SIMD2<Double>(u, v))
            } else if line.hasPrefix("f ") {
                let tokens = line.split(separator: " ").dropFirst()
                var vertexIndices: [Int] = []
                var textureIndices: [Int?] = []
                for token in tokens {
                    let parts = token.split(separator: "/", omittingEmptySubsequences: false)
                    if let vIndex = Int(parts[0]) {
                        vertexIndices.append(vIndex - 1)
                    }
                    if parts.indices.contains(1), let tIndex = Int(parts[1]), tIndex > 0 {
                        textureIndices.append(tIndex - 1)
                    } else {
                        textureIndices.append(nil)
                    }
                }
                faces.append(OBJFace(vertexIndices: vertexIndices, textureIndices: textureIndices))
            }
        }

        return OBJMesh(vertices: vertices, texcoords: texcoords, faces: faces)
    }
}

struct OBJMesh {
    let vertices: [SIMD3<Double>]
    let texcoords: [SIMD2<Double>]
    let faces: [OBJFace]
}

struct OBJFace {
    let vertexIndices: [Int]
    let textureIndices: [Int?]
}

// Texture selection can be auto-detected from OBJ folder (tex0 PNG).

private extension CGRect {
    func toPixelRect(imageSize: CGSize) -> CGRect {
        let width = size.width * imageSize.width
        let height = size.height * imageSize.height
        let x = origin.x * imageSize.width
        let y = (1 - origin.y - size.height) * imageSize.height
        return CGRect(x: x, y: y, width: width, height: height)
    }

    func clamped(to bounds: CGRect) -> CGRect {
        let clampedMinX = max(bounds.minX, min(bounds.maxX, minX))
        let clampedMinY = max(bounds.minY, min(bounds.maxY, minY))
        let clampedMaxX = max(clampedMinX, min(bounds.maxX, maxX))
        let clampedMaxY = max(clampedMinY, min(bounds.maxY, maxY))
        return CGRect(x: clampedMinX,
                      y: clampedMinY,
                      width: clampedMaxX - clampedMinX,
                      height: clampedMaxY - clampedMinY)
    }
}

private extension NSImage {
    var cgImageRepresentation: CGImage? {
        var proposedRect = CGRect(origin: .zero, size: size)
        return cgImage(forProposedRect: &proposedRect, context: nil, hints: nil)
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }
}

private extension SIMD3 where Scalar == Double {
    var length: Double {
        sqrt(x * x + y * y + z * z)
    }
}

private extension Data {
    func makeCGImage() -> CGImage? {
        guard let source = CGImageSourceCreateWithData(self as CFData, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}

private extension AutoScaleViewModel {
    func makePreview(for region: OCRTextRegion) -> NSImage? {
        guard let image = textureImage, let cgImage = image.cgImageRepresentation else {
            return nil
        }

        let height = CGFloat(cgImage.height)
        let cropRect = CGRect(
            x: region.boundingBox.minX,
            y: height - region.boundingBox.maxY,
            width: region.boundingBox.width,
            height: region.boundingBox.height
        )

        guard let cropped = cgImage.cropping(to: cropRect) else {
            return nil
        }

        let size = NSSize(width: cropRect.width, height: cropRect.height)
        return NSImage(cgImage: cropped, size: size)
    }
}
