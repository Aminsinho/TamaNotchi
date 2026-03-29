import Foundation
import MediaPlayer

/// `MPRemoteCommandCenter`: si el sistema entrega play/pause/salto a esta app, reenviamos teclas multimedia
/// (mismo comportamiento que los botones de la isla).
enum SystemMediaRemoteCommands {
    static func registerPlaybackEventsHandler(onCommandFired: @escaping () -> Void) {
        let commands = MPRemoteCommandCenter.shared()

        commands.playCommand.isEnabled = true
        commands.playCommand.addTarget { _ in
            MediaHardwareKey.playPause.send()
            DispatchQueue.main.async { onCommandFired() }
            return .success
        }

        commands.pauseCommand.isEnabled = true
        commands.pauseCommand.addTarget { _ in
            MediaHardwareKey.playPause.send()
            DispatchQueue.main.async { onCommandFired() }
            return .success
        }

        commands.togglePlayPauseCommand.isEnabled = true
        commands.togglePlayPauseCommand.addTarget { _ in
            MediaHardwareKey.playPause.send()
            DispatchQueue.main.async { onCommandFired() }
            return .success
        }

        commands.nextTrackCommand.isEnabled = true
        commands.nextTrackCommand.addTarget { _ in
            MediaHardwareKey.nextTrack.send()
            DispatchQueue.main.async { onCommandFired() }
            return .success
        }

        commands.previousTrackCommand.isEnabled = true
        commands.previousTrackCommand.addTarget { _ in
            MediaHardwareKey.previousTrack.send()
            DispatchQueue.main.async { onCommandFired() }
            return .success
        }
    }
}
