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

            if let hint = petStats.refusalHint, !hint.isEmpty {
                Text(hint)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.secondary.opacity(0.12))
                    )
            }

            HStack(spacing: 21) {
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

            VStack(alignment: .leading, spacing: 10) {
                popoverStatBar(
                    title: "Energía",
                    systemImage: "leaf.fill",
                    value: petStats.hunger,
                    tint: .mint
                )
                popoverStatBar(
                    title: "Vida",
                    systemImage: "heart.fill",
                    value: petStats.happiness,
                    tint: .pink
                )
            }
        }
        .padding(14)
        .frame(minWidth: 400)
    }

    private func popoverStatBar(title: String, systemImage: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .imageScale(.small)
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
            }
            GeometryReader { geo in
                StatBarView(
                    value: value,
                    tint: tint,
                    width: max(1, geo.size.width),
                    height: 7,
                    growDirection: .fromLeading
                )
            }
            .frame(height: 7)
        }
        .accessibilityElement(children: .combine)
    }

    private var foodCareButton: some View {
        Button {
            if petStats.feed() {
                isPresented = false
            }
        } label: {
            VStack(spacing: 9) {
                PetArt.image(named: "icon_food")
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 54, height: 54)
                Text("Comida")
                    .font(.caption.weight(.medium))
            }
            .frame(width: 108, height: 108)
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
        let label = VStack(spacing: 9) {
            image()
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 54, height: 54)
            Text(title)
                .font(.caption.weight(.medium))
        }
        .frame(width: 108, height: 108)

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
                        petStats.beginRefusalAnimation(hint: PetStats.refusalHintWhenHungry)
                    } label: {
                        Color.clear
                            .frame(width: 108, height: 108)
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
