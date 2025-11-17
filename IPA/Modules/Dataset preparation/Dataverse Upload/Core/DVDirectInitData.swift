//  Codable representations of the Dataverse direct-upload initialization
//  response, capturing presigned URLs and headers needed for storage uploads.
import Foundation

/// Response payload returned by the Dataverse direct-upload initialization endpoint.
public struct DVDirectInitData: Decodable {
    public let url: String?
    public let urls: [String:String]?
    public let partSize: Int?
    public let storageIdentifier: String
    public let abort: String?
    public let complete: String?
    public let headers: [String:String]?
}

public struct DVDirectInitResponse: Decodable {
    public let status: String
    public let data: DVDirectInitData
}
