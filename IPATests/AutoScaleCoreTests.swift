import XCTest
@testable import IPA

final class AutoScaleCoreTests: XCTestCase {

    func testOBJMeshAnalyzerMeasuresDistanceInsideTextureRegion() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let objURL = tempDir.appendingPathComponent("mesh.obj")
        let obj = """
        v 0 0 0
        v 3 4 0
        vt 0.2 0.8
        vt 0.8 0.2
        f 1/1 2/2
        """
        try obj.write(to: objURL, atomically: true, encoding: .utf8)

        let analyzer = OBJMeshAnalyzer()
        let measurement = try analyzer.measureDistance(
            objURL: objURL,
            boundingBox: CGRect(x: 0, y: 0, width: 100, height: 100),
            textureSize: CGSize(width: 100, height: 100)
        )

        XCTAssertEqual(measurement.distance, 5.0, accuracy: 0.0001)
        let uv1 = try XCTUnwrap(measurement.uv1)
        let uv2 = try XCTUnwrap(measurement.uv2)
        XCTAssertEqual(uv1.x, 0.2, accuracy: 0.0001)
        XCTAssertEqual(uv2.y, 0.2, accuracy: 0.0001)
    }

    func testOBJMeshAnalyzerThrowsWhenRegionHasFewerThanTwoVertices() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let objURL = tempDir.appendingPathComponent("mesh.obj")
        let obj = """
        v 0 0 0
        v 1 0 0
        vt 0.2 0.8
        vt 0.8 0.2
        f 1/1 2/2
        """
        try obj.write(to: objURL, atomically: true, encoding: .utf8)

        let analyzer = OBJMeshAnalyzer()
        XCTAssertThrowsError(
            try analyzer.measureDistance(
                objURL: objURL,
                boundingBox: CGRect(x: 0, y: 0, width: 10, height: 10),
                textureSize: CGSize(width: 100, height: 100)
            )
        ) { error in
            XCTAssertEqual(error as? AutoScaleError, .noVerticesInRegion)
        }
    }
}
