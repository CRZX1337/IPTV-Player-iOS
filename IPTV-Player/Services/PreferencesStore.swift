//
//  PreferencesStore.swift
//  IPTV-Player
//

import Foundation
import SwiftUI

/// Remembers per account which categories are favourites.
@MainActor
final class PreferencesStore: ObservableObject {
    @Published private var favouriteCategories: [String: Set<String>] = [:]

    private let defaultsKey = "preferences.favouriteCategories"
    private let defaults = UserDefaults.standard

    init() {
        load()
    }

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
        persist()
    }

    private func load() {
        guard let data = defaults.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return
        }
        favouriteCategories = decoded.mapValues { Set($0) }
    }

    private func persist() {
        let encodable = favouriteCategories.mapValues { Array($0) }
        guard let data = try? JSONEncoder().encode(encodable) else { return }
        defaults.set(data, forKey: defaultsKey)
    }
}
