//  UploadRetryPolicy.swift
//  Retry and index-refresh policy for Dataverse uploads.

import Foundation

struct UploadRetryPolicy {
    let maxAttempts: Int
    let baseBackoff: Double

    func shouldRetry(_ error: Error, attempt: Int) -> Bool {
        Self.isTransient(error) && attempt < maxAttempts - 1
    }

    func sleep(attempt: Int, factor: Double = 2.0) async {
        let delay = baseBackoff * pow(factor, Double(attempt - 1))
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }

    static func isTransient(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .networkConnectionLost,
                 .dnsLookupFailed,
                 .notConnectedToInternet,
                 .internationalRoamingOff,
                 .callIsActive,
                 .dataNotAllowed,
                 .requestBodyStreamExhausted,
                 .cannotLoadFromNetwork,
                 .resourceUnavailable:
                return true
            default:
                return false
            }
        }
        if let posixError = error as? POSIXError {
            switch posixError.code {
            case .ECONNRESET, .ENETDOWN, .EPIPE, .ETIMEDOUT:
                return true
            default:
                return false
            }
        }
        return false
    }
}

final class DataverseIndexRefreshPolicy {
    private let interval: TimeInterval
    private let everyFiles: Int
    private var lastRefresh = Date()
    private var processedSinceRefresh = 0

    init(interval: TimeInterval, everyFiles: Int) {
        self.interval = interval
        self.everyFiles = max(1, everyFiles)
    }

    func recordProcessedFile() {
        processedSinceRefresh += 1
    }

    func shouldRefresh(force: Bool = false) -> Bool {
        force || Date().timeIntervalSince(lastRefresh) > interval || processedSinceRefresh >= everyFiles
    }

    func recordRefresh() {
        lastRefresh = Date()
        processedSinceRefresh = 0
    }
}
