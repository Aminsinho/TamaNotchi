import SwiftUI

/// Acciones rápidas: comida, juego y caricia (iconos del catálogo / bundle).
struct CarePopoverView: View {
    @EnvironmentObject private var petStats: PetStats
    @Binding var isPresented: Bool

    private var hangry: Bool { petStats.isVeryHungry }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cuidar")
                .font(.headline)

            HStack(spacing: 14) {
                foodCareButton
                blockedCareButton(title: "Jugar") {
                    PetArt.image(named: "icon_play")
                } primaryAction: {
                    petStats.play()
                    isPresented = false
                }

                blockedCareButton(title: "Caricia") {
                    PetArt.image(named: "icon_hand")
                } primaryAction: {
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

    private var foodCareButton: some View {
        Button {
            petStats.feed()
            isPresented = false
        } label: {
            VStack(spacing: 6) {
                PetArt.image(named: "icon_food")
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                Text("Comida")
                    .font(.caption2)
            }
            .frame(width: 72, height: 72)
            .scaleEffect(hangry ? 1.08 : 1)
            .brightness(hangry ? 0.06 : 0)
        }
        .buttonStyle(.borderless)
        .help("Dar de comer")
    }

    private func blockedCareButton(
        title: String,
        @ViewBuilder image: () -> Image,
        primaryAction: @escaping () -> Void
    ) -> some View {
        let label = VStack(spacing: 6) {
            image()
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 36, height: 36)
            Text(title)
                .font(.caption2)
        }
        .frame(width: 72, height: 72)

        return Group {
            if hangry {
                ZStack {
                    Button(action: {}) {
                        label
                    }
                    .buttonStyle(.borderless)
                    .disabled(true)
                    .opacity(0.5)

                    Button {
                        petStats.beginRefusalAnimation()
                    } label: {
                        Color.clear
                            .frame(width: 72, height: 72)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button(action: primaryAction) {
                    label
                }
                .buttonStyle(.borderless)
                .help(title)
            }
        }
    }
}
