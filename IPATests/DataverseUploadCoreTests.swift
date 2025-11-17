import XCTest
@testable import IPA

final class DataverseUploadCoreTests: XCTestCase {

    func testMimeTypeInferenceReturnsSpecificTypeWhenAvailable() {
        let url = URL(fileURLWithPath: "/tmp/example.zip")
        let mime = MimeType.infer(url: url)
        XCTAssertEqual(mime, "application/zip")
    }

    func testMimeTypeInferenceFallsBackToOctetStream() {
        let url = URL(fileURLWithPath: "/tmp/file.unknownextension")
        let mime = MimeType.infer(url: url)
        XCTAssertEqual(mime, "application/octet-stream")
    }

    func testFileSystemFlattenFilesRecursesDirectories() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let fileA = tempDir.appendingPathComponent("a.txt")
        let nestedDir = tempDir.appendingPathComponent("nested")
        try "A".write(to: fileA, atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: nestedDir, withIntermediateDirectories: true)
        let fileB = nestedDir.appendingPathComponent("b.txt")
        try "B".write(to: fileB, atomically: true, encoding: .utf8)

        defer { try? FileManager.default.removeItem(at: tempDir) }

        let files = FileSystem.flattenFiles(from: [tempDir])
        XCTAssertTrue(files.contains(fileA))
        XCTAssertTrue(files.contains(fileB))
        XCTAssertEqual(files.count, 2)
    }

    func testDataverseDirectUploadURLConstruction() throws {
        let server = URL(string: "https://demo.dataverse.org")!
        let url = try DataverseAPI.directUploadURL(server: server,
                                                   persistentId: "doi:10.123/ABC",
                                                   fileSize: 42,
                                                   fileName: "file.txt",
                                                   mime: "text/plain")
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        XCTAssertEqual(comps?.path, "/api/datasets/:persistentId/uploadurls")
        let queryItems = comps?.queryItems ?? []
        XCTAssertTrue(queryItems.contains(.init(name: "persistentId", value: "doi:10.123/ABC")))
        XCTAssertTrue(queryItems.contains(.init(name: "size", value: "42")))
        XCTAssertTrue(queryItems.contains(.init(name: "filename", value: "file.txt")))
        XCTAssertTrue(queryItems.contains(.init(name: "mimeType", value: "text/plain")))
    }

    func testDraftFilesResponseParsing() throws {
        let json = """
        {
          "status": "OK",
          "data": [
            {
              "dataFile": {
                "filename": "file1.txt",
                "directoryLabel": "folder",
                "filesize": 10,
                "checksum": {
                  "type": "MD5",
                  "value": "abc123"
                }
              }
            }
          ]
        }
        """
        let data = Data(json.utf8)
        let files = try DataverseAPI.parseDraftFilesResponse(data)
        XCTAssertEqual(files.count, 1)
        let first = files[0]
        XCTAssertEqual(first.filename, "file1.txt")
        XCTAssertEqual(first.directoryLabel, "folder")
        XCTAssertEqual(first.filesize, 10)
        XCTAssertEqual(first.checksum, "abc123")
        XCTAssertEqual(first.checksumType?.uppercased(), "MD5")
    }
}
