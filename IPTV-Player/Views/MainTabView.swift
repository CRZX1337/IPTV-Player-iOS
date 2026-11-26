//
//  MainTabView.swift
//  IPTV-Player
//

import SwiftUI

/// The shell with the Liquid Glass tab bar. Movies and Series only exist on Xtream accounts.
struct MainTabView: View {
    let account: Account

    @StateObject private var movies = MediaLibraryStore(kind: .movie)
    @StateObject private var series = MediaLibraryStore(kind: .series)

    var body: some View {
        TabView {
            LiveTVView(account: account)
                .tabItem { Label("Live TV", systemImage: "tv") }

            if account.kind == .xtream {
                MediaLibraryView(account: account, library: movies)
                    .tabItem { Label("Movies", systemImage: "film") }

                MediaLibraryView(account: account, library: series)
                    .tabItem { Label("Series", systemImage: "rectangle.stack") }
            }

            SettingsView(account: account)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}
