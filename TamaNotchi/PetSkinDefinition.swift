import Foundation

/// Definición de una mascota.
///
/// Cada mascota vive en su propia subcarpeta dentro de `BundleResources`
/// con nombres de archivo fijos (p. ej. `pet_idle.png`, `pet_eating.gif`).
///
/// Para añadir una mascota nueva:
///   1. Crea `Assets/<Nombre>/` con los 9 sprites estándar.
///   2. Crea `BundleResources/<Nombre>/` con symlinks.
///   3. Añade un `static let` aquí y agrégalo a `builtIn`.
struct PetSkinDefinition: Identifiable, Equatable, Hashable, Codable {
    let id: String
    let displayName: String
    /// Subcarpeta dentro de `BundleResources` que contiene los assets.
    let folder: String

    // MARK: - Nombres de archivo (convención fija, iguales para todas las mascotas)

    static let idleImage     = "pet_idle"
    static let hungryImage   = "pet_hungry"
    static let blinkImage    = "pet_blink"
    static let eatingGif     = "pet_eating"
    static let happyPlayGif  = "pet_happy_play"
    static let strokeGif     = "pet_hand"
    static let danceGif      = "pet_happy_dance"
    static let danceGif2     = "pet_happy_dance_2"
    static let refuseGif     = "pet_refuse"

    // MARK: - Mascotas integradas

    static let mitchy = PetSkinDefinition(
        id: "mitchy",
        displayName: "Mitchy",
        folder: "Mitchy"
    )

    /// Catálogo de mascotas disponibles.
    static let builtIn: [PetSkinDefinition] = [
        .mitchy,
    ]
}
