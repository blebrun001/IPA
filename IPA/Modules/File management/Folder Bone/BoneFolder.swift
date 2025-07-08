import Foundation

// global response of the OLS API
struct OLSResponse: Codable {
    let response: OLSInnerResponse
}

struct OLSInnerResponse: Codable {
    let docs: [OLSDocument]
}

struct OLSDocument: Codable, Identifiable {
    var id: String { obo_id }  // to allow use in SwiftUI list

    let label: String
    let obo_id: String

    enum CodingKeys: String, CodingKey {
        case label
        case obo_id
    }
}
