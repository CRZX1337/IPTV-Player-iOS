//
//  PreferencesStore.swift
//  IPTV-Player
//

import Foundation
import SwiftUI

/// Remembers per account which categories, channels and movies or series are favourites,
/// and which channels were watched last.
@MainActor
final class PreferencesStore: ObservableObject {
    @Published private var favouriteCategories: [String: Set<String>] = [:]
    @Published private var favouriteMedia: [String: Set<String>] = [:]
    @Published private var favouriteChannelIDsByAccount: [String: [String]] = [:]
    @Published private var recentChannelIDsByAccount: [String: [String]] = [:]

    private let categoriesKey = "preferences.favouriteCategories"
    private let mediaKey = "preferences.favouriteMedia"
    private let channelsKey = "preferences.favouriteChannels"
    private let recentKey = "preferences.recentlyWatched"

    private static let recentlyWatchedLimit = 20

    private let defaults = UserDefaults.standard

    init() {
        favouriteCategories = Self.load(key: categoriesKey, from: defaults)
        favouriteMedia = Self.load(key: mediaKey, from: defaults)
        favouriteChannelIDsByAccount = Self.loadLists(key: channelsKey, from: defaults)
        recentChannelIDsByAccount = Self.loadLists(key: recentKey, from: defaults)
    }

    // MARK: - Categories

    func favouriteIDs(for account: Account) -> Set<String> {
        favouriteCategories[account.id] ?? []
    }

    func isFavourite(_ categoryID: String, for account: Account) -> Bool {
        favouriteCategories[account.id, default: []].contains(categoryID)
    }

    func toggleFavourite(_ categoryID: String, for account: Account) {
        var ids = favouriteCategories[account.id, default: []]
        if ids.contains(categoryID) {
            ids.remove(categoryID)
        } else {
            ids.insert(categoryID)
        }
        favouriteCategories[account.id] = ids
        Self.persist(favouriteCategories, key: categoriesKey, to: defaults)
    }

    // MARK: - Movies and series

    func favouriteMediaKeys(for account: Account) -> Set<String> {
        favouriteMedia[account.id] ?? []
    }

    func isFavouriteMedia(_ item: MediaItem, for account: Account) -> Bool {
        favouriteMedia[account.id, default: []].contains(item.key)
    }

    func toggleFavouriteMedia(_ item: MediaItem, for account: Account) {
        var keys = favouriteMedia[account.id, default: []]
        if keys.contains(item.key) {
            keys.remove(item.key)
        } else {
            keys.insert(item.key)
        }
        favouriteMedia[account.id] = keys
        Self.persist(favouriteMedia, key: mediaKey, to: defaults)
    }

    // MARK: - Channels

    /// Channel identifiers the user starred, newest first.
    func favouriteChannelIDs(for account: Account) -> [String] {
        favouriteChannelIDsByAccount[account.id] ?? []
    }

    func isFavouriteChannel(_ channelID: String, for account: Account) -> Bool {
        favouriteChannelIDsByAccount[account.id, default: []].contains(channelID)
    }

    func toggleFavouriteChannel(_ channelID: String, for account: Account) {
        var ids = favouriteChannelIDsByAccount[account.id, default: []]
        if let index = ids.firstIndex(of: channelID) {
            ids.remove(at: index)
        } else {
            ids.insert(channelID, at: 0)
        }
        favouriteChannelIDsByAccount[account.id] = ids
        Self.persistLists(favouriteChannelIDsByAccount, key: channelsKey, to: defaults)
    }

    /// Channel identifiers that were played, newest first.
    func recentChannelIDs(for account: Account) -> [String] {
        recentChannelIDsByAccount[account.id] ?? []
    }

    func recordWatch(_ channelID: String, for account: Account) {
        var ids = recentChannelIDsByAccount[account.id, default: []]
        ids.removeAll { $0 == channelID }
        ids.insert(channelID, at: 0)
        if ids.count > Self.recentlyWatchedLimit {
            ids = Array(ids.prefix(Self.recentlyWatchedLimit))
        }
        recentChannelIDsByAccount[account.id] = ids
        Self.persistLists(recentChannelIDsByAccount, key: recentKey, to: defaults)
    }

    // MARK: - Storage

    private static func load(key: String, from defaults: UserDefaults) -> [String: Set<String>] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return [:]
        }
        return decoded.mapValues { Set($0) }
    }

    private static func persist(_ value: [String: Set<String>], key: String, to defaults: UserDefaults) {
        let encodable = value.mapValues { Array($0) }
        guard let data = try? JSONEncoder().encode(encodable) else { return }
        defaults.set(data, forKey: key)
    }

    private static func loadLists(key: String, from defaults: UserDefaults) -> [String: [String]] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private static func persistLists(_ value: [String: [String]], key: String, to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
