import Alamofire
import Foundation

private let F1TVAPIv2BasePath: String = "/2.0/R/ENG/BIG_SCREEN_HLS"
private let pagePlaceholder = "${page}"
private let urlTemplate = "/ALL/\(pagePlaceholder)/F1_TV_Pro_Monthly/14"

struct F1TVEndpointV2 {

    enum Helper: String {
        case imageResizer = "https://ott.formula1.com/image-resizer/image/"
    }

    enum Page: String {
        static let prefix = "PAGE/"
        case main = "395"
        case search = "SEARCH/VOD"

        var url: URL {
            return Self.url(pageId: rawValue)
        }

        static func url(pageId: String) -> URL {
            let pagePath = urlTemplate.replacingOccurrences(of: pagePlaceholder, with: "\(Self.prefix)\(pageId)")
            let path = "\(F1TVAPIv2BasePath)\(pagePath)"

            return URL(string: path, relativeTo: F1TVAPIBaseV1)!
        }
    }
}

extension F1TV {
    private func getMainPage(completion: ((F1ApiMainPage) -> Void)? = nil) {
        get(F1TVEndpointV2.Page.main.url, parameters: nil)
            .responseDecodable(of: F1ApiMainPage.self) { response in
                guard let mainPage = response.value else {
                    print("[Error] error loading main Page")
                    return
                }

                completion?(mainPage)
            }
    }

    func getRaceWeekend_v2(completion: ((Event?) -> Void)? = nil) {
        getMainPage { [weak self] mainPage in
            guard let self = self else {
                return
            }

            guard let activeRaceWeekend = getActiveRaceWeekend(from: mainPage) else {
                completion?(nil)
                return
            }

            let event = Event(
                pageId: activeRaceWeekend.pageId ?? activeRaceWeekend.id,
                name: activeRaceWeekend.name,
                imageURLs: [
                    Image(URL: buildImageUrl(id: activeRaceWeekend.pictureId), title: "Unkonwn") // TODO: is this title used?
                ],
                startDate: activeRaceWeekend.startDate,
                endDate: activeRaceWeekend.endDate,
                officialName: activeRaceWeekend.officialName,
                meetingKey: activeRaceWeekend.meetingKey
            )

            completion?(event)
        }
    }

    func getEvent_v2(_ event: Event, completion: ((Event?) -> Void)? = nil) {
        guard let meetingKey = event.meetingKey else {
            print("[Error] Event does not have a meetingKey")
            return
        }

        let sessionFilterParams = [
            "filter_objectSubtype": "Replay,LIVE_EVENT",
            "orderBy": "session_index",
            "sortOrder": "asc",
            "filter_MeetingKey": meetingKey,
            "filter_orderByFom": "Y",
            "title": "Replays"
        ]

        print("url \(F1TVEndpointV2.Page.search.url)")
        get(F1TVEndpointV2.Page.search.url, parameters: sessionFilterParams)
            .responseData { response in
                print(response)

                guard let data = response.data,
                      let eventResponse = try? JSONDecoder().decode(F1ApiEventResponse.self, from: data) else {
                    print("error")
                    return
                }

                let sessions = eventResponse.resultObj?.containers?.map {
                    buildSession(from: $0)
                }

                let newEvent = Event(
                    pageId: event.pageId,
                    URL: event.URL,
                    name: event.name,
                    imageURLs: event.imageURLs,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    officialName: event.officialName,
                    sessions: sessions,
                    nation: nil,
                    meetingKey: event.meetingKey
                )

                completion?(newEvent)
            }
    }

    func getStream_v2(_ url: String, completion: ((URL) -> Void)? = nil) {
        get(URL(string: url)!, parameters: nil)
            .responseDecodable(of: F1TVManifestResponse.self) { response in
                guard let data = response.value else {
                    print("[Error] error fetching manifest")
                    return
                }

                guard let manifestUrlString = data.resultObj.url,
                    let manifestUrl = URL(string: manifestUrlString) else {
                    print("[Error] stream url missing")
                    return
                }

                completion?(manifestUrl)
            }
    }

