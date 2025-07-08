import Foundation

struct UBERONResponse: Codable {
    let response: UBERONInnerResponse
}

struct UBERONInnerResponse: Codable {
    let docs: [UBERONDocument]
}

struct UBERONDocument: Codable, Identifiable, Hashable {
    var id: String { obo_id }
    let label: String
    let obo_id: String

    enum CodingKeys: String, CodingKey {
        case label
        case obo_id
    }
}
