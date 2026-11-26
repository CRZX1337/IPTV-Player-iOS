//
//  PlayerScreen.swift
//  IPTV-Player
//

import AVFoundation
import AVKit
import SwiftUI
import UIKit

/// What the player should open for a movie or an episode.
struct PlayerRequest: Identifiable {
    let id = UUID()
    let title: String
    let url: URL
    /// Other addresses to try when the player cannot open the first one.
    var fallbackURLs: [URL] = []
    /// When set, the position is remembered under this key.
    var progressKey: String?
    var startPosition: Double = 0
}

/// The channels of one category and the one to start with, for the live player.
struct LivePlayback: Identifiable {
    let id = UUID()
    var channels: [Channel]
    var startIndex: Int
    var categoryTitle: String?
}

// MARK: - Playback

@MainActor
final class PlaybackSession: ObservableObject {
    let player = AVPlayer()

    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = false
    @Published private(set) var failureMessage: String?
    /// Played position and total length, for the timeline of movies and episodes.
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published var volume: Double = 1 {
        didSet { player.volume = Float(volume) }
    }

    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var timeObserver: Any?
    private var currentURL: URL?
    private var candidates: [URL] = []
    private var candidateIndex = 0

    init(url: URL, fallbackURLs: [URL] = []) {
        player.allowsExternalPlayback = true
        player.preventsDisplaySleepDuringVideoPlayback = true
        player.volume = 1
        observePlayer()
        candidates = [url] + fallbackURLs
        loadCurrentCandidate()
    }

    var currentPosition: Double {
        let seconds = player.currentTime().seconds
        return seconds.isFinite ? seconds : 0
    }

    /// Jumps to a position, used by the timeline while scrubbing.
    func seek(to seconds: Double) {
        guard seconds.isFinite else { return }
        let target = duration > 0 ? max(0, min(seconds, duration)) : max(0, seconds)
        player.seek(
            to: CMTime(seconds: target, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        currentTime = target
    }

    func load(url: URL) {
        candidates = [url]
        candidateIndex = 0
        loadCurrentCandidate()
    }

    private func loadCurrentCandidate() {
        guard candidates.indices.contains(candidateIndex) else { return }

        let url = candidates[candidateIndex]
        currentURL = url
        failureMessage = nil
        isPlaying = false
        isBuffering = true
        currentTime = 0
        duration = 0

        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 4
        player.replaceCurrentItem(with: item)
        observe(item)
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

    func togglePlayPause() {
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }

    func skip(by seconds: Double) {
        let target = max(0, currentPosition + seconds)
        player.seek(
            to: CMTime(seconds: target, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    func retry() {
        guard let currentURL else { return }
        load(url: currentURL)
        player.play()
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    // MARK: Observation

    private func observePlayer() {
        timeControlObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            let status = player.timeControlStatus
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isPlaying = status == .playing
                self.isBuffering = status == .waitingToPlayAtSpecifiedRate
            }
        }
        startTimeObserver()
    }

    private func startTimeObserver() {
        guard timeObserver == nil else { return }

        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }

                let seconds = time.seconds
                if seconds.isFinite {
                    self.currentTime = seconds
                }

                let total = self.player.currentItem?.duration.seconds ?? 0
                if total.isFinite, total > 0 {
                    self.duration = total
                }
            }
        }
    }

    private func observe(_ item: AVPlayerItem) {
        let identity = ObjectIdentifier(item)

        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            let status = item.status
            let message = item.error?.localizedDescription
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Ignore a stale item after a channel switch or a fallback.
                guard self.player.currentItem.map(ObjectIdentifier.init) == identity else { return }

                switch status {
                case .failed:
                    if self.candidateIndex + 1 < self.candidates.count {
                        self.candidateIndex += 1
                        self.loadCurrentCandidate()
                        self.player.play()
                        return
                    }
                    self.failureMessage = Self.failureText(for: self.candidates.first, error: message)
                    self.isBuffering = false
                case .readyToPlay:
                    self.failureMessage = nil
                    let total = self.player.currentItem?.duration.seconds ?? 0
                    if total.isFinite, total > 0 {
                        self.duration = total
                    }
                default:
                    break
                }
            }
        }
    }

