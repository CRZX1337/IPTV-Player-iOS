//
//  ProgressStore.swift
//  IPTV-Player
//

import Foundation
import SwiftUI

/// Remembers where a movie or an episode stopped, so it can resume there.
@MainActor
final class ProgressStore: ObservableObject {
    struct Entry: Codable, Equatable {
        var position: Double
        var duration: Double
        var updatedAt: Date
    }

    @Published private(set) var entries: [String: Entry] = [:]

    private let defaultsKey = "playback.progress"
    private let defaults = UserDefaults.standard
    private let maximumEntries = 400

    init() {
        if let data = defaults.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) {
            entries = decoded
        }
    }

    static func key(account: Account, media: String) -> String {
        "\(account.id)|\(media)"
    }

    func startPosition(for key: String) -> Double {
        entries[key]?.position ?? 0
    }

    /// How much of the title was watched, between 0 and 1.
    func fraction(for key: String) -> Double? {
        guard let entry = entries[key], entry.duration > 0 else { return nil }
        return min(max(entry.position / entry.duration, 0), 1)
    }

    func save(key: String, position: Double, duration: Double) {
        guard position.isFinite, duration.isFinite, duration > 0 else { return }

        // Almost at the end counts as finished, the next start begins from the top.
        let remaining = duration - position
        if remaining < max(30, duration * 0.03) {
            clear(key: key)
            return
        }
        // Barely started, nothing worth resuming.
        if position < 10 {
            return
        }

        entries[key] = Entry(position: position, duration: duration, updatedAt: Date())

        if entries.count > maximumEntries {
            let oldest = entries.sorted { $0.value.updatedAt < $1.value.updatedAt }
                .prefix(entries.count - maximumEntries)
            for (oldKey, _) in oldest {
                entries.removeValue(forKey: oldKey)
            }
        }
        persist()
    }

    func clear(key: String) {
        guard entries.removeValue(forKey: key) != nil else { return }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: defaultsKey)
    }
}
