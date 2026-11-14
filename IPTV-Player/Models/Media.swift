//
//  Media.swift
//  IPTV-Player
//

import Foundation

enum MediaKind: String, Hashable, Sendable {
    case movie
    case series

    var title: String {
        self == .movie ? "Movies" : "Series"
    }

    var searchPrompt: String {
        self == .movie ? "Search movies..." : "Search series..."
    }

    var systemImage: String {
        self == .movie ? "film" : "rectangle.stack"
    }
}

/// A movie or a series as the panel lists it.
struct MediaItem: Identifiable, Hashable, Sendable {
    let id: String
    let kind: MediaKind
    let name: String
    let posterURL: URL?
    let categoryID: String
    let rating: Double?
    let year: String?
    let plot: String?
    let containerExtension: String
    /// Unix time the panel added the title, used for the Recent tab.
    let added: Int

    var key: String {
        "\(kind.rawValue):\(id)"
    }
}

struct MediaCategory: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let items: [MediaItem]

    static func == (lhs: MediaCategory, rhs: MediaCategory) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// The long form information of a title, loaded when its page opens.
struct MediaDetail: Sendable {
    var plot: String?
    var year: String?
    var rating: Double?
    var genre: String?
    var duration: String?
    var cast: String?
    var director: String?
    var posterURL: URL?
}

struct Episode: Identifiable, Hashable, Sendable {
    let id: String
    let season: Int
    let number: Int
    let title: String
    let plot: String?
    let duration: String?
    let thumbURL: URL?
    let containerExtension: String

    var key: String {
        "episode:\(id)"
    }
}

struct SeriesDetail: Sendable {
    var detail: MediaDetail
    var seasons: [Int: [Episode]]

    var seasonNumbers: [Int] {
        seasons.keys.sorted()
    }
}
