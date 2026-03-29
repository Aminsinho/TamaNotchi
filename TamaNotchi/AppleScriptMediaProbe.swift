import Foundation

/// Consulta Music y Spotify vía AppleScript (funciona cuando la app no está en sandbox restrictivo).
enum AppleScriptMediaProbe {
    static func musicPlayerStateNormalized() -> String? {
        run(
            """
            tell application "Music"
                if it is running then return (player state as text)
            end tell
            """
        )
    }

    static func spotifyPlayerStateNormalized() -> String? {
        run(
            """
            tell application "Spotify"
                if it is running then return (player state as text)
            end tell
            """
        )
    }

    static func musicTrackTitle() -> String? {
        run(
            """
            tell application "Music"
                if it is running then return name of current track
            end tell
            """
        )
    }

    static func spotifyTrackTitle() -> String? {
        run(
            """
            tell application "Spotify"
                if it is running then return name of current track
            end tell
            """
        )
    }

    private static func run(_ source: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let out = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return out?.isEmpty == false ? out : nil
        } catch {
            return nil
        }
    }
}
