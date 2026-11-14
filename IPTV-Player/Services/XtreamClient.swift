//
//  XtreamClient.swift
//  IPTV-Player
//

import Foundation

/// Talks to the `player_api.php` endpoint every Xtream Codes panel exposes.
struct XtreamClient: Sendable {
    enum Failure: LocalizedError {
        case invalidResponse
        case invalidCredentials
        case expired
        case unavailable(Int)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "The server sent an unexpected answer."
            case .invalidCredentials:
                return "Wrong server, username or password."
            case .expired:
                return "This subscription has expired."
            case .unavailable(let code):
                return "The server answered with status \(code)."
            }
        }
    }

    let baseURL: URL
    let username: String
    let password: String

    // MARK: - Public API

    /// Verifies the login against the panel.
    func authenticate() async throws {
        let data = try await get(apiURL(action: nil))
        guard let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Failure.invalidResponse
        }
        guard let user = payload["user_info"] as? [String: Any] else {
            throw Failure.invalidCredentials
        }

        let status = Self.string(user["status"])?.lowercased()
        if status == "expired" {
            throw Failure.expired
        }
        if Self.isTruthy(user["auth"]) || status == "active" {
            return
        }
        throw Failure.invalidCredentials
    }

    /// Loads every live channel, grouped by the categories the panel defines.
    func liveGroups() async throws -> [ChannelGroup] {
        async let categoriesTask = get(apiURL(action: "get_live_categories"))
        async let streamsTask = get(apiURL(action: "get_live_streams"))
        let (categoryData, streamData) = try await (categoriesTask, streamsTask)

        let categories = Self.array(categoryData)
        let streams = Self.array(streamData)

        var titles: [String: String] = [:]
        var orderedIDs: [String] = []
        for category in categories {
            guard let id = Self.string(category["category_id"]), !id.isEmpty else { continue }
            titles[id] = Self.string(category["category_name"]) ?? "Other"
            orderedIDs.append(id)
        }

        var channelsByCategory: [String: [Channel]] = [:]
        var seen = Set<String>()
        for stream in streams {
            guard let rawID = Self.string(stream["stream_id"]),
                  let name = Self.string(stream["name"])?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty,
                  let streamURL = streamURL(streamID: rawID) else { continue }
            guard seen.insert(rawID).inserted else { continue }

            let categoryID = Self.string(stream["category_id"]) ?? ""
            let logo = Self.string(stream["stream_icon"]).flatMap { URL(string: $0) }
            let channel = Channel(id: rawID, name: name, logoURL: logo, streamURL: streamURL)
            channelsByCategory[categoryID, default: []].append(channel)
        }

        var groups: [ChannelGroup] = []
        var used = Set<String>()
        for id in orderedIDs {
            guard used.insert(id).inserted, let list = channelsByCategory[id], !list.isEmpty else { continue }
            groups.append(ChannelGroup(id: id, title: titles[id] ?? "Other", channels: list))
        }
        for (id, list) in channelsByCategory where !used.contains(id) && !list.isEmpty {
            let title = id.isEmpty ? "Other" : (titles[id] ?? "Other")
            groups.append(ChannelGroup(id: id.isEmpty ? "uncategorised" : id, title: title, channels: list))
        }

        return groups.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// Native HLS address for a live channel.
    func streamURL(streamID: String) -> URL? {
        var base = baseURL.absoluteString
        while base.hasSuffix("/") { base.removeLast() }
        return URL(string: "\(base)/live/\(Self.encode(username))/\(Self.encode(password))/\(Self.encode(streamID)).m3u8")
    }

    // MARK: - Networking

    private func apiURL(action: String?) -> URL? {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("player_api.php"),
            resolvingAgainstBaseURL: false
        )
        var items = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password)
        ]
        if let action {
            items.append(URLQueryItem(name: "action", value: action))
        }
        components?.queryItems = items
        return components?.url
    }

    private func get(_ url: URL?) async throws -> Data {
        guard let url else { throw Failure.invalidResponse }

        var request = URLRequest(url: url, timeoutInterval: 25)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw Failure.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw Failure.unavailable(http.statusCode) }
        return data
    }

    // MARK: - Helpers

    static let userAgent = "VLC/3.0.18 LibVLC/3.0.18"

    private static func array(_ data: Data) -> [[String: Any]] {
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return [] }
        return object as? [[String: Any]] ?? []
    }

    static func string(_ value: Any?) -> String? {
        switch value {
        case let text as String:
            return text
        case let number as Int:
            return String(number)
        case let number as Double:
            return String(Int(number))
        case let flag as Bool:
            return flag ? "1" : "0"
        default:
            return nil
        }
    }

    static func isTruthy(_ value: Any?) -> Bool {
        switch value {
        case let flag as Bool:
            return flag
        case let number as Int:
            return number != 0
        case let text as String:
            return ["1", "true", "active"].contains(text.lowercased())
        default:
            return false
        }
    }

    private static func encode(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
