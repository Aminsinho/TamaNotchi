import AppKit
import Combine
import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Documentos que arrastras al gato: se copian al contenedor de la app y puedes extraerlos con un clic (panel de carpeta).
final class PetDocumentStash: ObservableObject {
    struct StashedFile: Identifiable, Equatable {
        let id: UUID
        let originalName: String
        let storedURL: URL
    }

    private struct ManifestEntry: Codable {
        let id: UUID
        let originalName: String
        let storedFileName: String
    }

    @Published private(set) var files: [StashedFile] = []

    var isEmpty: Bool { files.isEmpty }
    var count: Int { files.count }

    /// Evita apilar varios NSOpenPanel si el usuario pulsa el gato muchas veces seguidas.
    private var isRetrievePanelActive = false

    private var stashFolder: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("TamaNotchi", isDirectory: true)
            .appendingPathComponent("stash", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var manifestURL: URL {
        stashFolder.appendingPathComponent(".stash_manifest.json")
    }

    init() {
        let folder = stashFolder
        NSLog("[TamaNotchi][Stash] init stashFolder=%@", folder.path)
        loadManifest()
        NSLog("[TamaNotchi][Stash] init cargados count=%ld", files.count)
    }

    func ingest(url: URL) {
        guard url.isFileURL else {
            NSLog("[TamaNotchi][Stash] ingest omitido: no es file URL (%@)", url.absoluteString)
            return
        }
        NSLog("[TamaNotchi][Stash] ingest origen=%@", url.path)
        let accessing = url.startAccessingSecurityScopedResource()
        NSLog("[TamaNotchi][Stash] ingest securityScoped=%@", accessing ? "true" : "false")
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }

        let safeName = sanitizeFileName(url.lastPathComponent)
        let storedFileName = "\(UUID().uuidString)-\(safeName)"
        let dest = stashFolder.appendingPathComponent(storedFileName)
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: url, to: dest)
            let item = StashedFile(id: UUID(), originalName: safeName, storedURL: dest)
            files.append(item)
            saveManifest()
            NSLog("[TamaNotchi][Stash] ingest OK destino=%@ totalEnAlijo=%ld", dest.path, files.count)
        } catch {
            let ns = error as NSError
            NSLog(
                "[TamaNotchi][Stash] ingest ERROR domain=%@ code=%ld desc=%@",
                ns.domain,
                ns.code,
                error.localizedDescription
            )
        }
    }

    /// Arrastrar desde la mascota hacia el Finder u otra app. Cuando el destino recibe cada archivo, se quita del alijo.
    func dragItemProvider() -> NSItemProvider? {
        guard !files.isEmpty else { return nil }
        let provider = NSItemProvider()
        let snapshot = files
        for f in snapshot {
            let url = f.storedURL
            let stashedId = f.id
            provider.registerFileRepresentation(
                forTypeIdentifier: UTType.fileURL.identifier,
                fileOptions: [],
                visibility: .all
            ) { [weak self] completion in
                // URL explícita file:// ; rutas sin esquema provocan CFURLCopyResourcePropertyForKey en hilos del pasteboard.
                let handoff = URL(fileURLWithPath: url.path, isDirectory: false)
                completion(handoff, true, nil)
                // Retrasar la mutación @Published hasta pasar el teardown del drag (evita crash al pasar a alijo vacío).
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    self?.removeStashedFileAfterDragHandoff(id: stashedId, storedURL: url)
                }
                return nil
            }
        }
        NSLog("[TamaNotchi][Stash] drag provider n=%ld", snapshot.count)
        return provider
    }

    /// Quitar del modelo enseguida; borrar en disco un poco después para no truncar la copia del receptor (Finder, etc.).
    private func removeStashedFileAfterDragHandoff(id: UUID, storedURL: URL) {
        let had = files.contains { $0.id == id }
        files.removeAll { $0.id == id }
        guard had else { return }
        saveManifest()
        let path = storedURL
        // Tras el handoff, dar margen a que Finder termine de leer antes de borrar el original del contenedor.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if FileManager.default.fileExists(atPath: path.path) {
                try? FileManager.default.removeItem(at: path)
            }
        }
        NSLog("[TamaNotchi][Stash] drag entregado, quitado del alijo %@ (quedan %ld)", path.lastPathComponent, files.count)
    }

    /// Elige carpeta destino; copia los archivos y vacía el alijo.
    func beginRetrieveFlow(hostWindow: NSWindow?) {
        guard !files.isEmpty else {
            NSLog("[TamaNotchi][Stash] retrieve omitido: alijo vacío")
            return
        }
        guard !isRetrievePanelActive else {
            NSLog("[TamaNotchi][Stash] retrieve omitido: panel de extracción ya abierto")
            return
        }
        isRetrievePanelActive = true
        let sheetParent = hostWindow ?? NSApp.keyWindow ?? NSApp.windows.first(where: \.isVisible)
        let winDesc = sheetParent.map { w in
            "window title=\(w.title) visible=\(w.isVisible) sheet=\(w.attachedSheet != nil)"
        } ?? "nil"
        NSLog(
            "[TamaNotchi][Stash] retrieve iniciado count=%ld hostWindow=%@ fallback=%@",
            files.count,
            hostWindow.map { "\(Unmanaged.passUnretained($0).toOpaque())" } ?? "nil",
            winDesc
        )
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "Elige la carpeta donde quieres recuperar los documentos."
        panel.prompt = "Extraer aquí"
        let snapshot = files

        let extractToFolder: (URL) -> Void = { [weak self] folder in
            guard let self else {
                NSLog("[TamaNotchi][Stash] extractToFolder: self nil")
                return
            }
            NSLog("[TamaNotchi][Stash] extrayendo a folder=%@", folder.path)
            let accessed = folder.startAccessingSecurityScopedResource()
            NSLog("[TamaNotchi][Stash] dest securityScoped=%@", accessed ? "true" : "false")
            defer {
                if accessed { folder.stopAccessingSecurityScopedResource() }
            }
            for item in snapshot {
                let dest = self.uniqueDestinationURL(in: folder, preferredName: item.originalName)
                do {
                    try FileManager.default.copyItem(at: item.storedURL, to: dest)
                    NSLog("[TamaNotchi][Stash] copiado OK %@ -> %@", item.storedURL.lastPathComponent, dest.path)
                } catch {
                    let ns = error as NSError
                    NSLog(
                        "[TamaNotchi][Stash] copia falló %@ domain=%@ code=%ld %@",
                        item.originalName,
                        ns.domain,
                        ns.code,
                        error.localizedDescription
                    )
                }
            }
            self.clearAllInternal()
            NSLog("[TamaNotchi][Stash] extracción terminada, alijo vaciado")
        }

        if let w = sheetParent {
            NSLog("[TamaNotchi][Stash] panel como sheet en ventana")
            panel.beginSheetModal(for: w) { [weak self] response in
                self?.isRetrievePanelActive = false
                if response == .OK, let folder = panel.url {
                    extractToFolder(folder)
                } else {
                    NSLog("[TamaNotchi][Stash] panel sheet cancelado o sin URL (response=%ld)", response.rawValue)
                }
            }
        } else {
            NSLog("[TamaNotchi][Stash] sin ventana para sheet: runModal")
            NSApp.activate(ignoringOtherApps: true)
            let r = panel.runModal()
            isRetrievePanelActive = false
            if r == .OK, let folder = panel.url {
                extractToFolder(folder)
            } else {
                NSLog("[TamaNotchi][Stash] runModal cancelado o sin URL (raw=%ld)", r.rawValue)
            }
        }
    }

    private func uniqueDestinationURL(in folder: URL, preferredName: String) -> URL {
        var target = folder.appendingPathComponent(preferredName)
        let base = (preferredName as NSString).deletingPathExtension
        let ext = (preferredName as NSString).pathExtension
        var n = 2
        while FileManager.default.fileExists(atPath: target.path) {
            let name = ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"
            target = folder.appendingPathComponent(name)
            n += 1
        }
        return target
    }

    private func clearAllInternal() {
        let n = files.count
        for item in files {
            try? FileManager.default.removeItem(at: item.storedURL)
        }
        files.removeAll()
        try? FileManager.default.removeItem(at: manifestURL)
        NSLog("[TamaNotchi][Stash] clearAllInternal eliminados=%ld", n)
    }

    private func loadManifest() {
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            NSLog("[TamaNotchi][Stash] manifest no existe (primer arranque o ya vacío)")
            return
        }
        guard let data = try? Data(contentsOf: manifestURL) else {
            NSLog("[TamaNotchi][Stash] manifest no legible en %@", manifestURL.path)
            return
        }
        guard let decoded = try? JSONDecoder().decode([ManifestEntry].self, from: data) else {
            NSLog("[TamaNotchi][Stash] manifest JSON inválido (%lu bytes)", UInt(data.count))
            return
        }
        var loaded: [StashedFile] = []
        var missingFiles = 0
        for e in decoded {
            let u = stashFolder.appendingPathComponent(e.storedFileName)
            if FileManager.default.fileExists(atPath: u.path) {
                loaded.append(StashedFile(id: e.id, originalName: e.originalName, storedURL: u))
            } else {
                missingFiles += 1
                NSLog("[TamaNotchi][Stash] manifest entrada sin archivo: %@", e.storedFileName)
            }
        }
        files = loaded
        if missingFiles > 0 {
            NSLog("[TamaNotchi][Stash] manifest entradas huérfanas=%d cargadas=%ld", missingFiles, loaded.count)
        }
    }

    private func saveManifest() {
        let entries = files.map {
            ManifestEntry(id: $0.id, originalName: $0.originalName, storedFileName: $0.storedURL.lastPathComponent)
        }
        guard let data = try? JSONEncoder().encode(entries) else {
            NSLog("[TamaNotchi][Stash] saveManifest encode falló")
            return
        }
        do {
            try data.write(to: manifestURL, options: .atomic)
        } catch {
            NSLog("[TamaNotchi][Stash] saveManifest write falló: %@", error.localizedDescription)
        }
    }

    private func sanitizeFileName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "documento" }
        return trimmed.replacingOccurrences(of: "/", with: ":")
    }
}

enum StashDropSupport {
    nonisolated static func loadFileURL(from provider: NSItemProvider) async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                if let url = item as? URL {
                    cont.resume(returning: url)
                    return
                }
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    cont.resume(returning: url)
                    return
                }
                if let str = item as? String, !str.isEmpty {
                    cont.resume(returning: URL(fileURLWithPath: str))
                    return
                }
                let kind = item.map { String(describing: Swift.type(of: $0)) } ?? "nil"
                NSLog("[TamaNotchi][Stash] loadItem tipo no soportado: %@", kind)
                cont.resume(throwing: NSError(domain: "TamaNotchi.Stash", code: 1, userInfo: [NSLocalizedDescriptionKey: "No se pudo leer el archivo"]))
            }
        }
    }
}
