import Foundation

/// Recursos de una mascota (nombres **sin** extensión; `PetArt` resuelve `.png` / `.gif`).
///
/// Para añadir un skin: incluye los archivos en `BundleResources` y añade una entrada en `builtIn`.
struct PetSkinDefinition: Identifiable, Equatable, Hashable, Codable {
    let id: String
    let displayName: String

    let idleImage: String
    let hungryImage: String
    let eatingGif: String
    let happyPlayGif: String
    let strokeGif: String
    let danceGif: String
    let refuseGif: String

    /// Skin por defecto (assets actuales).
    static let classic = PetSkinDefinition(
        id: "classic",
        displayName: "Clásico",
        idleImage: "pet_idle",
        hungryImage: "pet_hungry",
        eatingGif: "pet_eating",
        happyPlayGif: "pet_happy_play",
        strokeGif: "pet_hand",
        danceGif: "pet_happy_dance",
        refuseGif: "pet_refuse"
    )

    /// Catálogo embebido; puedes añadir más skins cuando tengas los archivos.
    static let builtIn: [PetSkinDefinition] = [
        .classic,
    ]
}
