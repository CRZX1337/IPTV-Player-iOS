//
//  PreferencesStore.swift
//  IPTV-Player
//

import Foundation
import SwiftUI

/// Remembers per account which categories and which movies or series are favourites.
@MainActor
final class PreferencesStore: ObservableObject {
    @Published private var favouriteCategories: [String: Set<String>] = [:]
    @Published private var favouriteMedia: [String: Set<String>] = [:]

    private let categoriesKey = "preferences.favouriteCategories"
    private let mediaKey = "preferences.favouriteMedia"
    private let defaults = UserDefaults.standard

    init() {
        favouriteCategories = Self.load(key: categoriesKey, from: defaults)
        favouriteMedia = Self.load(key: mediaKey, from: defaults)
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
}