    private static func failureText(for url: URL?, error message: String?) -> String {
        let fileExtension = url?.pathExtension.lowercased() ?? ""
        if ["mkv", "avi", "wmv", "flv"].contains(fileExtension) {
            return "This title is delivered as .\(fileExtension). The built-in player cannot open that format, and its MP4 and HLS variants did not work either."
        }
        return message ?? "This stream can't be played right now."
    }
}

// MARK: - Picture in picture

@MainActor
final class PiPController: ObservableObject {
    @Published private(set) var isPossible = false
    @Published private(set) var isActive = false

    private var controller: AVPictureInPictureController?
    private var possibleObservation: NSKeyValueObservation?
    private var activeObservation: NSKeyValueObservation?

    func attach(to layer: AVPlayerLayer) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
        guard controller?.playerLayer !== layer else { return }

        let controller = AVPictureInPictureController(playerLayer: layer)
        self.controller = controller

        possibleObservation = controller?.observe(\.isPictureInPicturePossible, options: [.new]) { [weak self] controller, _ in
            let possible = controller.isPictureInPicturePossible
            Task { @MainActor [weak self] in
                self?.isPossible = possible
            }
        }

        activeObservation = controller?.observe(\.isPictureInPictureActive, options: [.new]) { [weak self] controller, _ in
            let active = controller.isPictureInPictureActive
            Task { @MainActor [weak self] in
                self?.isActive = active
            }
        }
    }

    func toggle() {
        guard let controller else { return }
        if controller.isPictureInPictureActive {
            controller.stopPictureInPicture()
        } else {
            controller.startPictureInPicture()
        }
    }
}

/// The video surface itself, so picture in picture has a player layer to work with.
struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    let pip: PiPController

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.player = player
        pip.attach(to: view.playerLayer)
        return view
    }

    func updateUIView(_ view: PlayerContainerView, context: Context) {
        guard view.playerLayer.player !== player else { return }
        view.playerLayer.player = player
        pip.attach(to: view.playerLayer)
    }
}

final class PlayerContainerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        playerLayer.videoGravity = .resizeAspect
        backgroundColor = .black
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        playerLayer.videoGravity = .resizeAspect
        backgroundColor = .black
    }
}

/// The system AirPlay picker, drawn as a plain glyph so the glass circle around it shows.
struct AirPlayRouteButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.tintColor = .white
        view.activeTintColor = .white
        view.prioritizesVideoDevices = true
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: AVRoutePickerView, context: Context) {}
}

// MARK: - Player screen

/// Full screen playback with glass controls, for a live channel or a movie.
struct PlayerScreen: View {
    private let live: LivePlayback?
    private let request: PlayerRequest?
    private let onWatch: (Channel) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var progress: ProgressStore

    @StateObject private var session: PlaybackSession
    @StateObject private var pip = PiPController()

    @State private var index: Int
    @State private var controlsVisible = true
    @State private var bannerChannel: Channel?
    @State private var bannerTask: Task<Void, Never>?
    @State private var scrubFraction: Double?

    private let ticker = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    init(live: LivePlayback, onWatch: @escaping (Channel) -> Void = { _ in }) {
        let start = live.channels.isEmpty ? 0 : min(max(live.startIndex, 0), live.channels.count - 1)
        let first = live.channels.indices.contains(start) ? live.channels[start] : nil

        self.live = live
        self.request = nil
        self.onWatch = onWatch
        _index = State(initialValue: start)
        _session = StateObject(wrappedValue: PlaybackSession(url: first?.streamURL ?? URL(fileURLWithPath: "/dev/null")))
    }

    init(request: PlayerRequest) {
        self.live = nil
        self.request = request
        self.onWatch = { _ in }
        _index = State(initialValue: 0)
        _session = StateObject(wrappedValue: PlaybackSession(url: request.url, fallbackURLs: request.fallbackURLs))
    }

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height

