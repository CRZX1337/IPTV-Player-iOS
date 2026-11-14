//
//  PlayerScreen.swift
//  IPTV-Player
//

import AVFoundation
import AVKit
import Combine
import SwiftUI

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

    func start() {
        player.play()
    }

    func stop() {
        player.pause()
    }
}

/// Full screen playback with the system player controls.
struct PlayerScreen: View {
    let channel: Channel

    @Environment(\.dismiss) private var dismiss
    @StateObject private var session: PlaybackSession
    @State private var failureMessage: String?

    init(channel: Channel) {
        self.channel = channel
        _session = StateObject(wrappedValue: PlaybackSession(url: channel.streamURL))
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

                    Text(channel.name)
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
            session.start()
        }
        .onDisappear {
            session.stop()
        }
        .onReceive(session.item.publisher(for: \.status).removeDuplicates()) { status in
            switch status {
            case .failed:
                failureMessage = session.item.error?.localizedDescription
                    ?? "This channel can't be played right now."
            case .readyToPlay:
                failureMessage = nil
            default:
                break
            }
        }
    }
}
