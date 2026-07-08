//  AutoScaleImageHelpers.swift
//  Image and geometry helpers for Auto Scale.

import AppKit
import CoreGraphics
import ImageIO
import simd

extension CGRect {
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

extension NSImage {
    var cgImageRepresentation: CGImage? {
        var proposedRect = CGRect(origin: .zero, size: size)
        return cgImage(forProposedRect: &proposedRect, context: nil, hints: nil)
    }
}

extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }
}

extension SIMD3 where Scalar == Double {
    var length: Double {
        sqrt(x * x + y * y + z * z)
    }
}

extension Data {
    func makeCGImage() -> CGImage? {
        guard let source = CGImageSourceCreateWithData(self as CFData, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}

extension AutoScaleViewModel {
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
