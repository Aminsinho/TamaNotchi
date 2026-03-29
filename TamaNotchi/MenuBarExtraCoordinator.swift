import AppKit

/// NSStatusItem: menú con mostrar/ocultar panel, ajustes y salir.
final class MenuBarExtraCoordinator: NSObject {
    var onTogglePetPanel: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    var onQuit: () -> Void = {}

    private var statusItem: NSStatusItem?

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = PixelCatTemplateIcon.make()
        item.button?.imageScaling = .scaleProportionallyDown
        item.button?.toolTip = "TamaNotchi"

        let menu = NSMenu()

        let toggle = NSMenuItem(
            title: "Mostrar/Ocultar Mascota",
            action: #selector(menuTogglePet),
            keyEquivalent: ""
        )
        toggle.target = self
        menu.addItem(toggle)

        menu.addItem(.separator())

        let settings = NSMenuItem(
            title: "Configuración",
            action: #selector(menuSettings),
            keyEquivalent: ","
        )
        settings.keyEquivalentModifierMask = [.command]
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Salir de TamaNotchi",
            action: #selector(menuQuit),
            keyEquivalent: "q"
        )
        quit.keyEquivalentModifierMask = [.command]
        quit.target = self
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
    }

    @objc private func menuTogglePet() {
        onTogglePetPanel()
    }

    @objc private func menuSettings() {
        onOpenSettings()
    }

    @objc private func menuQuit() {
        onQuit()
    }
}
