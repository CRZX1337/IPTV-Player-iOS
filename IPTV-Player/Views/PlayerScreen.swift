//
//  PlayerScreen.swift
//  IPTV-Player
//

import AVFoundation
import AVKit
import Combine
import SwiftUI

/// What the player should open: a live channel, a movie or an episode.
struct PlayerRequest: Identifiable {
    let id = UUID()
    let title: String
    let url: URL
    /// When set, the position is remembered under this key.
    var progressKey: String?
    var startPosition: Double = 0
}

@MainActor
final class PlaybackSession: ObservableObject {
    let item: AVPlayerItem
    let player: AVPlayer

    init(url: URL) {
        item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 4

        player = AVPlayer(playerItem: item)
        player.allowsExternalPlayback = true
        player.preventsDisplaySleepDuringVideoPlayback = true
    }

    var currentPosition: Double {
        player.currentTime().seconds
    }

    var duration: Double {
        item.duration.seconds
    }

    func start(at seconds: Double) {
        if seconds > 0 {
            player.seek(
                to: CMTime(seconds: seconds, preferredTimescale: 600),
                toleranceBefore: .zero,
                toleranceAfter: .zero
            )
        }
        player.play()
    }

    func stop() {
        player.pause()
    }
}

/// Full screen playback with the system player controls.
struct PlayerScreen: View {
    let request: PlayerRequest

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var progress: ProgressStore
    @StateObject private var session: PlaybackSession
    @State private var failureMessage: String?

    private let ticker = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    init(request: PlayerRequest) {
        self.request = request
        _session = StateObject(wrappedValue: PlaybackSession(url: request.url))
    }

    init(channel: Channel) {
        self.init(request: PlayerRequest(title: channel.name, url: channel.streamURL))
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VideoPlayer(player: session.player)
                .ignoresSafeArea()

            VStack {
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .glassEffect(.regular, in: Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(request.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .glassEffect(.regular, in: Capsule())
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Spacer()
            }

            if let failureMessage {
                VStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.yellow)

                    Text(failureMessage)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)

                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.blue)
                }
                .padding(24)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .padding(32)
            }
        }
        .statusBarHidden(true)
        .onAppear {
            let audioSession = AVAudioSession.sharedInstance()
            try? audioSession.setCategory(.playback, mode: .moviePlayback)
            try? audioSession.setActive(true)
            session.start(at: request.startPosition)
        }
        .onDisappear {
            saveProgress()
            session.stop()
        }
        .onReceive(ticker) { _ in
            saveProgress()
        }
        .onReceive(session.item.publisher(for: \.status).removeDuplicates()) { status in
            switch status {
            case .failed:
                failureMessage = failureText
            case .readyToPlay:
                failureMessage = nil
            default:
                break
            }
        }
    }

    // MARK: - Helpers

    private func saveProgress() {
        guard let key = request.progressKey else { return }
        progress.save(key: key, position: session.currentPosition, duration: session.duration)
    }

    private var failureText: String {
        let fileExtension = request.url.pathExtension.lowercased()
        if ["mkv", "avi", "wmv", "flv"].contains(fileExtension) {
            return "The native player can't play .\(fileExtension) files."
        }
        return session.item.error?.localizedDescription ?? "This stream can't be played right now."
    }
}
