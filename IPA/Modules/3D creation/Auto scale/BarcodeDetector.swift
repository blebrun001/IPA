//  BarcodeDetector.swift
//  Vision-backed Micro QR detection for Auto Scale.

import Foundation
import CoreGraphics
import Vision

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
