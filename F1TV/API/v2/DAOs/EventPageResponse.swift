import Foundation

// MARK: - F1ApiEventResponse
struct F1ApiEventResponse: Codable {
    let resultObj: F1ApiResultObj?
}

// MARK: - F1ApiResultObj
struct F1ApiResultObj: Codable {
    let containers: [F1ApiContainer]?
}

// MARK: - F1ApiContainer
struct F1ApiContainer: Codable {
    let id: String
    let metadata: F1ApiMetadata?
}

// MARK: - F1ApiMetadata
struct F1ApiMetadata: Codable {
    let longDescription: String?
    let pictureUrl: String?

    enum CodingKeys: String, CodingKey {
        case longDescription = "longDescription"
        case pictureUrl = "pictureUrl"
    }
}
