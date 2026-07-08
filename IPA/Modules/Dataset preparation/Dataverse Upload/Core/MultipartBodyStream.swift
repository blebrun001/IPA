//  MultipartBodyStream.swift
//  Streams multipart upload bodies without loading large files into memory.

import Foundation

enum MultipartBodyStream {
    struct Parts {
        let head: Data
        let tail: Data
    }

    static func parts(boundary: String, fileName: String, directoryLabel: String?) -> Parts {
        var head = Data()
        func append(_ s: String) { head.append(Data(s.utf8)) }

        if let dir = directoryLabel, !dir.isEmpty {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"directoryLabel\"\r\n\r\n")
            append("\(dir)\r\n")
        }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n")
        append("Content-Type: application/octet-stream\r\n\r\n")

        let tail = Data("\r\n--\(boundary)--\r\n".utf8)
        return Parts(head: head, tail: tail)
    }

    static func make(head: Data,
                     fileURL: URL,
                     tail: Data,
                     log: @escaping (String) -> Void,
                     progress: @escaping (String) -> Void,
                     shouldCancel: @escaping () -> Bool) throws -> (input: InputStream, output: OutputStream) {
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        CFStreamCreateBoundPair(nil, &readStream, &writeStream, 1 << 20)

        guard let rs = readStream?.takeRetainedValue(),
              let ws = writeStream?.takeRetainedValue() else {
            throw DVError.serverError("CFStreamCreateBoundPair failed")
        }

        let input = rs as InputStream
        let output = ws as OutputStream
        let writer = MultipartOutputWriter(output)

        DispatchQueue.global(qos: .utility).async {
            writer.stream.open()
            defer { writer.stream.close() }

            guard writer.writeAll(head, log: log, progress: progress, shouldCancel: shouldCancel) else {
                logInterrupted(log)
                return
            }

            do {
                let fh = try FileHandle(forReadingFrom: fileURL)
                defer { try? fh.close() }
                var shouldContinue = true
                while shouldContinue && autoreleasepool(invoking: {
                    let chunk = try? fh.read(upToCount: 1 << 20)
                    if let chunk, !chunk.isEmpty {
                        if !writer.writeAll(chunk, log: log, progress: progress, shouldCancel: shouldCancel) {
                            shouldContinue = false
                            logInterrupted(log)
                            return false
                        }
                        return true
                    }
                    return false
                }) {}
                if !shouldContinue {
                    return
                }
            } catch {
                return
            }

            guard writer.writeAll(tail, log: log, progress: progress, shouldCancel: shouldCancel) else {
                logInterrupted(log)
                return
            }
        }

        return (input, output)
    }

    private static func logInterrupted(_ log: @escaping (String) -> Void) {
        DispatchQueue.main.async {
            log("Output stream interrupted, aborting upload")
        }
    }
}

private final class MultipartOutputWriter: @unchecked Sendable {
    let stream: OutputStream
    private var totalBytesUploaded = 0
    private var lastLoggedMB = 0

    init(_ stream: OutputStream) {
        self.stream = stream
    }

    func writeAll(_ data: Data,
                  log: @escaping (String) -> Void,
                  progress: @escaping (String) -> Void,
                  shouldCancel: @escaping () -> Bool) -> Bool {
        var writtenLocal = 0

        return data.withUnsafeBytes { raw -> Bool in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return false }
            while writtenLocal < data.count {
                if shouldCancel() {
                    return false
                }
                if !stream.hasSpaceAvailable {
                    Thread.sleep(forTimeInterval: 0.005)
                    continue
                }
                let n = stream.write(base.advanced(by: writtenLocal), maxLength: data.count - writtenLocal)
                if n <= 0 {
                    DispatchQueue.main.async {
                        log("Network connection interrupted while writing")
                    }
                    return false
                }
                writtenLocal += n
                totalBytesUploaded += n

                let totalMB = totalBytesUploaded / (1024 * 1024)
                if totalMB > lastLoggedMB {
                    lastLoggedMB = totalMB
                    DispatchQueue.main.async {
                        progress("→ \(totalMB) MB uploaded")
                    }
                }
            }
            return true
        }
    }
}
