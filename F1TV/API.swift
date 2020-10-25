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

            self?._authorize(subscriptionData: subscriptionData) { (authorized) in
                completion(authorized)
            }
        }
    }

    private func _login(username: String, password: String, completion: ((AccountSession?) -> Void)? ) {
        let login = ["Login": username,
                     "Password": password]
        AF.request(accountCreateSession, method: .post, parameters: login, encoder: JSONParameterEncoder.default, headers: HTTPHeaders(headers)).responseData { (response) in
            guard let data = response.data else {
                print("login failed")
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

    private func _authorize(subscriptionData: SubscriptionData, completion: ((Bool) -> Void)?) {
        let params = ["identity_provider_url": identityProvider,
                      "access_token": subscriptionData.subscriptionToken]
        AF.request(socialAuthenticate, method: .post, parameters: params, encoder: JSONParameterEncoder.default, headers: HTTPHeaders(headers)).responseData { [weak self] (response) in
            guard let data = response.data else {
                print("authorization failed")
                completion?(false)
                return
            }

            let decoder = JSONDecoder()
            do {
                let authorization = try decoder.decode(AuthorizationData.self, from: data)
                self?.updateHeaders(with: authorization)
                completion?(true)
            } catch {
                print(error)
                completion?(false)
            }
        }
    }

    var loggedInAndAuthorized: Bool {
        return headers["Authorization"] != nil
    }

    private func updateHeaders(with authorizationData: AuthorizationData) {
        headers["Authorization"] = "JWT \(authorizationData.token)"
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

    private func get(_ URL: URL, parameters: [String: String]?) -> some DataRequest {
        return AF.request(URL, method: .get, parameters: parameters, encoder: URLEncodedFormParameterEncoder.default, headers: HTTPHeaders(headers))
    }

    private func post(_ URL: URL, parameters: [String: String]?) -> some DataRequest {
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

struct Event: Codable, Hashable {

    let URL: String
    let name: String
    let imageURLs: [Image]
    let startDate: String
    let endDate: String
    let officialName: String
    let sessions: [Session]?
    let nation: Nation?

    enum CodingKeys: String, CodingKey {
        case name
        case URL = "self"
        case imageURLs = "image_urls"
        case startDate = "start_date"
        case endDate = "end_date"
        case officialName = "official_name"
        case sessions = "sessionoccurrence_urls"
        case nation = "nation_url"
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
    let startTime: String
    let imageURLs: [Image]
    let available: Bool
    let contentURLs: [String]

    enum CodingKeys: String, CodingKey {
        case URL = "self"
        case name = "session_name"
        case startTime = "start_time"
        case imageURLs = "image_urls"
        case available = "available_for_user"
        case contentURLs = "content_urls"
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
