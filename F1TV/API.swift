//
//  API.swift
//  F1TV
//
//  Created by Adam Bell on 9/27/20.
//

import Alamofire
import Foundation

// Adapted from https://github.com/bbsan2k/plugin.video.f1tv/blob/develop/resources/lib/F1TVParser/F1TV_Minimal_API.py
// Thanks for figuring out all the endpoints!

// From: https://account.formula1.com/scripts/main.min.js
let apiKey = "fCUCjWrKPu9ylJwRAv8BpGLEgiAuThx7"
let systemId = "60a9ad84-e93d-480f-80d6-af37494f2e22"

let socialAuthenticate = "https://f1tv.formula1.com/api/social-authenticate/"
let identityProvider = "/api/identity-providers/iden_732298a17f9c458890a1877880d140f3/"

let accountAPI = "https://api.formula1.com/v2/account/"
let accountCreateSession = accountAPI + "subscriber/authenticate/by-password"

let F1TVAPIBaseV1: URL = URL(string: "https://f1tv.formula1.com")!

enum F1TVEndpoints: String {

    case circuit = "/api/circuit"
    case eventOccurrence = "/api/event-occurrence"
    case raceSeason = "/api/race-season"
    case sessionOccurrence = "/api/session-occurrence"
    case viewings = "/api/viewings"
    case grandPrixWeekend = "/api/sets?slug=grand-prix-weekend-live"

    var url: URL {
        return URL(string: self.rawValue, relativeTo: F1TVAPIBaseV1)!
    }

    var baseParameters: [String: String] {
        // I don't like how this API is invoked at all -.- (albeit, I'm probably doing it the worst way possible)
        // This just gets the default parameters required for what the app needs.
        let baseParameters: [String: [String]] = {
            switch self {
            case .circuit:
                return [
                    "fields": ["name", "self", "eventoccurrence_urls", "eventoccurrence_urls__name", "eventoccurrence_urls__start_date", "eventoccurrence_urls__self", "eventoccurrence_urls__image_urls", "eventoccurrence_urls__official_name"],
                    "fields_to_expand": ["eventoccurrence_urls", "eventoccurrence_urls__image_urls"],
                ]
            case .eventOccurrence:
                return [
                    "fields": ["name", "self", "image_urls", "sessionoccurrence_urls", "official_name", "start_date", "end_date", "_nation_url__self", "nation_url__name", "nation_url__iso_country_code", "nation_url__image_urls", "sessionoccurrence_urls__session_name", "sessionoccurrence_urls__self", "sessionoccurrence_urls__image_urls", "sessionoccurrence_urls__start_time", "sessionoccurrence_urls__available_for_user", "sessionoccurrence_urls__content_urls"],
                    "fields_to_expand": ["image_urls", "sessionoccurrence_urls", "sessionoccurrence_urls__image_urls", "nation_url", "nation_url__image_urls"],
                ]
            case .raceSeason:
                return [
                    "fields": ["year", "name", "self", "eventoccurrence_urls", "eventoccurrence_urls__name", "eventoccurrence_urls__start_date", "eventoccurrence_urls__end_date", "eventoccurrence_urls__official_name", "eventoccurrence_urls__self", "eventoccurrence_urls__image_urls", "image_urls", "schedule_urls", "eventoccurrence_urls__nation_url", "eventoccurrence_urls__nation_url__self", "eventoccurrence_urls__nation_url__name", "eventoccurrence_urls__nation_url__iso_country_code", "eventoccurrence_urls__nation_url__image_urls"],
                    "fields_to_expand": ["eventoccurrence_urls", "eventoccurrence_urls__nation_url", "eventoccurrence_urls__nation_url__image_urls", "eventoccurrence_urls__image_urls", "image_urls"],
                ]
            case .sessionOccurrence:
                return [
                    "fields": ["name", "self", "image_urls", "status,channel_urls", "start_time", "content_urls", "session_name"],
                    "fields_to_expand": ["channel_urls", "image_urls", "content_urls", "channel_urls__image_urls", "content_urls__image_urls", "channel_urls__driveroccurrence_urls", "channel_urls__driveroccurrence_urls__image_urls"],
                ]
            default:
                return [:]
            }
        }()

        // Lastly just merge each field into a string of comma separated values.
        return baseParameters.mapValues { $0.joined(separator: ",") }
    }

    static func fullUrl(urlString: String) -> URL? {
        guard urlString.hasPrefix("/api") else { return nil }

        return F1TVAPIBaseV1.appendingPathComponent(urlString)
    }

}

class F1TV {

    static var shared: F1TV = F1TV()

