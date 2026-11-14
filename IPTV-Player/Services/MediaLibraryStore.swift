//
//  MediaLibraryStore.swift
//  IPTV-Player
//

import Foundation
import SwiftUI

/// Loads the movies or the series of an Xtream account.
@MainActor
final class MediaLibraryStore: ObservableObject {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    let kind: MediaKind

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var categories: [MediaCategory] = []
    @Published private(set) var allItems: [MediaItem] = []
    @Published private(set) var recentItems: [MediaItem] = []

    private var loadedAccountID: String?

    init(kind: MediaKind) {
        self.kind = kind
    }

    func load(account: Account, force: Bool = false) async {
        if !force, loadedAccountID == account.id, phase == .loaded || phase == .loading {
            return
        }
        guard let client = XtreamClient(account: account) else {
            phase = .failed("Movies and series need an Xtream Codes account.")
            return
        }

        loadedAccountID = account.id
        if phase != .loaded {
            phase = .loading
        }

        do {
            let categories = try await client.mediaCategories(kind: kind)
            let all = categories.flatMap(\.items)

            self.categories = categories
            allItems = all
            recentItems = Array(all.sorted { $0.added > $1.added }.prefix(60))
            phase = .loaded
        } catch {
            // A cancelled load (the user left the tab) is not an error, it simply runs again later.
            if Task.isCancelled || (error as? URLError)?.code == .cancelled {
                loadedAccountID = nil
                if phase == .loading { phase = .idle }
                return
            }
            if phase == .loaded && force { return }

            loadedAccountID = nil
            categories = []
            allItems = []
            recentItems = []
            phase = .failed(error.localizedDescription)
        }
    }

    func reset() {
        loadedAccountID = nil
        categories = []
        allItems = []
        recentItems = []
        phase = .idle
    }
}
