import Foundation

// MARK: - F1ApiMainPage
struct F1ApiMainPage: Codable {
    let resultObj: F1ApiMainPageResultObj
}

// MARK: - F1ApiMainPageResultObj
struct F1ApiMainPageResultObj: Codable {
    let containers: [F1ApiPurpleContainer]
}

// MARK: - F1ApiPurpleContainer
struct F1ApiPurpleContainer: Codable {
    let layout: String
    let retrieveItems: F1ApiRetrieveItems
}

// MARK: - F1ApiRetrieveItems
struct F1ApiRetrieveItems: Codable {
    let resultObj: F1ApiRetrieveItemsResultObj
}

// MARK: - F1ApiRetrieveItemsResultObj
struct F1ApiRetrieveItemsResultObj: Codable {
    let containers: [F1ApiFluffyContainer]
}

// MARK: - F1ApiFluffyContainer
struct F1ApiFluffyContainer: Codable {
    let metadata: F1ApiFluffyMetadata
}

// MARK: - F1ApiFluffyMetadata
struct F1ApiFluffyMetadata: Codable {
    let emfAttributes: F1ApiEmfAttributes
    let pictureUrl: String?
    let season: Int?
}

// MARK: - F1ApiEmfAttributes
struct F1ApiEmfAttributes: Codable {
    let pageID: Int?
    let meetingName: String?
    let meetingStartDate: String?
    let meetingEndDate: String?
    let meetingOfficialName: String?

    enum CodingKeys: String, CodingKey {
        case pageID = "PageID"
        case meetingName = "Meeting_Name"
        case meetingStartDate = "Meeting_Start_Date"
        case meetingEndDate = "Meeting_End_Date"
        case meetingOfficialName = "Meeting_Official_Name"
    }
}