    var headers = [
        "CD-Language": "en-US",
        "Content-Type": "application/json",
        "apikey": apiKey,
        "cd-systemid": systemId,
        "User-Agent": "RaceControl",
        "accept-language": "en",
        "Last-Modified": ""
    ]

    // MARK: - Login

    func login(username: String, password: String, completion: @escaping ((Bool) -> Void)) {
        if loggedInAndAuthorized {
            completion(true)
        }

        _login(username: username, password: password) { [weak self] (session) in
            guard let subscriptionData = session?.subscriptionData else {
                completion(false)
                return
            }

            print("[log] login completed")
            self?.updateHeaders(with: session!.subscriptionData!.subscriptionToken)
//            self?._authorize(subscriptionData: subscriptionData) { (authorized) in
//                completion(authorized)
//            }
        }
    }

    private func _login(username: String, password: String, completion: ((AccountSession?) -> Void)? ) {
        let login = [
            "DeviceType": "16",
            "DistributionChannel": "871435e3-2d31-4d4f-9004-96c6a8011656",
            "Language": "en-GB",
            "Login": username,
            "Password": password
        ]
        let authHeaders = [
             "Content-Type": "application/json",
             "apikey": apiKey,
             "CD-DeviceType": "16",
             "CD-DistributionChannel": "871435e3-2d31-4d4f-9004-96c6a8011656",
             "User-Agent": "RaceControl"
        ]
        AF.request(
            accountCreateSession,
            method: .post,
            parameters: login,
            encoder: JSONParameterEncoder.default,
            headers: HTTPHeaders(authHeaders)
        ).responseData { (response) in
            guard let data = response.data else {
                print("[Error] login failed")
                completion?(nil)
                return
            }

            let decoder = JSONDecoder()
            do {
                let session = try decoder.decode(AccountSession.self, from: data)
                completion?(session)
            } catch {
                print(error)
                completion?(nil)
            }
        }
    }

//    private func _authorize(subscriptionData: SubscriptionData, completion: ((Bool) -> Void)?) {
//        let params = ["identity_provider_url": identityProvider,
//                      "access_token": subscriptionData.subscriptionToken]
//        AF.request(socialAuthenticate, method: .post, parameters: params, encoder: JSONParameterEncoder.default, headers: HTTPHeaders(headers)).responseData { [weak self] (response) in
//            guard let data = response.data else {
//                print("authorization failed")
//                completion?(false)
//                return
//            }
//
//            let decoder = JSONDecoder()
//            do {
//                let authorization = try decoder.decode(AuthorizationData.self, from: data)
//                self?.updateHeaders(with: authorization)
//                completion?(true)
//            } catch {
//                print(error)
//                completion?(false)
//            }
//        }
//    }

    var loggedInAndAuthorized: Bool {
        return headers["Authorization"] != nil
    }

