//  AutoScaleModels.swift
//  Shared data models and errors for the Auto Scale module.

import Foundation
import CoreGraphics
import simd

struct OCRTextRegion: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let confidence: Float
    let boundingBox: CGRect
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