            stage(isLandscape: isLandscape, size: proxy.size)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .statusBarHidden(isLandscape)
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            let audioSession = AVAudioSession.sharedInstance()
            try? audioSession.setCategory(.playback, mode: .moviePlayback)
            try? audioSession.setActive(true)
            session.start(at: request?.startPosition ?? 0)
            updateIdleTimer()
        }
        .onDisappear {
            saveProgress()
            bannerTask?.cancel()
            session.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: session.isPlaying) { updateIdleTimer() }
        .onChange(of: session.isBuffering) { updateIdleTimer() }
        .onReceive(ticker) { _ in
            saveProgress()
        }
    }

    /// The screen must stay lit while something plays or loads, dimming only when the user pauses.
    private func updateIdleTimer() {
        if session.failureMessage != nil {
            UIApplication.shared.isIdleTimerDisabled = false
        } else {
            UIApplication.shared.isIdleTimerDisabled = session.isPlaying || session.isBuffering
        }
    }

    // MARK: - Layout

    @ViewBuilder
    private func stage(isLandscape: Bool, size: CGSize) -> some View {
        if isLandscape || live == nil {
            fullScreenStage
        } else {
            portraitStage(height: max(size.height * 0.5, 280))
        }
    }

    /// Landscape and movies: the video fills the screen and the glass bars float on it.
    private var fullScreenStage: some View {
        ZStack {
            Color.black

            PlayerLayerView(player: session.player, pip: pip)
                .ignoresSafeArea()

            chromeOverlay
        }
        .overlay(alignment: .leading) { channelBanner }
        .overlay { bufferingIndicator }
        .overlay { failureOverlay }
        .contentShape(Rectangle())
        .onTapGesture { toggleControls() }
        .gesture(channelSwipe)
    }

    /// Portrait live TV: the video on top, the channels of the category underneath.
    private func portraitStage(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Color.black

                PlayerLayerView(player: session.player, pip: pip)

                chromeOverlay
            }
            .frame(height: height)
            .overlay(alignment: .leading) { channelBanner }
            .overlay { bufferingIndicator }
            .overlay { failureOverlay }
            .contentShape(Rectangle())
            .onTapGesture { toggleControls() }
            .gesture(channelSwipe)

            channelList
        }
    }

    // MARK: - Chrome

    private var chromeOverlay: some View {
        GlassEffectContainer(spacing: 18) {
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                Spacer(minLength: 12)

                controlCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            }
            .opacity(controlsVisible ? 1 : 0)
            .allowsHitTesting(controlsVisible)
            .animation(.easeInOut(duration: 0.22), value: controlsVisible)
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")

            Rectangle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 1, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(primaryTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            AirPlayRouteButton()
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.white.opacity(0.12)))
                .clipShape(Circle())
                .accessibilityLabel("AirPlay")

            pipButton
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var pipButton: some View {
        Button {
            pip.toggle()
        } label: {
            Image(systemName: pip.isActive ? "pip.exit" : "pip.enter")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(pip.isPossible || pip.isActive ? Color.white : Color.white.opacity(0.35))
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .disabled(!pip.isPossible && !pip.isActive)
        .accessibilityLabel(pip.isActive ? "Exit Picture in Picture" : "Picture in Picture")
    }

    private var controlCard: some View {
        VStack(spacing: 14) {
            if live == nil {
                timeline
            }

            HStack(spacing: 18) {
                Spacer(minLength: 0)

                Button {
                    session.skip(by: -10)
                } label: {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back 10 seconds")

                Button {
                    session.togglePlayPause()
                } label: {
                    Image(systemName: session.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 62, height: 62)
                        .background(Circle().fill(Color.blue.opacity(0.9)))
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(session.isPlaying ? "Pause" : "Play")

                Button {
                    session.skip(by: 10)
                } label: {
                    Image(systemName: "goforward.10")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Forward 10 seconds")

                Spacer(minLength: 0)

                if live != nil {
                    livePill
                }
            }

            HStack(spacing: 12) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))

                Slider(value: $session.volume, in: 0...1)
                    .tint(.blue)
                    .accessibilityLabel("Volume")

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    /// The scrubber for movies and episodes; a live stream has no fixed length.
    private var timeline: some View {
        let total = session.duration
        let played = scrubFraction.map { $0 * max(total, 0) } ?? session.currentTime
        let fraction: Double = total > 0 ? min(max(played / total, 0), 1) : 0

        return VStack(spacing: 4) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let knob: CGFloat = scrubFraction == nil ? 13 : 18

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.22))
                        .frame(height: 5)

                    Capsule()
                        .fill(Color.blue)
                        .frame(width: max(width * fraction, 0), height: 5)

                    Circle()
                        .fill(Color.white)
                        .frame(width: knob, height: knob)
                        .shadow(color: .black.opacity(0.4), radius: 4, y: 1)
                        .offset(x: max(min(width * fraction - knob / 2, width - knob), 0))
                        .animation(.easeOut(duration: 0.12), value: scrubFraction == nil)
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(scrubGesture(width: width))
            }
            .frame(height: 24)

            HStack {
                Text(Self.timeText(played))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(scrubFraction == nil ? 0.85 : 1))

                Spacer()

                Text(total > 0 ? Self.timeText(total) : "--:--")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Playback position")
        .accessibilityValue("\(Self.timeText(played)) of \(Self.timeText(total))")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                session.seek(to: session.currentTime + 15)
            case .decrement:
                session.seek(to: session.currentTime - 15)
            @unknown default:
                break
            }
        }
    }

    private func scrubGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard session.duration > 0 else { return }
                scrubFraction = min(max(value.location.x / max(width, 1), 0), 1)
            }
            .onEnded { value in
                guard session.duration > 0 else {
                    scrubFraction = nil
                    return
                }
                let fraction = min(max(value.location.x / max(width, 1), 0), 1)
                session.seek(to: fraction * session.duration)
                scrubFraction = nil
            }
    }

    private static func timeText(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }

        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    private var livePill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)

            Text("Live")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.white.opacity(0.12)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Live")
    }

    // MARK: - Channel banner

    @ViewBuilder
    private var channelBanner: some View {
        if let channel = bannerChannel {
            HStack(spacing: 12) {
                ChannelArtwork(channel: channel, cornerRadius: 12)
                    .frame(width: 58)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text(channel.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(.leading, 20)
            .padding(.bottom, 90)
            .allowsHitTesting(false)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    // MARK: - States

    @ViewBuilder
    private var bufferingIndicator: some View {
        if session.isBuffering && session.failureMessage == nil {
            ProgressView()
                .controlSize(.large)
                .tint(.white)
                .padding(20)
                .glassEffect(.regular, in: Circle())
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var failureOverlay: some View {
        if let message = session.failureMessage {
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.yellow)

                Text(message)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)

                HStack(spacing: 12) {
                    Button("Try Again") {
                        session.retry()
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.blue)

                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(.glass)
                }
            }
            .padding(24)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .padding(32)
        }
    }

    // MARK: - Channel list

    private var channelList: some View {
        List {
            ForEach(Array(channels.indices), id: \.self) { position in
                let channel = channels[position]

                Button {
                    select(position)
                } label: {
                    HStack(spacing: 12) {
                        ChannelArtwork(channel: channel, cornerRadius: 12)
                            .frame(width: 72)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(channel.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            ChannelLiveLine(category: live?.categoryTitle)
                        }

                        Spacer(minLength: 8)

                        if position == index {
                            Image(systemName: "waveform")
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(position == index ? Color.blue.opacity(0.20) : Color.white.opacity(0.06))
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Helpers

    private var channels: [Channel] {
        live?.channels ?? []
    }

    private var primaryTitle: String {
        if let request { return request.title }
        return channels.indices.contains(index) ? channels[index].name : "Live TV"
    }

    private var subtitle: String? {
        guard live != nil else { return nil }
        return live?.categoryTitle
    }

    private var channelSwipe: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                guard live != nil else { return }
                let vertical = value.translation.height
                guard abs(vertical) > abs(value.translation.width), abs(vertical) > 40 else { return }
                switchChannel(by: vertical < 0 ? 1 : -1)
            }
    }

    private func select(_ position: Int) {
        guard channels.indices.contains(position) else { return }

        index = position
        let channel = channels[position]
        session.load(url: channel.streamURL)
        session.start(at: 0)
        onWatch(channel)
        showBanner(channel)
    }

    private func switchChannel(by delta: Int) {
        let next = index + delta
        guard channels.indices.contains(next) else { return }
        select(next)
    }

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.22)) {
            controlsVisible.toggle()
        }
    }

    private func showBanner(_ channel: Channel) {
        bannerTask?.cancel()

        withAnimation(.snappy(duration: 0.25)) {
            bannerChannel = channel
        }

        bannerTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                bannerChannel = nil
            }
        }
    }

    private func saveProgress() {
        guard let key = request?.progressKey else { return }
        progress.save(key: key, position: session.currentPosition, duration: session.duration)
    }
}