    private func updateHeaders(with token: String) {
//        headers["Authorization"] = "JWT \(authorizationData.token)"
        print("[log] token: \(token)")
        headers["ascendontoken"] = token

//        eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJFeHRlcm5hbEF1dGhvcml6YXRpb25zQ29udGV4dERhdGEiOiJBVVQiLCJTdWJzY3JpcHRpb25TdGF0dXMiOiJhY3RpdmUiLCJTdWJzY3JpYmVySWQiOiIzNTg2NTAyMyIsIkZpcnN0TmFtZSI6IkRhdmlkIiwiTGFzdE5hbWUiOiJTdGVpbmFjaGVyIiwiZXhwIjoxNjIwMjgzNzMzLCJTZXNzaW9uSWQiOiJleUowZVhBaU9pSktWMVFpTENKaGJHY2lPaUpJVXpJMU5pSjkuZXlKemFTSTZJall3WVRsaFpEZzBMV1U1TTJRdE5EZ3daaTA0TUdRMkxXRm1NemMwT1RSbU1tVXlNaUlzSW1KMUlqb2lNVEF3TVRFaUxDSnBaQ0k2SWpCa05HRTNOREU1TFdKa04yRXROR0ZrTWkxaVl6RTJMV00zTVRsak1XWmtaak0yTlNJc0ltd2lPaUpsYmkxSFFpSXNJbVJqSWpvaU1TSXNJblFpT2lJeElpd2lZV1ZrSWpvaU1qQXlNUzB3TlMwd05sUXdOam8wT0RvMU1pNDVNRFZhSWl3aVpXUWlPaUl5TURJeExUQTFMVEl5VkRBMk9qUTRPalV5TGprd05Wb2lMQ0pqWldRaU9pSXlNREl4TFRBMExUSXpWREEyT2pRNE9qVXlMamt3TlZvaUxDSnVZVzFsYVdRaU9pSXpOVGcyTlRBeU15SXNJbVIwSWpvaU1UQWlMQ0p3WkdraU9pSXpNell3TkRRek1pSXNJbWx3SWpvaU5EWXVNVEkwTGpFeE1pNHlPU0lzSW1Odklqb2lRVlZVSWl3aWJHRjBJam9pTkRndU1qQXhOeUlzSW14dmJtY2lPaUl4Tmk0ek9URTJJaXdpWXlJNklreEJUa1JUVkZKQlUxTkZJaXdpY0dNaU9pSXhNRE13SWl3aWFYTnpJam9pWVhOalpXNWtiMjR1ZEhZaUxDSmhkV1FpT2lKaGMyTmxibVJ2Ymk1MGRpSXNJbVY0Y0NJNk1UWXlNVFkyTmpFek1pd2libUptSWpveE5qRTVNRGMwTVRNeWZRLngwd0pmaE1ZWWZJMDhhVjRUNzRxUWdlaEd6SW5WUlpZSnBUZUo2N1dMRXMiLCJpYXQiOjE2MTkwNzQxMzMsIlN1YnNjcmliZWRQcm9kdWN0IjoiRjEgVFYgUHJvIE1vbnRobHkiLCJqdGkiOiI4ZjIxOTM5My1kZjBhLTRjMzgtOWQ0Yy04NzY0ZTg3MDM1ZDUifQ.ttjZ_VLgZKcaV7nfrEDgmJ_dX5pxWvO8rv9U0NTL4MwdqIP0IavQQF3lReQyzZR0qKVDv45ikBL8Z0x5xiqf3CyvSJFm8LaYqqLfnEt3tUUry10E1ZHMP9BqzJ1u3AX2Rr8IkiXG6jrKxHP2Ho7kAjBdKyCVR0Okc1ZMkpZxf74n4gfuNnMS0iBttkKGBTumsFAmzOZ8mF9B-t0kwtE_eLhK3xSuc3RKkuMz5CNYlRyKPeSTHQ-g_kfTQi68fi3NFs8K3QI6wxrmWo5uLm3FaSiO9EG4mgjJuNr549iWc-1IdBgtCPA4IQyqGmN-NGWLsTmLW8hZ_jxbh4g4hL0LAg
//        eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJlbWFpbCI6bnVsbCwiaWQiOjM3MzgyNjE0LCJleHAiOjE2MjA1NzU5MjIsInVnIjoiQVVUIn0.DmaVGfa1gg9WWg2_PTpY8Nn7ktevG1U-HDaOQ-WIMIc
    }

    // MARK: - Endpoints

    func getRaceWeekend(completion: ((Event?) -> Void)? = nil) {
        get(F1TVEndpoints.grandPrixWeekend.url, parameters: nil)
            .responseData { [weak self] (response) in
                guard let data = response.data else {
                    print(response.error.debugDescription)
                    completion?(nil)
                    return
                }

                let decoder = JSONDecoder()

                // Will actually make this better at some point, race day is tomorrow!
                do {
                    let response = try decoder.decode(GrandPrixWeekendResponse.self, from: data)
                    guard let eventUrl = response.objects.first?.items.first?.contentUrl else {
                        print("content_url missing")
                        completion?(nil)
                        return
                    }

                    self?.getEvent(eventUrl, completion: completion)
                } catch {
                    print(error)
                    completion?(nil)
                    return
                }
            }
    }

    func getSeason(_ seasonURLString: String, completion: ((Season?) -> Void)? = nil) {
        guard let url = F1TVEndpoints.fullUrl(urlString: seasonURLString) else {
            print("Failed to construct full URL from \(seasonURLString)")
            completion?(nil)
            return
        }

        let parameters = F1TVEndpoints.raceSeason.baseParameters
        get(url, parameters: parameters)
            .responseData { (response) in
                guard let data = response.data else {
                    print(response.error.debugDescription)
                    completion?(nil)
                    return
                }

                let decoder = JSONDecoder()

                do {
                    let season = try decoder.decode(Season.self, from: data)
                    completion?(season)
                    return
                } catch {
                    print(error)
                    completion?(nil)
                    return
                }
            }
    }

    func getSeasons(completion: (([SeasonsResponse.Season]?) -> Void)? = nil) {
        let parameters = [
            "order": "-year",
        ]

        get(F1TVEndpoints.raceSeason.url, parameters: parameters)
            .responseData { (response) in
                guard let data = response.data else {
                    print(response.error.debugDescription)
                    completion?(nil)
                    return
                }

                let decoder = JSONDecoder()

                do {
                    let seasons = try decoder.decode(SeasonsResponse.self, from: data).seasons
                    completion?(seasons)
                    return
                } catch {
                    print(error)
                    completion?(nil)
                    return
                }
            }
    }

