import SwiftUI

/// Dynamic Island: mascota central, estadísticas a los lados, música abajo, cuidados entre medias.
struct NotchPetView: View {
    @EnvironmentObject private var petStats: PetStats
    @EnvironmentObject private var notchHost: NotchWindowHost
    @EnvironmentObject private var nowPlaying: NowPlayingMonitor
    @EnvironmentObject private var skinStore: PetSkinStore

    private var expanded: Bool { notchHost.isRevealed }

    /// Baile en bucle mientras el Media Center reporta reproducción (`MPNowPlayingInfoCenter`).
    private var shouldDance: Bool {
        expanded
            && nowPlaying.isPlaying
            && !petStats.isVeryHungry
            && !petStats.isEating
            && !petStats.isPlayAnimating
            && !petStats.isStrokeAnimating
            && !petStats.isRefusing
    }

    private var petW: CGFloat {
        expanded ? NotchWindowMetrics.petLogicalWidth : NotchWindowMetrics.petPeekWidth
    }

    private var petH: CGFloat {
        expanded ? NotchWindowMetrics.petLogicalHeight : NotchWindowMetrics.petPeekHeight
    }

    private var statFont: CGFloat { expanded ? 11 : 9 }
    private var statIcon: CGFloat { expanded ? 11 : 9 }

    /// Radio solo en esquinas inferiores (superiores rectas, al ras del notch).
    private var islandBottomCornerRadius: CGFloat { expanded ? 36 : 16 }

    /// Desplaza todo el contenido hacia abajo para equilibrar el área negra (+ extra para bajar mascota, botones y dock).
    private var contentShiftY: CGFloat {
        NotchWindowMetrics.fullHeight * 0.10 + 15
    }

