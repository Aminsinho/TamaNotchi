import AppKit
import CoreGraphics

/// Teclas multimedia de hardware (Music, Spotify, etc.).
enum MediaHardwareKey {
    case playPause
    case nextTrack
    case previousTrack

    private var nxKeyCode: Int {
        switch self {
        case .playPause: return 16
        case .nextTrack: return 17
        case .previousTrack: return 18
        }
    }

    func send() {
        let key = nxKeyCode
        func post(down: Bool) {
            let flagBits = down ? 0xa00 : 0xb00
            let data1 = (key << 16) | flagBits
            guard
                let event = NSEvent.otherEvent(
                    with: .systemDefined,
                    location: .zero,
                    modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(flagBits)),
                    timestamp: 0,
                    windowNumber: 0,
                    context: nil,
                    subtype: 8,
                    data1: data1,
                    data2: -1
                ),
                let cg = event.cgEvent
            else { return }
            cg.post(tap: CGEventTapLocation.cghidEventTap)
        }
        post(down: true)
        post(down: false)
    }
}

enum MediaPlayPauseKey {
    static func send() {
        MediaHardwareKey.playPause.send()
    }
}