    func getEvent(_ eventURLString: String, completion: ((Event?) -> Void)? = nil) {
        guard let url = F1TVEndpoints.fullUrl(urlString: eventURLString) else {
            print("Failed to construct full URL from \(eventURLString)")
            completion?(nil)
            return
        }

        let parameters = F1TVEndpoints.eventOccurrence.baseParameters
        get(url, parameters: parameters)
            .responseData { (response) in
                guard let data = response.data else {
                    print(response.error.debugDescription)
                    completion?(nil)
                    return
                }

                let decoder = JSONDecoder()

                do {
                    let event = try decoder.decode(Event.self, from: data)
                    completion?(event)
                    return
                } catch {
                    print(error)
                    completion?(nil)
                    return
                }
            }
    }

    func getEpisodesForSession(_ sessionURLString: String, completion: (([Channel]?) -> Void)? = nil) {
        guard let url = F1TVEndpoints.fullUrl(urlString: sessionURLString) else {
            print("Failed to construct full URL from \(sessionURLString)")
            completion?(nil)
            return
        }

        let parameters = F1TVEndpoints.sessionOccurrence.baseParameters
        get(url, parameters: parameters)
            .responseData { (response) in
                guard let data = response.data else {
                    print(response.error.debugDescription)
                    completion?(nil)
                    return
                }

                let decoder = JSONDecoder()

                do {
                    let session = try decoder.decode(Session_Episodes.self, from: data)
                    completion?(session.channels)
                    return
                } catch {
                    print(error)
                    completion?(nil)
                    return
                }
            }
    }

    func getStream(_ url: String, completion: ((URL?) -> Void)? = nil) {
        //        get(URL(string: url, relativeTo: F1APIBaseV1)!, parameters: nil)
        //            .responseData { [weak self] (response) in
        //                guard let data = response.data else {
        //                    print(response.error.debugDescription)
        //                    return
        //                }
        //                let obj = try! JSONSerialization.jsonObject(with: data, options: []) as! Dictionary<String, Any>
        //
        //                guard let assetURL = (obj["items"] as? Array<String>)?.first else {
        //                    return
        //                }
        //                print(assetURL)

        let key = url.contains("asse") ? "asset_url" : "channel_url"
        let parameters = [key: url]
        post(F1TVEndpoints.viewings.url, parameters: parameters)
            .responseData { (response) in
                guard let data = response.data else {
                    print(response.error.debugDescription)
                    return
                }

                let decoder = JSONDecoder()

                if let stream_ = try? decoder.decode(StreamP1.self, from: data), let stream = stream_.objects.first?.tata {
                    completion?(stream.URL)
                    return
                } else if let stream = try? decoder.decode(Stream.self, from: data) {
                    completion?(stream.URL)
                    return
                }

                print("Decoding stream failed.")
                completion?(nil)
            }
        //            }
    }

    func get(_ URL: URL, parameters: [String: String]?) -> some DataRequest {
        return AF.request(URL, method: .get, parameters: parameters, encoder: URLEncodedFormParameterEncoder.default, headers: HTTPHeaders(headers))
    }

    func post(_ URL: URL, parameters: [String: String]?) -> some DataRequest {
        return AF.request(URL, method: .post, parameters: parameters, encoder: JSONParameterEncoder.default, headers: HTTPHeaders(headers))
    }

}

struct AuthorizationData: Codable {

    let token: String

}

struct SubscriptionData: Codable {

    let subscriptionStatus: String
    let subscriptionToken: String

    var hasValidSubscription: Bool {
        return subscriptionStatus == "Active"
    }

}

struct AccountSession: Codable {

    let subscriptionData: SubscriptionData?

    private enum CodingKeys : String, CodingKey {
        case subscriptionData = "data"
    }

}

struct Season: Codable {

    let URL: String
    let year: Int
    let name: String
    let events: [Event]
    let scheduleURLs: [String]

    enum CodingKeys: String, CodingKey {
        case URL = "self"
        case year
        case name
        case events = "eventoccurrence_urls"
        case scheduleURLs = "schedule_urls"
    }

}

struct SeasonsResponse: Codable {

    struct Season: Codable {

        let URL: String
        let year: Int
        let name: String
        let eventURLs: [String]
        let scheduleURLs: [String]

        enum CodingKeys: String, CodingKey {
            case URL = "self"
            case year
            case name
            case eventURLs = "eventoccurrence_urls"
            case scheduleURLs = "schedule_urls"
        }

    }

