import SwiftUI

/// Acciones rápidas: comida, juego y caricia (iconos del catálogo / bundle).
struct CarePopoverView: View {
    @EnvironmentObject private var petStats: PetStats
    @Binding var isPresented: Bool

    @State private var popoverFoodCallout = false
    @State private var popoverCalloutTask: Task<Void, Never>?

    private var hangry: Bool { petStats.isVeryHungry }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cuidar")
                .font(.headline)

            if popoverFoodCallout {
                HStack(spacing: 6) {
                    PetArt.image(named: "icon_food")
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                    Text("Primero, ¡comida!")
                        .font(.caption.weight(.semibold))
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.secondary.opacity(0.14))
                )
            }

            HStack(spacing: 14) {
                careButton(title: "Comida", disabledLook: false, help: "Dar de comer") {
                    PetArt.image(named: "icon_food")
                } action: {
                    petStats.feed()
                    isPresented = false
                }

                careButton(title: "Jugar", disabledLook: hangry, help: hangry ? "Primero, ¡comida!" : "Jugar") {
                    PetArt.image(named: "icon_play")
                } action: {
                    petStats.play()
                    isPresented = false
                }

                careButton(title: "Caricia", disabledLook: hangry, help: hangry ? "Primero, ¡comida!" : "Caricia") {
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
        .onAppear {
            if petStats.isVeryHungry {
                petStats.beginRefusalAnimation()
            }
        }
        .onDisappear {
            popoverCalloutTask?.cancel()
            popoverCalloutTask = nil
        }
    }

    private func flashPopoverFoodCallout() {
        popoverFoodCallout = true
        popoverCalloutTask?.cancel()
        popoverCalloutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_300_000_000)
            guard !Task.isCancelled else { return }
            popoverFoodCallout = false
        }
    }

    private func careButton(
        title: String,
        disabledLook: Bool,
        help: String,
        @ViewBuilder image: () -> Image,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            if disabledLook {
                petStats.beginRefusalAnimation()
                flashPopoverFoodCallout()
            } else {
                action()
            }
        } label: {
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
        .opacity(disabledLook ? 0.5 : 1)
        .help(help)
    }
}