    /// Returns a currently live session (Not the current race weekend)
//    func getLiveEvent(completion: ((Event_2?) -> Void)? = nil) {
//        get(F1TVEndpointV2.Page.main.url, parameters: nil)
//            .responseData { (response) in
//                guard let data = response.data else {
//                    print(response.error.debugDescription)
//                    completion?(nil)
//                    return
//                }
//
//                let decoder = JSONDecoder()
//
//                do {
//                    let response = try decoder.decode(GrandPrixWeekendResponse.self, from: data)
//                    guard let liveEvent = response
//                        .resultObj
//                        .containers
//                        .map({ $0.retrieveItems })
//                        .map({ $0.resultObj.containers })
//                        .flatMap({ $0 })
//                        .first(where: { $0.metadata.contentSubtype == .live }) else {
//                        print("[Info] No live event found")
//                        completion?(nil)
//                        return
//                    }
//
//                    print("[Debug] contentId of live event: \(liveEvent.id)")
//                    completion?(liveEvent)
//                } catch {
//                    print("[Error] failed loading live event: \(error)")
//                    completion?(nil)
//                    return
//                }
//            }
//    }

    // on main page https://f1tv.formula1.com/2.0/R/DEU/MOBILE_HLS/ALL/PAGE/395/F1_TV_Pro_Monthly/14
    // Find active weekend when `"layout": "gp_banner",` (inside `containers`)
    // Meeting_Display_Date
    // "PageID": 1347, ⬇️

    // Weekend overview: (How to find this)
    // https://f1tv.formula1.com/2.0/R/DEU/MOBILE_HLS/ALL/PAGE/1347/F1_TV_Pro_Monthly/14
    // filter for "properties": ["series": "FORMULA 1",
    // metadata contains start and end time timestamps
    // long description contains localized value to display
    // title is full description
    // titleBrief is short

    // Season overview:
    // https://f1tv.formula1.com/2.0/R/DEU/MOBILE_HLS/ALL/PAGE/1510/F1_TV_Pro_Monthly/14
    // Contains previous and past races
    // page infos of events is present in: containers-actions-uri
    // e.g. bahrain https://f1tv.formula1.com/2.0/R/DEU/MOBILE_HLS/ALL/PAGE/1532/F1_TV_Pro_Monthly/14
}

// MARK: - helpers
private func getActiveRaceWeekend(from mainPage: F1ApiMainPage) -> ActiveRaceWeekend? {
    guard let raceWeekendContainer = mainPage.resultObj.containers.first(where: { $0.layout == "hero"}) else {
        return nil
    }

    guard let innerContainer = raceWeekendContainer.retrieveItems.resultObj.containers.first else {
        return nil
    }

    let metadata = innerContainer.metadata
    return ActiveRaceWeekend(from: metadata, id: Int(innerContainer.id))
}

private func buildSession(from eventContainer: F1ApiContainer) -> Session {
    let mainChannelUrl = "https://f1tv.formula1.com/1.0/R/ENG/BIG_SCREEN_HLS/ALL/CONTENT/PLAY?contentId=\(eventContainer.id)"

    return Session(
        URL: mainChannelUrl,
        name: eventContainer.metadata!.longDescription!,
        imageURLs: [
            Image(URL: buildImageUrl(id: eventContainer.metadata!.pictureUrl!), title: "Unkonwn")
        ],
        contentId: eventContainer.id
    )
}

private func buildImageUrl(id: String) -> URL {
    let imageWidth = 1280
    let imageHeight = 720

    var components = URLComponents(url: URL(string: F1TVEndpointV2.Helper.imageResizer.rawValue + id)!, resolvingAgainstBaseURL: true)!
    components.queryItems = [
        URLQueryItem(name: "w", value: "\(imageWidth)"),
        URLQueryItem(name: "h", value: "\(imageHeight)"),
    ]

    return components.url!
}

// MARK: - ViewModels
struct ActiveRaceWeekend {
    let id: Int?
    let pageId: Int?
    let name: String
    let startDate: String
    let endDate: String
    let officialName: String
    let pictureId: String
    let season: Int?
    let meetingKey: String?

    init?(from metadata: F1ApiFluffyMetadata, id: Int?) {
        // TODO: improve optional handling
        guard let attributes = metadata.emfAttributes else {
            return nil
        }

        self.id = id
        self.pageId = attributes.pageID
        self.name = attributes.meetingName!
        self.startDate = attributes.meetingStartDate!
        self.endDate = attributes.meetingEndDate!
        self.officialName = attributes.meetingOfficialName!
        self.pictureId = metadata.pictureUrl!
        self.season = metadata.season
        self.meetingKey = attributes.meetingKey
    }
}
