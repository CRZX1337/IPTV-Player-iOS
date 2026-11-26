//
//  MediaLibraryView.swift
//  IPTV-Player
//

import SwiftUI

enum LibraryTab: String, CaseIterable, Hashable {
    case all
    case recent
    case favourites

    var title: String {
        switch self {
        case .all: return "All"
        case .recent: return "Recent"
        case .favourites: return "Favourites"
        }
    }
}

/// The Movies and the Series tab: category rows of posters.
struct MediaLibraryView: View {
    let account: Account
    @ObservedObject var library: MediaLibraryStore

    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var progress: ProgressStore

    @State private var search = ""
    @State private var tab: LibraryTab = .all

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(spacing: 14) {
                            GlassSegmentedControl(
                                options: LibraryTab.allCases,
                                title: { $0.title },
                                selection: $tab
                            )
                        }
                        .padding(.horizontal, 20)

                        content
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.immediately)
                .searchable(text: $search, prompt: library.kind.searchPrompt)
            }
            .navigationTitle(library.kind.title)
            .navigationDestination(for: MediaItem.self) { item in
                MediaDetailView(account: account, item: item)
            }
            .navigationDestination(for: MediaCategory.self) { category in
                MediaCategoryScreen(account: account, category: category)
            }
        }
        .task { await library.load(account: account) }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch library.phase {
        case .idle, .loading:
            VStack(spacing: 14) {
                ProgressView()
                Text("Loading \(library.kind.title.lowercased())")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 80)

        case .failed(let message):
            MessageState(
                systemImage: "exclamationmark.triangle.fill",
                title: "Couldn't load \(library.kind.title.lowercased())",
                message: message,
                retry: {
                    Task { await library.load(account: account, force: true) }
                }
            )

        case .loaded:
            if !trimmedSearch.isEmpty {
                grid(
                    of: searchResults,
                    emptyTitle: "No matches",
                    emptyMessage: "Nothing found for “\(trimmedSearch)”.",
                    emptyIcon: "magnifyingglass"
                )
            } else {
                switch tab {
                case .all:
                    categoryRows
                case .recent:
                    grid(
                        of: library.recentItems,
                        emptyTitle: "Nothing recent",
                        emptyMessage: "The service has not added any titles lately.",
                        emptyIcon: "clock"
                    )
                case .favourites:
                    grid(
                        of: favouriteItems,
                        emptyTitle: "No favourites yet",
                        emptyMessage: "Open a title and tap the star to keep it here.",
                        emptyIcon: "star"
                    )
                }
            }
        }
    }

    private var categoryRows: some View {
        LazyVStack(alignment: .leading, spacing: 26) {
            ForEach(library.categories) { category in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(category.title)
                            .font(.title3.weight(.bold))
                            .lineLimit(1)

                        Spacer(minLength: 12)

                        NavigationLink(value: category) {
                            HStack(spacing: 4) {
                                Text("See All")
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)

                    ScrollView(.horizontal) {
                        LazyHStack(alignment: .top, spacing: 12) {
                            ForEach(category.items.prefix(30)) { item in
                                NavigationLink(value: item) {
                                    PosterCard(
                                        item: item,
                                        fraction: progress.fraction(
                                            for: ProgressStore.key(account: account, media: item.key)
                                        )
                                    )
                                    .frame(width: 100)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
    }

    @ViewBuilder
    private func grid(
        of items: [MediaItem],
        emptyTitle: String,
        emptyMessage: String,
        emptyIcon: String
    ) -> some View {
        if items.isEmpty {
            MessageState(systemImage: emptyIcon, title: emptyTitle, message: emptyMessage)
        } else {
            MediaGrid(account: account, items: items)
        }
    }

    // MARK: - Data

    private var trimmedSearch: String {
        search.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var searchResults: [MediaItem] {
        let query = trimmedSearch
        return Array(
            library.allItems
                .filter { $0.name.localizedCaseInsensitiveContains(query) }
                .prefix(300)
        )
    }

    private var favouriteItems: [MediaItem] {
        let keys = preferences.favouriteMediaKeys(for: account)
        return library.allItems.filter { keys.contains($0.key) }
    }
}
