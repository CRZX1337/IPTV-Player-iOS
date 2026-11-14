//
//  Channel.swift
//  IPTV-Player
//

import Foundation

struct Channel: Identifiable, Hashable {
    let id: String
    let name: String
    let logoURL: URL?
    let streamURL: URL
}

struct ChannelGroup: Identifiable, Hashable {
    let id: String
    let title: String
    let channels: [Channel]
}

extension ChannelGroup {
    var channelCountLabel: String {
        channels.count == 1 ? "1 channel" : "\(channels.count) channels"
    }
}
