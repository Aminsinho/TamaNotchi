import SwiftUI

/// Acciones rápidas: comida, juego y caricia (iconos del catálogo / bundle).
struct CarePopoverView: View {
    @EnvironmentObject private var petStats: PetStats
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cuidar")
                .font(.headline)

            HStack(spacing: 14) {
                careButton(title: "Comida") {
                    PetArt.image(named: "icon_food")
                } action: {
                    petStats.feed()
                    isPresented = false
                }

                careButton(title: "Jugar") {
                    PetArt.image(named: "icon_play")
                } action: {
                    petStats.play()
                    isPresented = false
                }

                careButton(title: "Caricia") {
                    PetArt.image(named: "icon_hand")
                } action: {
                    petStats.stroke()
                    isPresented = false
                }
            }

            Divider().padding(.vertical, 2)

            HStack {
                Label("Hambre: \(petStats.hungerClamped)", systemImage: "leaf")
                Spacer()
                Label("Ánimo: \(petStats.happinessClamped)", systemImage: "heart")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(minWidth: 240)
    }

    private func careButton(
        title: String,
        @ViewBuilder image: () -> Image,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                image()
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                Text(title)
                    .font(.caption2)
            }
            .frame(width: 72, height: 72)
        }
        .buttonStyle(.borderless)
        .help(title)
    }
}
