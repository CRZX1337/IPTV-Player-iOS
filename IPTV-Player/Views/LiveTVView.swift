//
//  LiveTVView.swift
//  IPTV-Player
//

import SwiftUI

struct LiveTVView: View {
    let account: Account

    @EnvironmentObject private var accounts: AccountStore
    @EnvironmentObject private var liveTV: LiveTVStore

    @State private var search = ""
    @State private var playing: Channel?
    @State private var confirmsSignOut = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    header
                        .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listSectionSeparator(.hidden)
                }

                content
            }
            .listStyle(.insetGrouped)
            .environment(\.defaultMinListRowHeight, 44)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    signOutButton
                }
            }
        }
        .task { await liveTV.load(account: account) }
        .fullScreenCover(item: $playing) { channel in
            PlayerScreen(channel: channel)
        }
        .confirmationDialog(
            "Sign out of this service?",
            isPresented: $confirmsSignOut,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                liveTV.reset()
                accounts.signOut()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Live TV")
                    .font(.system(size: 40, weight: .bold))
                Text("Watch your favourite channels live.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

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
            .padding(.vertical, 14)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var signOutButton: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)

            Divider()
                .frame(height: 20)

            Button("Sign Out") {
                confirmsSignOut = true
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: Capsule())
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch liveTV.phase {
        case .idle, .loading:
            statusRow(
                title: "Loading channels",
                message: "Large playlists can take a moment.",
                showsSpinner: true,
                retry: nil
            )

        case .failed(let message):
            statusRow(
                title: "Couldn't load channels",
                message: message,
                showsSpinner: false,
                retry: {
                    Task { await liveTV.reload(account: account) }
                }
            )

        case .loaded:
            if filteredGroups.isEmpty {
                statusRow(
                    title: search.isEmpty ? "No channels" : "No matches",
                    message: search.isEmpty
                        ? "This service returned no live channels."
                        : "Nothing found for “\(search)”.",
                    showsSpinner: false,
                    retry: nil
                )
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
                        HStack {
                            Text(group.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(group.channelCountLabel)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .textCase(nil)
                    }
                }
            }
        }
    }

    private func statusRow(
        title: String,
        message: String,
        showsSpinner: Bool,
        retry: (() -> Void)?
    ) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    if showsSpinner {
                        ProgressView()
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
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

    private var filteredGroups: [ChannelGroup] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return liveTV.groups }

        return liveTV.groups.compactMap { group in
            let hits = group.channels.filter { $0.name.localizedCaseInsensitiveContains(query) }
            guard !hits.isEmpty else { return nil }
            return ChannelGroup(id: group.id, title: group.title, channels: hits)
        }
    }
}
