//
//  MediaComponents.swift
//  IPTV-Player
//

import SwiftUI

/// A poster in 2:3 with rounded corners and a calm placeholder.
struct PosterImage: View {
    let url: URL?
    let kind: MediaKind

    var body: some View {
        Color.white.opacity(0.08)
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .overlay {
                if let url {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                        } else {
                            placeholder
                        }
                    }
                } else {
                    placeholder
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            )
    }

    private var placeholder: some View {
        Image(systemName: kind.systemImage)
            .font(.title2)
            .foregroundStyle(.secondary)
    }
}

/// Poster with its title underneath, as used in the rows and the grids.
struct PosterCard: View {
    let item: MediaItem
    var fraction: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PosterImage(url: item.posterURL, kind: item.kind)
                .overlay(alignment: .bottom) {
                    if let fraction, fraction > 0 {
                        ProgressView(value: fraction)
                            .tint(.white)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 8)
                    }
                }

            Text(item.name)
                .font(.footnote)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Poster grid used by See All, Recent, Favourites and the search results.
struct MediaGrid: View {
    let account: Account
    let items: [MediaItem]

    @EnvironmentObject private var progress: ProgressStore

    private let columns = [GridItem(.adaptive(minimum: 100, maximum: 170), spacing: 14, alignment: .top)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
            ForEach(items) { item in
                NavigationLink(value: item) {
                    PosterCard(
                        item: item,
                        fraction: progress.fraction(for: ProgressStore.key(account: account, media: item.key))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }
}

/// A full poster grid for one category.
struct MediaCategoryScreen: View {
    let account: Account
    let category: MediaCategory

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                MediaGrid(account: account, items: category.items)
                    .padding(.vertical, 12)
            }
        }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct GlassSearchField: View {
    let prompt: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(prompt, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    text = ""
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
    }
}

/// A centred message with an icon and an optional retry.
struct MessageState: View {
    let systemImage: String
    let title: String
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 38))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let retry {
                Button("Try Again", action: retry)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.glass)
                    .tint(.blue)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.vertical, 60)
    }
}
