import Foundation

struct F1TVManifestResponse: Codable {
    let resultObj: F1TVResultObject
}

struct F1TVResultObject: Codable {
    let entitlementToken: String?
    let url: String?
}
