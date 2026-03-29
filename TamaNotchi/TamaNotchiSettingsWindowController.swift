import AppKit
import SwiftUI

/// Ventana de ajustes mínima (placeholder hasta conectar preferencias reales).
final class TamaNotchiSettingsWindowController {
    private var window: NSWindow?

    func show() {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let root = SettingsRootView()
        let host = NSHostingController(rootView: root)
        host.title = "TamaNotchi"

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 220),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        w.isReleasedWhenClosed = false
        w.title = "Configuración"
        w.contentViewController = host
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = w
    }
}

private struct SettingsRootView: View {
    var body: some View {
        Form {
            Section {
                Text("Preferencias próximamente.")
                    .foregroundStyle(.secondary)
            } header: {
                Text("TamaNotchi")
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 340, minHeight: 160)
    }
}
