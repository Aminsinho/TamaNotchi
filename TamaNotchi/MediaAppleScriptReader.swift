import AppKit
import Foundation

/// Spotify y Music exponen estado y metadatos vía Apple Events (entitlement `com.apple.security.automation.apple-events`).
enum MediaAppleScriptReader {
    private static let recordSeparator = "\u{001E}"

    /// `TAMANOTCHI_MEDIA_DEBUG=1`: una línea por cambio de estado (no spam cada poll).
    /// `TAMANOTCHI_MEDIA_DEBUG_SCRIPT=1`: además, vuelca el script numerado en cada petición (muy ruidoso).
    private static var verboseDebug: Bool {
        ProcessInfo.processInfo.environment["TAMANOTCHI_MEDIA_DEBUG"] == "1"
    }

    private static var verboseDumpScriptEveryPoll: Bool {
        ProcessInfo.processInfo.environment["TAMANOTCHI_MEDIA_DEBUG_SCRIPT"] == "1"
    }

    private static var lastVerboseSummaryKey: String?

    private static var spotifyRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.spotify.client" }
    }

    private static var musicRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.apple.Music" }
    }

    struct MediaScriptSnapshot {
        var line: String?
        var isPlaying: Bool
    }

    /// Prioriza Spotify, luego Music.
    static func fetchFromSpotifyOrMusic() -> MediaScriptSnapshot? {
        if spotifyRunning, let s = fetchSpotify() { return s }
        if musicRunning, let s = fetchMusic() { return s }
        return nil
    }

    private static func fetchSpotify() -> MediaScriptSnapshot? {
        let lines: [String] = [
            "tell application \"Spotify\"",
            "    if not running then return \"\"",
            "    set recSep to ASCII character 30",
            "    set playerState to player state as string",
            "    set artistName to \"\"",
            "    set trackName to \"\"",
            "    try",
            "        set artistName to artist of current track",
            "        set trackName to name of current track",
            "    end try",
            "    return (playerState & recSep & artistName & recSep & trackName)",
            "end tell",
        ]
        return runAppleScript(lines.joined(separator: "\n"), label: "Spotify")
    }

    private static func fetchMusic() -> MediaScriptSnapshot? {
        let lines: [String] = [
            "tell application \"Music\"",
            "    if not running then return \"\"",
            "    set recSep to ASCII character 30",
            "    set playerState to player state as string",
            "    set artistName to \"\"",
            "    set trackName to \"\"",
            "    try",
            "        set artistName to artist of current track",
            "        set trackName to name of current track",
            "    end try",
            "    return (playerState & recSep & artistName & recSep & trackName)",
            "end tell",
        ]
        return runAppleScript(lines.joined(separator: "\n"), label: "Music")
    }

    private static func runAppleScript(_ source: String, label: String) -> MediaScriptSnapshot? {
        let numbered = source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .map { String(format: "%2d | %@", $0.offset + 1, String($0.element)) }
            .joined(separator: "\n")

        if verboseDumpScriptEveryPoll {
            print("[TamaNotchi] MediaAppleScriptReader (\(label)) script:\n\(numbered)\n")
        }

        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            print("[TamaNotchi] MediaAppleScriptReader (\(label)): no se pudo crear NSAppleScript.")
            print(numbered)
            return nil
        }

        let result = script.executeAndReturnError(&error)

        guard let raw = result.stringValue, !raw.isEmpty else {
            logAppleScriptFailure(label: label, source: source, numberedSource: numbered, error: error)
            return nil
        }

        let parts = raw.components(separatedBy: recordSeparator)
        guard parts.count >= 3 else {
            print("[TamaNotchi] MediaAppleScriptReader (\(label)): respuesta inesperada (partes=\(parts.count)): \(raw.debugDescription)")
            return nil
        }

        let stateRaw = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let artist = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let title = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)

        let isPlaying = stateRaw == "playing"

        let line: String?
        if !title.isEmpty {
            line = artist.isEmpty ? title : "\(artist) — \(title)"
        } else {
            line = nil
        }

        if verboseDebug {
            let key = "\(label)|\(line ?? "")|\(isPlaying)"
            if key != lastVerboseSummaryKey {
                lastVerboseSummaryKey = key
                print("[TamaNotchi] MediaAppleScriptReader (\(label)) OK playing=\(isPlaying) line=\(line ?? "nil")")
            }
        }

        return MediaScriptSnapshot(line: line, isPlaying: isPlaying)
    }

    private static func logAppleScriptFailure(label: String, source: String, numberedSource: String, error: NSDictionary?) {
        print("[TamaNotchi] MediaAppleScriptReader (\(label)): falló executeAndReturnError.")
        print("[TamaNotchi] --- script numerado ---\n\(numberedSource)\n[TamaNotchi] --- fin script ---")

        guard let err = error else {
            print("[TamaNotchi] error NSDictionary = nil (sin detalle).")
            return
        }

        let message = err[NSAppleScript.errorMessage] as? String ?? "(sin NSAppleScript.errorMessage)"
        let brief = err[NSAppleScript.errorBriefMessage] as? String
        let number = err[NSAppleScript.errorNumber] as? NSNumber
        let appName = err[NSAppleScript.errorAppName] as? String
        print("[TamaNotchi] AppleScript errorMessage: \(message)")
        if let brief { print("[TamaNotchi] AppleScript errorBriefMessage: \(brief)") }
        if let number { print("[TamaNotchi] AppleScript errorNumber: \(number)") }
        if let appName { print("[TamaNotchi] AppleScript errorAppName: \(appName)") }

        if let rangeVal = err[NSAppleScript.errorRange] as? NSValue {
            let r = rangeVal.rangeValue
            print("[TamaNotchi] AppleScript errorRange: location=\(r.location) length=\(r.length)")
            if r.location != NSNotFound, r.length > 0 {
                let u = sourceSnippet(source: source, range: r)
                if !u.isEmpty {
                    print("[TamaNotchi] Trozo del script en el fallo: \(u.debugDescription)")
                }
            }
        }

        print("[TamaNotchi] error dict keys: \(err.allKeys.map { String(describing: $0) }.joined(separator: ", "))")
    }

    /// Rango en unidades UTF-16 (como `NSString`); coincide con lo que suele devolver AppleScript.
    private static func sourceSnippet(source: String, range: NSRange) -> String {
        let ns = source as NSString
        guard range.location != NSNotFound, range.length > 0,
              range.location + range.length <= ns.length else { return "" }
        return ns.substring(with: range)
    }
}
