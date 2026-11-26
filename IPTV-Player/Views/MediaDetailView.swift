//
//  MediaDetailView.swift
//  IPTV-Player
//

import SwiftUI

/// The page of a movie or a series with plot, year, rating and playback.
struct MediaDetailView: View {
    let account: Account
    let item: MediaItem

    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var progress: ProgressStore

    @State private var detail: MediaDetail?
    @State private var seriesDetail: SeriesDetail?
    @State private var loadError: String?
    @State private var isLoading = true
    @State private var season = 1
    @State private var request: PlayerRequest?

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    actions

                    if let plot, !plot.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Overview")
                                .font(.title3.weight(.bold))
                            Text(plot)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    facts

                    if item.kind == .series {
                        episodesSection
                    } else if let loadError, detail == nil {
                        Text(loadError)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .fullScreenCover(item: $request) { request in
            PlayerScreen(request: request)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .bottom, spacing: 16) {
            PosterImage(url: detail?.posterURL ?? item.posterURL, kind: item.kind)
                .frame(width: 130)

            VStack(alignment: .leading, spacing: 8) {
                Text(item.name)
                    .font(.title2.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)

                if !metaLine.isEmpty {
                    Text(metaLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let rating {
                    Label(String(format: "%.1f", rating), systemImage: "star.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.yellow)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var isFavourite: Bool {
        preferences.isFavouriteMedia(item, for: account)
    }

    @ViewBuilder
    private var actions: some View {
        if item.kind == .movie {
            HStack(spacing: 12) {
                Button {
                    playMovie(from: resumePosition)
                } label: {
                    Label(resumeTitle, systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.glassProminent)
                .tint(.blue)

                if resumePosition > 0 {
                    Button {
                        playMovie(from: 0)
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .frame(width: 50, height: 50)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Start over")
                }

                Button {
                    preferences.toggleFavouriteMedia(item, for: account)
                } label: {
                    Image(systemName: isFavourite ? "star.fill" : "star")
                        .foregroundStyle(isFavourite ? Color.yellow : Color.primary)
                        .frame(width: 50, height: 50)
                }
                .buttonStyle(.glass)
                .accessibilityLabel(isFavourite ? "Remove from favourites" : "Add to favourites")
            }
        } else {
            Button {
                preferences.toggleFavouriteMedia(item, for: account)
            } label: {
                Label(
                    isFavourite ? "In Favourites" : "Add to Favourites",
                    systemImage: isFavourite ? "star.fill" : "star"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.glass)
        }
    }

    // MARK: - Facts

    @ViewBuilder
    private var facts: some View {
        let rows = factRows
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(rows, id: \.0) { row in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.0)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(row.1)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
        }
    }

    private var factRows: [(String, String)] {
        var rows: [(String, String)] = []
        if let director = detail?.director, !director.isEmpty { rows.append(("Director", director)) }
        if let cast = detail?.cast, !cast.isEmpty { rows.append(("Cast", cast)) }
        if let genre = detail?.genre, !genre.isEmpty { rows.append(("Genre", genre)) }
        return rows
    }

    // MARK: - Episodes

    @ViewBuilder
    private var episodesSection: some View {
        if let series = seriesDetail, !series.seasonNumbers.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Episodes")
                        .font(.title3.weight(.bold))

                    Spacer()

                    Menu {
                        Picker("Season", selection: $season) {
                            ForEach(series.seasonNumbers, id: \.self) { number in
                                Text(seasonTitle(number)).tag(number)
                            }
                        }
                    } label: {
                        Label(seasonTitle(season), systemImage: "chevron.up.chevron.down")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.glass)
                }

                ForEach(series.seasons[season] ?? []) { episode in
                    episodeRow(episode)
                }
            }
        } else if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        } else {
            Text(loadError ?? "No episodes available.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func episodeRow(_ episode: Episode) -> some View {
        let fraction = progress.fraction(for: ProgressStore.key(account: account, media: episode.key))

        return Button {
            play(episode)
        } label: {
            HStack(spacing: 12) {
                Color.white.opacity(0.08)
                    .frame(width: 118, height: 66)
                    .overlay {
                        if let thumb = episode.thumbURL {
                            AsyncImage(url: thumb) { phase in
                                if let image = phase.image {
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    Image(systemName: "play.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            Image(systemName: "play.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(episode.number). \(episode.title)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let duration = episode.duration {
                        Text(duration)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let plot = episode.plot, !plot.isEmpty {
                        Text(plot)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    if let fraction, fraction > 0 {
                        ProgressView(value: fraction)
                            .tint(.blue)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func seasonTitle(_ number: Int) -> String {
        number == 0 ? "Specials" : "Season \(number)"
    }

    // MARK: - Values

    private var plot: String? {
        detail?.plot ?? item.plot
    }

    private var rating: Double? {
        detail?.rating ?? item.rating
    }

    private var metaLine: String {
        [detail?.year ?? item.year, detail?.duration]
            .compactMap { value -> String? in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: "  ·  ")
    }

    private var movieKey: String {
        ProgressStore.key(account: account, media: item.key)
    }

    private var resumePosition: Double {
        progress.startPosition(for: movieKey)
    }

    private var resumeTitle: String {
        resumePosition > 0 ? "Resume \(timeString(resumePosition))" : "Play"
    }

    private func timeString(_ seconds: Double) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    // MARK: - Actions

    private func playMovie(from position: Double) {
        guard let client = XtreamClient(account: account),
              let url = client.movieURL(id: item.id, ext: item.containerExtension) else { return }

        request = PlayerRequest(
            title: item.name,
            url: url,
            progressKey: movieKey,
            startPosition: position
        )
    }

    private func play(_ episode: Episode) {
        guard let client = XtreamClient(account: account),
              let url = client.episodeURL(id: episode.id, ext: episode.containerExtension) else { return }

        let key = ProgressStore.key(account: account, media: episode.key)
        request = PlayerRequest(
            title: "\(item.name)  ·  \(episode.number). \(episode.title)",
            url: url,
            progressKey: key,
            startPosition: progress.startPosition(for: key)
        )
    }

    private func load() async {
        guard let client = XtreamClient(account: account) else {
            isLoading = false
            return
        }

        do {
            if item.kind == .movie {
                detail = try await client.movieDetail(id: item.id)
            } else {
                let loaded = try await client.seriesDetail(id: item.id)
                seriesDetail = loaded
                detail = loaded.detail
                season = loaded.seasonNumbers.first(where: { $0 > 0 }) ?? loaded.seasonNumbers.first ?? 1
            }
        } catch {
            if !Task.isCancelled {
                loadError = error.localizedDescription
            }
        }
        isLoading = false
    }
}
