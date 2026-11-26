//
//  LiveTVView.swift
//  IPTV-Player
//

import SwiftUI
import UIKit

enum CategoryFilter: Hashable {
    case all
    case favourites
    case category(String)
}

/// How the channel list is laid out: one channel a row, or a two column grid of tiles.
enum ChannelLayout {
    case list
    case grid
}

struct LiveTVView: View {
    let account: Account

    @EnvironmentObject private var liveTV: LiveTVStore
    @EnvironmentObject private var preferences: PreferencesStore

    @State private var search = ""
    @State private var filter: CategoryFilter = .all
    @State private var layout: ChannelLayout = .grid
    @State private var playback: LivePlayback?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                List {
                    Section {
                        controls
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listSectionSeparator(.hidden)
                    }

                    content
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.immediately)
                .searchable(text: $search, prompt: "Search channels")
            }
            .navigationTitle("Live TV")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    layoutToggle
                }
            }
        }
        .task { await liveTV.load(account: account) }
        .fullScreenCover(item: $playback) { live in
            PlayerScreen(live: live) { channel in
                preferences.recordWatch(channel.id, for: account)
            }
        }
        .onChange(of: liveTV.groups) {
            if case .category(let id) = filter, !liveTV.groups.contains(where: { $0.id == id }) {
                filter = .all
            }
        }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Watch your favourite channels live.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            categoryChips
        }
    }

    /// One toolbar button that switches between the rows and the grid.
    private var layoutToggle: some View {
        Button {
            withAnimation(.snappy(duration: 0.26)) {
                layout = layout == .list ? .grid : .list
            }
        } label: {
            Image(systemName: layout == .list ? "square.grid.2x2" : "list.bullet")
        }
        .accessibilityLabel(layout == .list ? "Show grid" : "Show list")
    }

    private var categoryChips: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    chip(for: .all, title: "All")

                    chip(for: .favourites, title: "Favourites", icon: "star.fill")

                    ForEach(liveTV.groups) { group in
                        chip(
                            for: .category(group.id),
                            title: group.title,
                            isFavourite: preferences.isFavourite(group.id, for: account),
                            group: group
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }
        }
        .scrollIndicators(.hidden)
    }

    private func chip(
        for value: CategoryFilter,
        title: String,
        icon: String? = nil,
        isFavourite: Bool = false,
        group: ChannelGroup? = nil
    ) -> some View {
        let isSelected = filter == value

        return Button {
            withAnimation(.snappy(duration: 0.24)) {
                filter = value
            }
        } label: {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                } else if isFavourite {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.yellow))
                }

                Text(title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .glassEffect(isSelected ? .regular.tint(.blue).interactive() : .regular.interactive(), in: Capsule())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let group {
                let favourite = preferences.isFavourite(group.id, for: account)
                Button {
                    preferences.toggleFavourite(group.id, for: account)
                } label: {
                    Label(
                        favourite ? "Remove from Favourites" : "Add to Favourites",
                        systemImage: favourite ? "star.slash" : "star"
                    )
                }
            }
        }
    }

    // MARK: - List content

    @ViewBuilder
    private var content: some View {
        switch liveTV.phase {
        case .idle, .loading:
            statusRow(
                title: "Loading channels",
                message: "Large playlists can take a moment.",
                systemImage: nil,
                showsSpinner: true,
                retry: nil
            )

        case .failed(let message):
            statusRow(
                title: "Couldn't load channels",
                message: message,
                systemImage: "exclamationmark.triangle.fill",
                showsSpinner: false,
                retry: {
                    Task { await liveTV.reload(account: account) }
                }
            )

        case .loaded:
            if showsChannelFavourites {
                favouriteChannelsSection
            }

            if showsRecentlyWatched {
                recentlyWatchedSection
            }

            if filteredGroups.isEmpty {
                if !showsChannelFavourites || favouriteChannels.isEmpty {
                    emptyState
                }
            } else {
                ForEach(filteredGroups) { group in
                    Section {
                        channelContent(group.channels, category: group.title)
                    } header: {
                        header(for: group)
                    }
                }
            }
        }
    }

    private func header(for group: ChannelGroup) -> some View {
        HStack(spacing: 6) {
            Text(group.title)
                .font(.headline)
                .foregroundStyle(.primary)

            if preferences.isFavourite(group.id, for: account) {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }

            Spacer()

            Text(group.channelCountLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .textCase(nil)
    }

    // MARK: - Favourites and recently watched

    private var favouriteChannels: [Channel] {
        preferences.favouriteChannelIDs(for: account).compactMap { liveTV.channel(withID: $0) }
    }

    private var recentlyWatchedChannels: [Channel] {
        preferences.recentChannelIDs(for: account).compactMap { liveTV.channel(withID: $0) }
    }

    private var searchQuery: String {
        search.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The starred channels lead the list, on top of the favourite categories.
    private var showsChannelFavourites: Bool {
        searchQuery.isEmpty && (filter == .all || filter == .favourites)
    }

    private var showsRecentlyWatched: Bool {
        searchQuery.isEmpty && filter == .all && !recentlyWatchedChannels.isEmpty
    }

    @ViewBuilder
    private var favouriteChannelsSection: some View {
        let channels = favouriteChannels

        if !channels.isEmpty {
            Section {
                channelContent(channels, category: nil)
            } header: {
                sectionHeader("Favourites", systemImage: "star.fill", tint: .yellow)
            }
        }
    }

    @ViewBuilder
    private var recentlyWatchedSection: some View {
        Section {
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(recentlyWatchedChannels) { channel in
                        Button {
                            play(channel)
                        } label: {
                            RecentlyWatchedCard(channel: channel)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } header: {
            sectionHeader("Recently Watched", systemImage: "clock.arrow.circlepath", tint: .blue)
        }
    }

    private func sectionHeader(_ title: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(tint)

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()
        }
        .textCase(nil)
    }

    /// Channels in the layout the toolbar picked: rows, or a two column grid of tiles.
    @ViewBuilder
    private func channelContent(_ channels: [Channel], category: String?) -> some View {
        switch layout {
        case .list:
            ForEach(Array(channels.indices), id: \.self) { index in
                channelRow(channels[index], category: category)
                    .softAppear(index: index)
            }

        case .grid:
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 14, alignment: .top),
                    GridItem(.flexible(), spacing: 14, alignment: .top)
                ],
                alignment: .leading,
                spacing: 20
            ) {
                ForEach(Array(channels.indices), id: \.self) { index in
                    channelTile(channels[index], category: category)
                        .softAppear(index: index)
                }
            }
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 12, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private func channelRow(_ channel: Channel, category: String?) -> some View {
        let isFavourite = preferences.isFavouriteChannel(channel.id, for: account)

        return Button {
            play(channel)
        } label: {
            ChannelRow(
                channel: channel,
                category: categoryTitle(for: channel, fallback: category),
                isFavourite: isFavourite
            )
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Rectangle().fill(.ultraThinMaterial))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                preferences.toggleFavouriteChannel(channel.id, for: account)
            } label: {
                Label(
                    isFavourite ? "Unfavourite" : "Favourite",
                    systemImage: isFavourite ? "star.slash.fill" : "star.fill"
                )
            }
            .tint(.yellow)
        }
        .contextMenu {
            channelMenu(for: channel, isFavourite: isFavourite)
        }
    }

    private func channelTile(_ channel: Channel, category: String?) -> some View {
        let isFavourite = preferences.isFavouriteChannel(channel.id, for: account)

        return Button {
            play(channel)
        } label: {
            ChannelGridTile(
                channel: channel,
                category: categoryTitle(for: channel, fallback: category),
                isFavourite: isFavourite
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            channelMenu(for: channel, isFavourite: isFavourite)
        }
    }

    @ViewBuilder
    private func channelMenu(for channel: Channel, isFavourite: Bool) -> some View {
        Button {
            play(channel)
        } label: {
            Label("Play", systemImage: "play.fill")
        }

        Button {
            UIPasteboard.general.string = channel.name
        } label: {
            Label("Copy name", systemImage: "doc.on.doc")
        }

        Divider()

        favouriteButton(for: channel, isFavourite: isFavourite)
    }

    private func favouriteButton(for channel: Channel, isFavourite: Bool) -> some View {
        Button {
            preferences.toggleFavouriteChannel(channel.id, for: account)
        } label: {
            Label(
                isFavourite ? "Remove from Favourites" : "Add to Favourites",
                systemImage: isFavourite ? "star.slash" : "star"
            )
        }
        .tint(.yellow)
    }

    private func categoryTitle(for channel: Channel, fallback: String?) -> String? {
        liveTV.categoryTitle(forChannelID: channel.id) ?? fallback
    }

    private func play(_ channel: Channel) {
        preferences.recordWatch(channel.id, for: account)

        // The player steps through the channels of the category the tapped one belongs to.
        let group = liveTV.groups.first { group in
            group.channels.contains { $0.id == channel.id }
        }
        let channels = group?.channels ?? [channel]
        let start = channels.firstIndex { $0.id == channel.id } ?? 0

        playback = LivePlayback(
            channels: channels,
            startIndex: start,
            categoryTitle: group?.title ?? liveTV.categoryTitle(forChannelID: channel.id)
        )
    }

    @ViewBuilder
    private var emptyState: some View {
        switch filter {
        case .favourites:
            statusRow(
                title: "No favourite categories",
                message: "Long press a category above to add it to your favourites.",
                systemImage: "star",
                showsSpinner: false,
                retry: nil
            )
        case .category:
            statusRow(
                title: "No channels",
                message: search.isEmpty
                    ? "This category has no channels."
                    : "Nothing found for “\(search)”.",
                systemImage: "tv.slash",
                showsSpinner: false,
                retry: nil
            )
        case .all:
            statusRow(
                title: search.isEmpty ? "No channels" : "No matches",
                message: search.isEmpty
                    ? "This service returned no live channels."
                    : "Nothing found for “\(search)”.",
                systemImage: "magnifyingglass",
                showsSpinner: false,
                retry: nil
            )
        }
    }

    private func statusRow(
        title: String,
        message: String,
        systemImage: String?,
        showsSpinner: Bool,
        retry: (() -> Void)?
    ) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    if showsSpinner {
                        ProgressView()
                    } else if let systemImage {
                        Image(systemName: systemImage)
                            .foregroundStyle(.secondary)
                    }
                    Text(title)
                        .font(.headline)
                    Spacer()
                }

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let retry {
                    Button("Try Again", action: retry)
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.glass)
                        .tint(.blue)
                }
            }
            .padding(.vertical, 8)
            .listRowBackground(Rectangle().fill(.ultraThinMaterial))
        }
    }

    // MARK: - Filtering

    private var filteredGroups: [ChannelGroup] {
        let base: [ChannelGroup]
        switch filter {
        case .all:
            base = liveTV.groups
        case .favourites:
            let ids = preferences.favouriteIDs(for: account)
            base = liveTV.groups.filter { ids.contains($0.id) }
        case .category(let id):
            base = liveTV.groups.filter { $0.id == id }
        }

        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return base }

        return base.compactMap { group in
            let hits = group.channels.filter { $0.name.localizedCaseInsensitiveContains(query) }
            guard !hits.isEmpty else { return nil }
            return ChannelGroup(id: group.id, title: group.title, channels: hits)
        }
    }
}
