import Combine
import Foundation
import MediaPlayer

/// Refresco inmediato cuando Music / Spotify publican en el center distribuido (además del polling y Media Remote).
private final class DistributedPlaybackNotifier: NSObject {
    var onEvent: () -> Void = {}

    override init() {
        super.init()
        let center = DistributedNotificationCenter.default()
        for raw in [
            "com.spotify.client.PlaybackStateChanged",
            "com.apple.Music.playerInfo",
        ] {
            center.addObserver(
                self,
                selector: #selector(handleRemotePlaybackNotification(_:)),
                name: NSNotification.Name(raw),
                object: nil,
                suspensionBehavior: .deliverImmediately
            )
        }
    }

    @objc private func handleRemotePlaybackNotification(_ notification: Notification) {
        onEvent()
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }
}

/// Metadatos y estado del reproductor del sistema.
/// 1) AppleScript hacia Spotify / Music (fiable con sandbox + automatización).
/// 2) Media Remote (otras apps; puede fallar en sandbox).
/// 3) `MPNowPlayingInfoCenter` como respaldo inmediato.
final class NowPlayingMonitor: ObservableObject {
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var trackTitle: String?

    private var poll: AnyCancellable?
    private var refreshGeneration: UInt64 = 0
    private let distributedPlayback = DistributedPlaybackNotifier()

    init() {
        distributedPlayback.onEvent = { [weak self] in
            self?.refreshFromMediaPlayer()
        }

        poll = Timer.publish(every: 0.65, tolerance: 0.2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshFromMediaPlayer()
            }

        refreshFromMediaPlayer()
    }

    func refreshFromMediaPlayer() {
        refreshGeneration += 1
        let generation = refreshGeneration

        /// Un solo paso en main: evita que `MPNowPlayingInfoCenter` (casi siempre vacío con Spotify)
        /// pise la UI con "Sin música" un instante antes de que AppleScript restaure título y estado.
        DispatchQueue.main.async { [weak self] in
            guard let self, generation == self.refreshGeneration else { return }

            if let s = MediaAppleScriptReader.fetchFromSpotifyOrMusic() {
                self.applyScriptSnapshot(s)
                return
            }

            let centerSnapshot = Self.snapshotFromNowPlayingCenter()
            self.applySnapshot(centerSnapshot)

            MediaRemoteNowPlayingFetcher.fetchNowPlayingInfo { dict in
                DispatchQueue.main.async { [weak self] in
                    guard let self, generation == self.refreshGeneration else { return }

                    guard let d = dict as? [String: Any], !d.isEmpty else { return }

                    let parsed = Self.parseMediaRemoteDictionary(d)
                    if parsed.hasUsableMediaState {
                        self.applyParsedMediaRemote(parsed)
                    }
                }
            }
        }
    }

    func refreshAll() {
        refreshFromMediaPlayer()
    }

    // MARK: - Apply

    private func applySnapshot(_ s: MediaSnapshot) {
        if trackTitle != s.line {
            trackTitle = s.line
        }
        if isPlaying != s.isPlaying {
            isPlaying = s.isPlaying
        }
    }

    private func applyParsedMediaRemote(_ p: ParsedMediaRemote) {
        if trackTitle != p.line {
            trackTitle = p.line
        }
        if isPlaying != p.isPlaying {
            isPlaying = p.isPlaying
        }
    }

    private func applyScriptSnapshot(_ s: MediaAppleScriptReader.MediaScriptSnapshot) {
        if trackTitle != s.line {
            trackTitle = s.line
        }
        if isPlaying != s.isPlaying {
            isPlaying = s.isPlaying
        }
    }

    // MARK: - MPNowPlayingInfoCenter (respaldor / Music cuando publica aquí)

    private struct MediaSnapshot {
        var line: String?
        var isPlaying: Bool
    }

    private static func snapshotFromNowPlayingCenter() -> MediaSnapshot {
        let center = MPNowPlayingInfoCenter.default()
        let info = center.nowPlayingInfo ?? [:]
        let centerLine = titleLine(from: info)
        let rate = (info[MPNowPlayingInfoPropertyPlaybackRate] as? NSNumber)?.doubleValue
            ?? (info[MPNowPlayingInfoPropertyPlaybackRate] as? Double)
        let playingFromRate = (rate ?? 0) > 0.01
        let centerPlaying = playingFromRate || center.playbackState == .playing

        return MediaSnapshot(line: centerLine, isPlaying: centerPlaying)
    }

    private static func titleLine(from info: [String: Any]) -> String? {
        let title = (info[MPMediaItemPropertyTitle] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = (info[MPMediaItemPropertyArtist] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let t = title, !t.isEmpty {
            if let a = artist, !a.isEmpty {
                return "\(a) — \(t)"
            }
            return t
        }
        return nil
    }

    // MARK: - Media Remote

    private struct ParsedMediaRemote {
        var line: String?
        var isPlaying: Bool
        var hasUsableMediaState: Bool
    }

    private static func parseMediaRemoteDictionary(_ d: [String: Any]) -> ParsedMediaRemote {
        let title = firstString(in: d, keys: [
            "kMRMediaRemoteNowPlayingInfoTitle",
            "Title",
            "title",
        ])
        let artist = firstString(in: d, keys: [
            "kMRMediaRemoteNowPlayingInfoArtist",
            "Artist",
            "artist",
        ])

        let line: String?
        if let t = title, !t.isEmpty {
            if let a = artist, !a.isEmpty {
                line = "\(a) — \(t)"
            } else {
                line = t
            }
        } else {
            line = nil
        }

        let rate = firstDouble(in: d, keys: [
            "kMRMediaRemoteNowPlayingInfoPlaybackRate",
            "Playback Rate",
            "playbackRate",
        ]) ?? 0

        let isPlaying = rate > 0.01
        let hasUsableMediaState = (line != nil) || isPlaying

        return ParsedMediaRemote(line: line, isPlaying: isPlaying, hasUsableMediaState: hasUsableMediaState)
    }

    private static func firstString(in d: [String: Any], keys: [String]) -> String? {
        for k in keys {
            if let s = d[k] as? String {
                let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { return t }
            }
            if let s = d[k] as? NSString {
                let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { return t as String }
            }
        }
        return nil
    }

    private static func firstDouble(in d: [String: Any], keys: [String]) -> Double? {
        for k in keys {
            if let n = d[k] as? NSNumber {
                return n.doubleValue
            }
            if let n = d[k] as? Double {
                return n
            }
            if let n = d[k] as? Float {
                return Double(n)
            }
        }
        return nil
    }
}
