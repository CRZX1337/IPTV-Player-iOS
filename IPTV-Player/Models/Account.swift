//
//  Account.swift
//  IPTV-Player
//

import Foundation

/// A saved connection to a TV service, either an Xtream Codes panel or a plain M3U playlist.
struct Account: Codable, Equatable, Identifiable {
    enum Kind: String, Codable {
        case xtream
        case m3u
    }

    var kind: Kind
    /// Base address of an Xtream panel, or the playlist address for an M3U account.
    var server: String
    var username: String
    var password: String
    var displayName: String

    var id: String {
        "\(kind.rawValue)|\(server)|\(username)"
    }

    var kindDescription: String {
        switch kind {
        case .xtream: return "Xtream Codes"
        case .m3u: return "M3U playlist"
        }
    }
}