    private var islandMaskShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            cornerRadii: RectangleCornerRadii(
                topLeading: 0,
                bottomLeading: islandBottomCornerRadius,
                bottomTrailing: islandBottomCornerRadius,
                topTrailing: 0
            ),
            style: .continuous
        )
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 36.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let shake: CGFloat = petStats.isVeryHungry
                ? CGFloat(sin(t * 13)) * 2.3
                : 0
            let danceBob: CGFloat = shouldDance
                ? CGFloat(sin(t * Double.pi * 2 * 2.15)) * 4.5
                : 0

            ZStack(alignment: .top) {
                islandMaskShape
                    .fill(Color.black)
                islandChrome(danceBob: danceBob)
                    .offset(x: shake, y: contentShiftY)
            }
            .frame(
                width: NotchWindowMetrics.windowWidth,
                height: NotchWindowMetrics.fullHeight,
                alignment: .top
            )
            .clipShape(islandMaskShape)
        }
    }

    private func islandChrome(danceBob: CGFloat) -> some View {
        VStack(spacing: expanded ? 7 : 5) {
            heroRow(danceBob: danceBob)

            careActionsRow

            musicDock
        }
        .padding(.horizontal, expanded ? 12 : 8)
        .animation(.spring(response: 0.48, dampingFraction: 0.82), value: expanded)
        .animation(.easeInOut(duration: 0.18), value: petDisplayKey)
        .animation(.easeInOut(duration: 0.2), value: nowPlaying.isPlaying)
    }

    private func heroRow(danceBob: CGFloat) -> some View {
        HStack(alignment: .center, spacing: expanded ? 6 : 4) {
            statSideColumn(
                icon: "leaf.fill",
                value: petStats.hungerClamped,
                tint: Color.mint.opacity(0.95),
                alignment: .leading
            )
            .frame(width: expanded ? 44 : 36, alignment: .leading)

            Spacer(minLength: 2)

            ZStack(alignment: .top) {
                petSprite
                    .frame(width: petW, height: petH)
                    .offset(y: danceBob)
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if petStats.isVeryHungry {
                            petStats.beginRefusalAnimation()
                        }
                    }
            }
            .id("\(skinStore.selectedSkinId)-\(petDisplayKey)")

            Spacer(minLength: 2)

            statSideColumn(
                icon: "heart.fill",
                value: petStats.happinessClamped,
                tint: Color.pink.opacity(0.95),
                alignment: .trailing
            )
            .frame(width: expanded ? 44 : 36, alignment: .trailing)
        }
    }

    private func statSideColumn(
        icon: String,
        value: Int,
        tint: Color,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment == .leading ? .leading : .trailing, spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: statIcon, weight: .semibold))
                .foregroundStyle(tint)
            Text("\(value)")
                .font(.system(size: statFont, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.92))
        }
    }

    private var careActionsRow: some View {
        HStack(spacing: expanded ? 12 : 8) {
            careIconButton(assetName: "icon_food", help: "Dar de comer", blocksWhenHangry: false) {
                petStats.feed()
            }
            careIconButton(assetName: "icon_play", help: "Jugar", blocksWhenHangry: true) {
                petStats.play()
            }
            careIconButton(assetName: "icon_hand", help: "Caricia", blocksWhenHangry: true) {
                petStats.stroke()
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var musicDock: some View {
        VStack(alignment: .leading, spacing: expanded ? 5 : 3) {
            MarqueeTitleView(
                text: trackTitleLine,
                fontSize: expanded ? 8 : 7,
                cycleSeconds: 10
            )
            .frame(height: expanded ? 12 : 10)

            HStack(spacing: expanded ? 14 : 10) {
                Spacer(minLength: 0)
                pixelMediaButton(label: "⏮", help: "Anterior") {
                    MediaHardwareKey.previousTrack.send()
                    scheduleMediaRefresh()
                }
                pixelMediaButton(label: nowPlaying.isPlaying ? "❚❚" : "▶", help: nowPlaying.isPlaying ? "Pausar" : "Reproducir") {
                    MediaPlayPauseKey.send()
                    scheduleMediaRefresh()
                }
                pixelMediaButton(label: "⏭", help: "Siguiente") {
                    MediaHardwareKey.nextTrack.send()
                    scheduleMediaRefresh()
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func pixelMediaButton(label: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: expanded ? 11 : 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.92))
                .frame(minWidth: expanded ? 28 : 24, minHeight: expanded ? 22 : 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(PixelTapButtonStyle())
        .help(help)
    }

    /// Prioridad: negación > comer > juego > caricia > baile (bloqueado si hambre) > hambre estática > idle.
    private var petDisplayKey: String {
        if petStats.isRefusing { return "refuse" }
        if petStats.isEating { return "eating" }
        if petStats.isPlayAnimating { return "play" }
        if petStats.isStrokeAnimating { return "stroke" }
        if shouldDance { return "dance" }
        if petStats.isVeryHungry { return "hungry" }
        return "idle"
    }

    private var trackTitleLine: String {
        if let t = nowPlaying.trackTitle, !t.isEmpty {
            return t
        }
        return nowPlaying.isPlaying ? "Reproduciendo…" : "Sin música"
    }

    private func scheduleMediaRefresh() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            nowPlaying.refreshAll()
        }
    }

    private func careIconButton(
        assetName: String,
        help: String,
        blocksWhenHangry: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let side: CGFloat = expanded ? 26 : 22
        let blocked = blocksWhenHangry && petStats.isVeryHungry
        let icon = PetArt.image(named: assetName)
            .resizable()
            .interpolation(.none)
            .antialiased(false)
            .scaledToFit()
            .frame(width: side, height: side)

        return Group {
            if blocked {
                ZStack {
                    Button(action: {}) {
                        icon
                    }
                    .buttonStyle(.plain)
                    .disabled(true)
                    .opacity(0.5)

                    Button {
                        petStats.beginRefusalAnimation()
                    } label: {
                        Color.clear
                            .frame(width: side, height: side)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button(action: action) {
                    icon
                        .scaleEffect(assetName == "icon_food" && petStats.isVeryHungry ? 1.08 : 1)
                        .brightness(assetName == "icon_food" && petStats.isVeryHungry ? 0.06 : 0)
                }
                .buttonStyle(.plain)
                .help(help)
            }
        }
    }

    @ViewBuilder
    private var petSprite: some View {
        let skin = skinStore.currentSkin
        let box = CGSize(width: petW, height: petH)
        if petStats.isRefusing, let url = PetArt.gifURL(named: skin.refuseGif) {
            gif(url: url, box: box)
        } else if petStats.isEating, let url = PetArt.gifURL(named: skin.eatingGif) {
            gif(url: url, box: box)
        } else if petStats.isPlayAnimating, let url = PetArt.gifURL(named: skin.happyPlayGif) {
            gif(url: url, box: box)
        } else if petStats.isStrokeAnimating, let url = PetArt.gifURL(named: skin.strokeGif) {
            gif(url: url, box: box)
        } else if shouldDance, let url = PetArt.gifURL(named: skin.danceGif) {
            gif(url: url, box: box)
        } else {
            PetArt.image(named: petImageName(skin: skin))
                .resizable()
                .interpolation(.none)
                .antialiased(false)
                .scaledToFit()
                .frame(width: petW, height: petH)
        }
    }

    private func gif(url: URL, box: CGSize) -> some View {
        AnimatedGifRepresentable(url: url, layoutSize: box)
            .frame(width: petW, height: petH)
            .clipped()
    }

    private func petImageName(skin: PetSkinDefinition) -> String {
        if petStats.isVeryHungry {
            return skin.hungryImage
        }
        return skin.idleImage
    }
}

private struct PixelTapButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.45 : 1)
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
    }
}

#if DEBUG
struct NotchPetView_Previews: PreviewProvider {
    static var previews: some View {
        NotchPetView()
            .environmentObject(PetStats())
            .environmentObject(NotchWindowHost())
            .environmentObject(NowPlayingMonitor())
            .environmentObject(PetSkinStore())
            .frame(width: 360, height: 280)
            .background(Color.black)
    }
}
#endif
