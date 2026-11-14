//
//  CategoryListView.swift
//  IPTV-Player
//

import SwiftUI

/// Lets the user star the categories that matter to them.
struct CategoryListView: View {
    let account: Account

    @EnvironmentObject private var liveTV: LiveTVStore
    @EnvironmentObject private var preferences: PreferencesStore

    @State private var search = ""

    var body: some View {
        List {
            if visibleGroups.isEmpty {
                Section {
                    Text(search.isEmpty ? "No categories loaded yet." : "No categories match “\(search)”.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(visibleGroups) { group in
                        row(for: group)
                    }
                } footer: {
                    Text("Favourite categories appear first in Live TV and can be shown on their own.")
                }
            }
        }
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "Search categories")
    }

    private func row(for group: ChannelGroup) -> some View {
        let isFavourite = preferences.isFavourite(group.id, for: account)

        return Button {
            preferences.toggleFavourite(group.id, for: account)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.title)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(group.channelCountLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: isFavourite ? "star.fill" : "star")
                    .foregroundStyle(isFavourite ? AnyShapeStyle(.yellow) : AnyShapeStyle(.tertiary))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var visibleGroups: [ChannelGroup] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return liveTV.groups }
        return liveTV.groups.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }
}
