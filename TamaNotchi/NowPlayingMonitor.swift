import Combine
import Foundation
import MediaPlayer

/// Detecta reproducción vía MediaPlayer + AppleScript (Music/Spotify) + notificaciones distribuidas.
final class NowPlayingMonitor: ObservableObject {
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var trackTitle: String?

    private var observers: [Any] = []
    private var poll: AnyCancellable?

    init() {
        registerDistributedObservers()
        poll = Timer.publish(every: 0.85, tolerance: 0.2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshAll()
            }
        refreshAll()
    }

    deinit {
        for o in observers {
            DistributedNotificationCenter.default().removeObserver(o)
        }
    }

    func refreshFromMediaPlayer() {
        refreshAll()
    }

    func refreshAll() {
        let center = MPNowPlayingInfoCenter.default()
        if let title = center.nowPlayingInfo?[MPMediaItemPropertyTitle] as? String {
            trackTitle = title
        }

        let mpPlaying = center.playbackState == .playing

        let musicState = AppleScriptMediaProbe.musicPlayerStateNormalized()?.lowercased()
        let spotifyState = AppleScriptMediaProbe.spotifyPlayerStateNormalized()?.lowercased()

        if musicState == "playing" {
            trackTitle = AppleScriptMediaProbe.musicTrackTitle() ?? trackTitle
        } else if spotifyState == "playing" {
            trackTitle = AppleScriptMediaProbe.spotifyTrackTitle() ?? trackTitle
        }

        let scriptPlaying = (musicState == "playing") || (spotifyState == "playing")
        let playing = mpPlaying || scriptPlaying

        if isPlaying != playing {
            isPlaying = playing
        }
    }

    private func registerDistributedObservers() {
        let names: [Notification.Name] = [
            Notification.Name("com.apple.Music.playerInfo"),
            Notification.Name("com.apple.iTunes.playerInfo"),
            Notification.Name("com.spotify.client.PlaybackStateChanged"),
        ]

        for name in names {
            let token = DistributedNotificationCenter.default().addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] note in
                self?.handleDistributedNotification(note)
            }
            observers.append(token)
        }
    }

    private func handleDistributedNotification(_ note: Notification) {
        guard let info = note.userInfo else { return }

        if let title = info[MPMediaItemPropertyTitle] as? String ?? info["Name"] as? String {
            trackTitle = title
        }

        let stateStrings: [String] = [
            info["Player State"] as? String,
            info["playerState"] as? String,
            info["state"] as? String,
        ].compactMap { $0 }

        for raw in stateStrings {
            let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            switch s {
            case "playing":
                if !isPlaying { isPlaying = true }
                return
            case "paused", "stopped", "stopped unexpectedly":
                if isPlaying { isPlaying = false }
                return
            default:
                continue
            }
        }

        for (_, value) in info {
            guard let text = value as? String else { continue }
            let s = text.lowercased()
            if s == "playing" {
                if !isPlaying { isPlaying = true }
                return
            }
            if s == "paused" || s == "stopped" {
                if isPlaying { isPlaying = false }
                return
            }
        }
    }
}
