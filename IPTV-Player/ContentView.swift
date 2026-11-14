//
//  ContentView.swift
//  IPTV-Player
//

import SwiftUI

struct ContentView: View {
    @StateObject private var accounts = AccountStore()
    @StateObject private var liveTV = LiveTVStore()
    @StateObject private var preferences = PreferencesStore()

    var body: some View {
        ZStack {
            AppBackground()

            if let account = accounts.account {
                LiveTVView(account: account)
                    .transition(.opacity)
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .environmentObject(accounts)
        .environmentObject(liveTV)
        .environmentObject(preferences)
        .preferredColorScheme(.dark)
        .tint(.blue)
        .animation(.easeInOut(duration: 0.28), value: accounts.account)
    }
}

#Preview {
    ContentView()
}
