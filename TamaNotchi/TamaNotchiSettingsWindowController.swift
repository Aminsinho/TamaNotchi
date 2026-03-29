import AppKit
import SwiftUI

/// Ventana de ajustes mínima (placeholder hasta conectar preferencias reales).
final class TamaNotchiSettingsWindowController {
    private var window: NSWindow?

    func show(skinStore: PetSkinStore) {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let root = SettingsRootView().environmentObject(skinStore)
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
    @EnvironmentObject private var skinStore: PetSkinStore

    var body: some View {
        Form {
            Section {
                Picker(
                    "Apariencia de la mascota",
                    selection: Binding(
                        get: { skinStore.selectedSkinId },
                        set: { skinStore.selectSkin(id: $0) }
                    )
                ) {
                    ForEach(PetSkinDefinition.builtIn) { skin in
                        Text(skin.displayName).tag(skin.id)
                    }
                }

                Text("Para nuevos skins: enlaza PNG/GIF en BundleResources y añade una fila en PetSkinDefinition.builtIn.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Mascota")
            }

            Section {
                Text("Más opciones próximamente.")
                    .foregroundStyle(.secondary)
            } header: {
                Text("General")
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 360, minHeight: 240)
    }
}