    let seasons: [SeasonsResponse.Season]

    enum CodingKeys: String, CodingKey {
        case seasons = "objects"
    }

}

// TODO: split ViewModels and DAOs for v1 and v2 API
struct Event: Codable, Hashable {

    // TODO: Streamline this once fully switching to one API version.
    //       If the pageId is set it's using the v2 API and if the URL is present it should go to the v1 API.
    let pageId: Int?
    let URL: String?

    let name: String
    let imageURLs: [Image]
    let startDate: String
    let endDate: String
    let officialName: String
    let sessions: [Session]?
    let nation: Nation?

    // v2 only
    let meetingKey: String?

    init(
        pageId: Int? = nil,
        URL: String? = nil,
        name: String,
        imageURLs: [Image],
        startDate: String,
        endDate: String,
        officialName: String,
        sessions: [Session]? = nil,
        nation: Nation? = nil,
        meetingKey: String? = nil
    ) {
        self.pageId = pageId
        self.URL = URL
        self.name = name
        self.imageURLs = imageURLs
        self.startDate = startDate
        self.endDate = endDate
        self.officialName = officialName
        self.sessions = sessions
        self.nation = nation
        self.meetingKey = meetingKey
    }

    enum CodingKeys: String, CodingKey {
        case pageId
        case name
        case URL = "self"
        case imageURLs = "image_urls"
        case startDate = "start_date"
        case endDate = "end_date"
        case officialName = "official_name"
        case sessions = "sessionoccurrence_urls"
        case nation = "nation_url"
        case meetingKey
    }

    var sessionNamePrefix: String? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = dateFormatter.date(from: startDate) else { return nil }

        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)

        return "\(year) \(name)"
    }

}

struct Session: Codable, Hashable {

    let URL: String
    let name: String
//    let startTime: String
    let imageURLs: [Image]
//    let available: Bool
//    let contentURLs: [String]

    // v2 only
    let contentId: String?

    enum CodingKeys: String, CodingKey {
        case URL = "self"
        case name = "session_name"
//        case startTime = "start_time"
        case imageURLs = "image_urls"
        case contentId
//        case available = "available_for_user"
//        case contentURLs = "content_urls"
    }

}

struct Nation: Codable, Hashable {

    let URL: String
    let name: String
    let countryCode: String
    let imageURLs: [Image]

    enum CodingKeys: String, CodingKey {
        case URL = "self"
        case name
        case countryCode = "iso_country_code"
        case imageURLs = "image_urls"
    }

}

struct Session_Episodes: Codable, Hashable {

    let episodes: [Episode]
    let channels: [Channel]

    enum CodingKeys: String, CodingKey {
        case episodes = "content_urls"
        case channels = "channel_urls"
    }

}

struct Channel: Codable, Hashable {

    let URL: String
    let name: String
    let channelType: String
    let imageURLs: [Image]
    let drivers: [Driver]

    enum CodingKeys: String, CodingKey {
        case URL = "self"
        case name
        case channelType = "channel_type"
        case imageURLs = "image_urls"
        case drivers = "driveroccurrence_urls"
    }

}

struct Episode: Codable, Hashable {

    let URL: String
    let title: String
    let imageURLs: [Image]

    enum CodingKeys: String, CodingKey {
        case URL = "self"
        case title
        case imageURLs = "image_urls"
    }

}

struct Driver: Codable, Hashable {

    struct DriverImage: Codable, Hashable {
        let URL: URL
        let title: String
        let imageType: String

        enum CodingKeys: String, CodingKey {
            case URL = "url"
            case title
            case imageType = "image_type"
        }
    }

    let URL: String
    let name: String
    let imageURLs: [DriverImage]

    enum CodingKeys: String, CodingKey {
        case URL = "self"
        case name
        case imageURLs = "image_urls"
    }

}

struct Image: Codable, Hashable {

    let URL: URL
    let title: String

    enum CodingKeys: String, CodingKey {
        case URL = "url"
        case title
    }

}

private struct StreamP1: Codable {
    let objects: [StreamP2]
}

private struct StreamP2: Codable {
    let tata: Stream
}

private struct Stream: Codable {
    let URL: URL

    enum CodingKeys: String, CodingKey {
        case URL = "tokenised_url"
    }
}

struct GrandPrixWeekendResponse: Codable {

    struct ResponseObject: Codable {
        struct ResponseItem: Codable {
            let contentUrl: String

            enum CodingKeys: String, CodingKey {
                case contentUrl = "content_url"
            }
        }

        let items: [ResponseItem]
    }

    let objects: [ResponseObject]

}
