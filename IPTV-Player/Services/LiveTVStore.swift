//
//  LiveTVStore.swift
//  IPTV-Player
//

import Foundation
import SwiftUI

@MainActor
final class LiveTVStore: ObservableObject {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var groups: [ChannelGroup] = []

    private var loadedAccountID: String?

    func load(account: Account) async {
        if loadedAccountID == account.id, phase == .loaded { return }

        loadedAccountID = account.id
        phase = .loading
        do {
            let groups = try await Self.fetchGroups(for: account)
            self.groups = groups
            phase = .loaded
        } catch {
            groups = []
            phase = .failed(error.localizedDescription)
        }
    }

    func reload(account: Account) async {
        loadedAccountID = nil
        await load(account: account)
    }

    /// Takes over channels that were already downloaded while signing in.
    func prime(_ groups: [ChannelGroup], for account: Account) {
        loadedAccountID = account.id
        self.groups = groups
        phase = .loaded
    }

    func reset() {
        loadedAccountID = nil
        groups = []
        phase = .idle
    }

    private static func fetchGroups(for account: Account) async throws -> [ChannelGroup] {
        guard let url = URL(string: account.server) else { throw ResolverError.badAddress }

        let groups: [ChannelGroup]
        switch account.kind {
        case .xtream:
            let client = XtreamClient(baseURL: url, username: account.username, password: account.password)
            groups = try await client.liveGroups()
        case .m3u:
            let text = try await PlaylistDownloader.text(from: url)
            groups = M3UParser.parse(text)
        }

        guard !groups.isEmpty else { throw ResolverError.emptyPlaylist }
        return groups
    }
}
