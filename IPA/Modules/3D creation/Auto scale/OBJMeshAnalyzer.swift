//  OBJMeshAnalyzer.swift
//  OBJ parsing and UV-region distance measurement for Auto Scale.

import Foundation
import CoreGraphics
import simd

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

    func parseMesh(at url: URL) throws -> OBJMesh {
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
