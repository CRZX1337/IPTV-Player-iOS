//
//  XtreamClient+Media.swift
//  IPTV-Player
//

import Foundation

/// Movies and series of an Xtream Codes panel.
extension XtreamClient {
    init?(account: Account) {
        guard account.kind == .xtream, let url = URL(string: account.server) else { return nil }
        self.init(baseURL: url, username: account.username, password: account.password)
    }

    // MARK: - Lists

    func mediaCategories(kind: MediaKind) async throws -> [MediaCategory] {
        let categoryAction = kind == .movie ? "get_vod_categories" : "get_series_categories"
        let itemAction = kind == .movie ? "get_vod_streams" : "get_series"

        async let categoriesTask = get(apiURL(action: categoryAction))
        async let itemsTask = get(apiURL(action: itemAction))
        let (categoryData, itemData) = try await (categoriesTask, itemsTask)

        var titles: [String: String] = [:]
        var order: [String] = []
        for category in Self.array(categoryData) {
            guard let id = Self.string(category["category_id"]), !id.isEmpty else { continue }
            titles[id] = Self.string(category["category_name"]) ?? "Other"
            order.append(id)
        }

        let idKey = kind == .movie ? "stream_id" : "series_id"
        var itemsByCategory: [String: [MediaItem]] = [:]
        var seen = Set<String>()

        for entry in Self.array(itemData) {
            guard let id = Self.string(entry[idKey]), !id.isEmpty,
                  let name = Self.string(entry["name"])?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty,
                  seen.insert(id).inserted else { continue }

            var rating = Self.double(entry["rating"])
            if rating == nil || rating == 0, let fiveBased = Self.double(entry["rating_5based"]) {
                rating = fiveBased * 2
            }
            if let value = rating, value <= 0 { rating = nil }

            let categoryID = Self.string(entry["category_id"]) ?? ""
            let item = MediaItem(
                id: id,
                kind: kind,
                name: name,
                posterURL: Self.url(Self.firstString(entry, ["stream_icon", "cover"])),
                categoryID: categoryID,
                rating: rating,
                year: Self.year(from: Self.firstString(entry, ["year", "releaseDate", "release_date", "releasedate"])),
                plot: Self.firstString(entry, ["plot"]),
                containerExtension: Self.firstString(entry, ["container_extension"]) ?? "mp4",
                added: Int(Self.firstString(entry, ["added", "last_modified"]) ?? "") ?? 0
            )
            itemsByCategory[categoryID, default: []].append(item)
        }

        var categories: [MediaCategory] = []
        var used = Set<String>()
        for id in order {
            guard used.insert(id).inserted, let items = itemsByCategory[id], !items.isEmpty else { continue }
            categories.append(MediaCategory(id: id, title: titles[id] ?? "Other", items: items))
        }
        for (id, items) in itemsByCategory where !used.contains(id) && !items.isEmpty {
            categories.append(
                MediaCategory(
                    id: id.isEmpty ? "uncategorised" : id,
                    title: titles[id] ?? "Other",
                    items: items
                )
            )
        }

        return categories.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    // MARK: - Details

    func movieDetail(id: String) async throws -> MediaDetail {
        let data = try await get(apiURL(action: "get_vod_info", extra: [URLQueryItem(name: "vod_id", value: id)]))
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Failure.invalidResponse
        }
        return Self.detail(from: root["info"] as? [String: Any] ?? [:])
    }

    func seriesDetail(id: String) async throws -> SeriesDetail {
        let data = try await get(apiURL(action: "get_series_info", extra: [URLQueryItem(name: "series_id", value: id)]))
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Failure.invalidResponse
        }

        let detail = Self.detail(from: root["info"] as? [String: Any] ?? [:])

        var seasons: [Int: [Episode]] = [:]
        if let grouped = root["episodes"] as? [String: Any] {
            for (key, value) in grouped {
                guard let list = value as? [[String: Any]] else { continue }
                let season = Int(key) ?? 0
                seasons[season] = Self.episodes(from: list, season: season)
            }
        } else if let grouped = root["episodes"] as? [Any] {
            for (index, value) in grouped.enumerated() {
                guard let list = value as? [[String: Any]] else { continue }
                seasons[index + 1] = Self.episodes(from: list, season: index + 1)
            }
        }
        seasons = seasons.filter { !$0.value.isEmpty }

