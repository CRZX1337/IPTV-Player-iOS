//
//  LoginView.swift
//  IPTV-Player
//

import SwiftUI

enum LoginMethod: String, CaseIterable, Hashable {
    case xtream
    case m3u

    var title: String {
        switch self {
        case .xtream: return "Xtream Codes"
        case .m3u: return "M3U URL"
        }
    }
}

struct LoginView: View {
    @EnvironmentObject private var accounts: AccountStore
    @EnvironmentObject private var liveTV: LiveTVStore

    @State private var method: LoginMethod = .xtream
    @State private var server = ""
    @State private var username = ""
    @State private var password = ""
    @State private var playlistAddress = ""
    @State private var isBusy = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Add Service")
                        .font(.system(size: 42, weight: .bold))
                    Text("Xtream Codes or M3U playlist.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                GlassSegmentedControl(
                    options: LoginMethod.allCases,
                    title: { $0.title },
                    selection: $method
                )

                card

                Text("Your login is stored securely in the Keychain.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) { signInBar }
        .animation(.easeInOut(duration: 0.22), value: method)
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
    }

    // MARK: - Pieces

    private var card: some View {
        VStack(spacing: 0) {
            switch method {
            case .xtream:
                FieldRow(
                    title: "Server",
                    text: $server,
                    placeholder: "http://server.com:8080",
                    keyboard: .URL,
                    contentType: .URL
                )
                separator
                FieldRow(
                    title: "Username",
                    text: $username,
                    placeholder: "Enter your username",
                    contentType: .username
                )
                separator
                FieldRow(
                    title: "Password",
                    text: $password,
                    placeholder: "Enter your password",
                    contentType: .password,
                    isSecure: true
                )
            case .m3u:
                FieldRow(
                    title: "Playlist URL",
                    text: $playlistAddress,
                    placeholder: "http://server.com/playlist.m3u",
                    keyboard: .URL,
                    contentType: .URL
                )
            }
        }
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(height: 1)
    }

    private var signInBar: some View {
        Button {
            Task { await submit() }
        } label: {
            Group {
                if isBusy {
                    ProgressView()
                } else {
                    Text("Sign In")
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
        }
        .buttonStyle(.glassProminent)
        .tint(.blue)
        .disabled(!canSubmit || isBusy)
        .opacity(canSubmit ? 1 : 0.55)
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }

    // MARK: - Actions

    private var canSubmit: Bool {
        switch method {
        case .xtream:
            return !server.trimmingCharacters(in: .whitespaces).isEmpty
                && !username.trimmingCharacters(in: .whitespaces).isEmpty
                && !password.isEmpty
        case .m3u:
            return !playlistAddress.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func submit() async {
        guard !isBusy else { return }
        errorMessage = nil
        isBusy = true
        defer { isBusy = false }

        do {
            switch method {
            case .xtream:
                let account = try await AccountResolver.xtream(
                    server: server,
                    username: username,
                    password: password
                )
                try accounts.signIn(account)
            case .m3u:
                let result = try await AccountResolver.playlist(urlString: playlistAddress)
                liveTV.prime(result.groups, for: result.account)
                try accounts.signIn(result.account)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ZStack {
        AppBackground()
        LoginView()
    }
    .environmentObject(AccountStore())
    .environmentObject(LiveTVStore())
    .preferredColorScheme(.dark)
}
