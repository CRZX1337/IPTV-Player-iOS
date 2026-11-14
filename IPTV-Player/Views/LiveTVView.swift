//
//  LiveTVView.swift
//  IPTV-Player
//

import SwiftUI

enum CategoryFilter: Hashable {
    case all
    case favourites
    case category(String)
}

struct LiveTVView: View {
    let account: Account

    @EnvironmentObject private var liveTV: LiveTVStore
    @EnvironmentObject private var preferences: PreferencesStore

    @State private var search = ""
    @State private var filter: CategoryFilter = .all
    @State private var playing: Channel?
    @State private var showsSettings = false

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
            }
            .navigationTitle("Live TV")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Settings")
                }
            }
        }
        .task { await liveTV.load(account: account) }
        .fullScreenCover(item: $playing) { channel in
            PlayerScreen(channel: channel)
        }
        .sheet(isPresented: $showsSettings) {
            SettingsView(account: account)
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
            searchField
            categoryChips
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search channels", text: $search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 20)
    }

    private var categoryChips: some View {
        ScrollView(.horizontal) {
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
            .glassEffect(isSelected ? .regular.tint(.blue) : .regular, in: Capsule())
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
            if filteredGroups.isEmpty {
                emptyState
            } else {
                ForEach(filteredGroups) { group in
                    Section {
                        ForEach(group.channels) { channel in
                            Button {
                                playing = channel
                            } label: {
                                ChannelRow(channel: channel)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.white.opacity(0.07))
                        }
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
            .listRowBackground(Color.white.opacity(0.07))
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
