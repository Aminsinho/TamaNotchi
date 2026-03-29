import AppKit

/// Arranque AppKit nativo: con SwiftUI `App` + solo `Settings`, en algunos entornos la ventana
/// creada en el delegado no llega a mostrarse al ejecutar `swift run`.
@main
enum TamaNotchiBootstrap {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
