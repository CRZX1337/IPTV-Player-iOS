//
//  SettingsView.swift
//  IPTV-Player
//

import SwiftUI

struct SettingsView: View {
    let account: Account

    @EnvironmentObject private var accounts: AccountStore
    @EnvironmentObject private var liveTV: LiveTVStore
    @EnvironmentObject private var preferences: PreferencesStore

    @Environment(\.dismiss) private var dismiss
    @State private var confirmsSignOut = false

    var body: some View {
        NavigationStack {
            List {
                Section("Service") {
                    LabeledContent("Name", value: account.displayName)
                    LabeledContent("Type", value: account.kindDescription)
                    LabeledContent("Server") {
                        Text(account.server)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                    }
                    if !account.username.isEmpty {
                        LabeledContent("Username", value: account.username)
                    }
                }

                Section("Channels") {
                    NavigationLink {
                        CategoryListView(account: account)
                    } label: {
                        Label("Categories", systemImage: "square.grid.2x2")
                    }

                    LabeledContent {
                        Text("\(preferences.favouriteIDs(for: account).count)")
                    } label: {
                        Label("Favourite categories", systemImage: "star")
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Build", value: appBuild)
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        dismiss()
                        liveTV.reset()
                        accounts.signOut()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}
