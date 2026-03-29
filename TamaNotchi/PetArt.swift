import AppKit
import SwiftUI

private extension Bundle {
    /// Recursos del target cuando se compila con SwiftPM (p. ej. `swift run`).
    static var tamaNotchiResources: Bundle {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle.main
        #endif
    }
}

/// Carga sprites desde el catálogo de assets (Xcode) o desde archivos empaquetados (SwiftPM `resources`).
enum PetArt {
    static func image(named name: String) -> Image {
        if let image = NSImage(named: name) {
            return Image(nsImage: image)
        }

        for bundle in [Bundle.main, Bundle.tamaNotchiResources] {
            if let url = bundle.url(forResource: name, withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                return Image(nsImage: image)
            }
        }

        return Image(systemName: "hare.fill")
    }

    static func gifURL(named name: String) -> URL? {
        for bundle in [Bundle.main, Bundle.tamaNotchiResources] {
            if let url = bundle.url(forResource: name, withExtension: "gif") {
                return url
            }
        }
        return nil
    }
}
