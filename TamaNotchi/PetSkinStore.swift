import Combine
import Foundation

/// Mascota elegida por el usuario (persistente en `UserDefaults`).
final class PetSkinStore: ObservableObject {
    private static let defaultsKey = "TamaNotchi.PetSkin.selectedId"

    @Published private(set) var selectedSkinId: String

    var currentSkin: PetSkinDefinition {
        PetSkinDefinition.builtIn.first { $0.id == selectedSkinId } ?? .mitchy
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.defaultsKey)
        if let saved, PetSkinDefinition.builtIn.contains(where: { $0.id == saved }) {
            selectedSkinId = saved
        } else {
            selectedSkinId = PetSkinDefinition.mitchy.id
        }
    }

    func selectSkin(id: String) {
        guard PetSkinDefinition.builtIn.contains(where: { $0.id == id }),
              selectedSkinId != id else { return }
        selectedSkinId = id
        UserDefaults.standard.set(id, forKey: Self.defaultsKey)
    }
}
