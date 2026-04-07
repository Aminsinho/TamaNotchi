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

/// Carga sprites desde archivos empaquetados (SwiftPM `resources`).
///
/// Cuando se proporciona `folder`, busca dentro de esa subcarpeta de recursos
/// (p. ej. `BundleResources/Mitchy/pet_idle.png`). Los iconos compartidos se
/// cargan sin folder (raíz de `BundleResources`).
enum PetArt {

    /// Directorio raíz copiado por `.copy("BundleResources")` en Package.swift.
    private static let resourceRoot = "BundleResources"

    static func image(named name: String, in folder: String? = nil) -> Image {
        if folder == nil, let image = NSImage(named: name) {
            return Image(nsImage: image)
        }

        for bundle in [Bundle.main, Bundle.tamaNotchiResources] {
            if let url = resourceURL(in: bundle, name: name, ext: "png", folder: folder),
               let image = NSImage(contentsOf: url) {
                return Image(nsImage: image)
            }
        }

        return Image(systemName: "hare.fill")
    }

    static func gifURL(named name: String, in folder: String? = nil) -> URL? {
        for bundle in [Bundle.main, Bundle.tamaNotchiResources] {
            if let url = resourceURL(in: bundle, name: name, ext: "gif", folder: folder) {
                return url
            }
        }
        return nil
    }

    // MARK: - Private

    private static func resourceURL(
        in bundle: Bundle,
        name: String,
        ext: String,
        folder: String?
    ) -> URL? {
        let subdir: String
        if let folder {
            subdir = "\(resourceRoot)/\(folder)"
        } else {
            subdir = resourceRoot
        }
        if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: subdir) {
            return url
        }
        // Fallback: buscar sin subdirectorio (útil si los recursos se aplanararon con .process).
        if let folder {
            return bundle.url(forResource: name, withExtension: ext, subdirectory: folder)
        }
        return bundle.url(forResource: name, withExtension: ext)
    }
}
