import AppKit

/// Ventana sin marco que sí puede ser key (evita el warning de `makeKeyWindow` y permite popovers/popup).
final class NotchKeyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
