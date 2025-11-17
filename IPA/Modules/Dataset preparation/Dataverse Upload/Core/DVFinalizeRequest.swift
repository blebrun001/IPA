//  Encodable payload that informs Dataverse about a completed direct upload,
//  pairing the storage identifier with metadata to register the file in draft.
import Foundation

/// Payload sent to Dataverse after a successful direct upload so the file appears in the dataset draft.
public struct DVFinalizeRequest: Encodable {
    public let storageIdentifier: String
    public let fileName: String
    public let mimeType: String?
    public let directoryLabel: String?
    public let description: String?

    public init(storageIdentifier: String,
                fileName: String,
                mimeType: String?,
                directoryLabel: String? = nil,
                description: String? = nil) {
        self.storageIdentifier = storageIdentifier
        self.fileName = fileName
        self.mimeType = mimeType
        self.directoryLabel = directoryLabel
        self.description = description
    }
}