        return SeriesDetail(detail: detail, seasons: seasons)
    }

    // MARK: - Stream addresses

    func movieURL(id: String, ext: String) -> URL? {
        mediaURL(folder: "movie", id: id, ext: ext)
    }

    func episodeURL(id: String, ext: String) -> URL? {
        mediaURL(folder: "series", id: id, ext: ext)
    }

    private func mediaURL(folder: String, id: String, ext: String) -> URL? {
        var base = baseURL.absoluteString
        while base.hasSuffix("/") { base.removeLast() }
        let cleanExtension = ext.trimmingCharacters(in: .whitespaces).isEmpty ? "mp4" : ext
        return URL(
            string: "\(base)/\(folder)/\(Self.encode(username))/\(Self.encode(password))/\(Self.encode(id)).\(Self.encode(cleanExtension))"
        )
    }

    // MARK: - Parsing helpers

    private static func episodes(from list: [[String: Any]], season: Int) -> [Episode] {
        var result: [Episode] = []
        for entry in list {
            guard let id = string(entry["id"]), !id.isEmpty else { continue }

            let number = Int(string(entry["episode_num"]) ?? "") ?? (result.count + 1)
            let info = entry["info"] as? [String: Any] ?? [:]
            var title = string(entry["title"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if title.isEmpty { title = "Episode \(number)" }

            result.append(
                Episode(
                    id: id,
                    season: season,
                    number: number,
                    title: title,
                    plot: firstString(info, ["plot"]),
                    duration: duration(from: info),
                    thumbURL: url(firstString(info, ["movie_image", "cover"])),
                    containerExtension: string(entry["container_extension"]) ?? "mp4"
                )
            )
        }
        return result.sorted { $0.number < $1.number }
    }

    private static func detail(from info: [String: Any]) -> MediaDetail {
        var rating = double(info["rating"])
        if rating == nil || rating == 0, let fiveBased = double(info["rating_5based"]) {
            rating = fiveBased * 2
        }
        if let value = rating, value <= 0 { rating = nil }

        return MediaDetail(
            plot: firstString(info, ["plot", "description"]),
            year: year(from: firstString(info, ["releasedate", "releaseDate", "release_date", "year"])),
            rating: rating,
            genre: firstString(info, ["genre"]),
            duration: duration(from: info),
            cast: firstString(info, ["cast", "actors"]),
            director: firstString(info, ["director"]),
            posterURL: url(firstString(info, ["movie_image", "cover_big", "cover"]))
        )
    }

    private static func duration(from info: [String: Any]) -> String? {
        if let secondsText = string(info["duration_secs"]), let seconds = Int(secondsText), seconds > 0 {
            return formatted(seconds: seconds)
        }
        guard let text = string(info["duration"])?.trimmingCharacters(in: .whitespaces), !text.isEmpty else {
            return nil
        }
        let parts = text.split(separator: ":").compactMap { Int($0) }
        if parts.count == 3 {
            let seconds = parts[0] * 3600 + parts[1] * 60 + parts[2]
            return seconds > 0 ? formatted(seconds: seconds) : nil
        }
        return text
    }

    private static func formatted(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(max(minutes, 1)) min"
    }

    static func firstString(_ entry: [String: Any], _ keys: [String]) -> String? {
        for key in keys {
            if let value = string(entry[key])?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                return value
            }
        }
        return nil
    }

    static func double(_ value: Any?) -> Double? {
        switch value {
        case let number as Double:
            return number
        case let number as Int:
            return Double(number)
        case let text as String:
            return Double(text.trimmingCharacters(in: .whitespaces))
        default:
            return nil
        }
    }

    static func url(_ text: String?) -> URL? {
        guard let text, !text.isEmpty else { return nil }
        return URL(string: text)
    }

    static func year(from text: String?) -> String? {
        guard let text, let range = text.range(of: "(19|20)\\d{2}", options: .regularExpression) else {
            return nil
        }
        return String(text[range])
    }
}
