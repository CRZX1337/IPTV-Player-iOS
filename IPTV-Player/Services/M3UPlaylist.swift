//
//  M3UPlaylist.swift
//  IPTV-Player
//

import Foundation

/// Reads the `#EXTINF` playlist format most providers hand out.
enum M3UParser {
    private struct Pending {
        var name: String
        var logo: URL?
        var group: String
    }

    static func parse(_ text: String) -> [ChannelGroup] {
        var channelsByGroup: [String: [Channel]] = [:]
        var groupOrder: [String] = []
        var seenURLs = Set<String>()
        var pending: Pending?

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("#EXTINF:") {
                let attributes = attributes(in: line)
                var name = displayName(in: line)
                if name.isEmpty {
                    name = attributes["tvg-name"] ?? ""
                }
                var group = attributes["group-title"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if group.isEmpty { group = "Other" }
                pending = Pending(
                    name: name,
                    logo: attributes["tvg-logo"].flatMap { URL(string: $0) },
                    group: group
                )
            } else if line.hasPrefix("#EXTGRP:") {
                let group = line.dropFirst("#EXTGRP:".count).trimmingCharacters(in: .whitespacesAndNewlines)
                if !group.isEmpty {
                    pending?.group = group
                }
            } else if line.hasPrefix("#") {
                continue
            } else {
                guard let entry = pending,
                      !entry.name.isEmpty,
                      let url = URL(string: line),
                      url.scheme != nil else {
                    pending = nil
                    continue
                }
                pending = nil

                guard seenURLs.insert(url.absoluteString).inserted else { continue }

                if channelsByGroup[entry.group] == nil {
                    groupOrder.append(entry.group)
                }
                let channel = Channel(
                    id: url.absoluteString,
                    name: entry.name,
                    logoURL: entry.logo,
                    streamURL: url
                )
                channelsByGroup[entry.group, default: []].append(channel)
            }
        }

        let groups = groupOrder.compactMap { title -> ChannelGroup? in
            guard let channels = channelsByGroup[title], !channels.isEmpty else { return nil }
            return ChannelGroup(id: title, title: title, channels: channels)
        }
        return groups.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private static func attributes(in line: String) -> [String: String] {
        var result: [String: String] = [:]
        let pattern = "([A-Za-z0-9_-]+)=\"([^\"]*)\""
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }

        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        for match in regex.matches(in: line, range: range) {
            guard match.numberOfRanges == 3,
                  let keyRange = Range(match.range(at: 1), in: line),
                  let valueRange = Range(match.range(at: 2), in: line) else { continue }
            result[String(line[keyRange]).lowercased()] = String(line[valueRange])
        }
        return result
    }

    /// The channel name is everything after the last comma that sits outside quotes.
    private static func displayName(in line: String) -> String {
        var insideQuotes = false
        var lastComma: String.Index?
        var index = line.startIndex

        while index < line.endIndex {
            let character = line[index]
            if character == "\"" {
                insideQuotes.toggle()
            } else if character == ",", !insideQuotes {
                lastComma = index
            }
            index = line.index(after: index)
        }

        guard let lastComma else { return "" }
        return String(line[line.index(after: lastComma)...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
