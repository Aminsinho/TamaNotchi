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
                islandChrome(danceBob: danceBob, timelineDate: context.date)
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

    /// Parpadeo: un frame corto cada `blinkInterval` s (sprite estático).
    private static let blinkInterval: TimeInterval = 3
    private static let blinkDuration: TimeInterval = 0.16

    private func islandChrome(danceBob: CGFloat, timelineDate: Date) -> some View {
        VStack(spacing: expanded ? 7 : 5) {
            heroRow(danceBob: danceBob, timelineDate: timelineDate)

            careActionsRow

            musicDock
        }
        .padding(.horizontal, expanded ? 12 : 8)
        .animation(.spring(response: 0.48, dampingFraction: 0.82), value: expanded)
        .animation(.easeInOut(duration: 0.18), value: petDisplayKey)
        .animation(.easeInOut(duration: 0.2), value: nowPlaying.isPlaying)
    }

    private func heroRow(danceBob: CGFloat, timelineDate: Date) -> some View {
        HStack(alignment: .center, spacing: expanded ? 6 : 4) {
            statBarSideColumn(
                icon: "leaf.fill",
                value: petStats.hunger,
                tint: Color.mint.opacity(0.95),
                alignment: .leading,
                growDirection: .fromLeading
            )
            .frame(width: expanded ? 44 : 36, alignment: .leading)

            Spacer(minLength: 2)

            ZStack(alignment: .top) {
                petSprite(timelineDate: timelineDate)
                    .frame(width: petW, height: petH)
                    .offset(y: danceBob)
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if petStats.isVeryHungry {
                            petStats.beginRefusalAnimation(hint: PetStats.refusalHintWhenHungry)
                        } else if petStats.isFullySatisfied {
                            petStats.beginRefusalAnimation(hint: PetStats.refusalHintWhenFull)
                        }
                    }

                if let hint = petStats.refusalHint, !hint.isEmpty {
                    refusalHintBubble(text: hint)
                        .offset(y: danceBob - (expanded ? 8 : 6))
                }
            }
            .id("\(skinStore.selectedSkinId)-\(petDisplayKey)")

            Spacer(minLength: 2)

            statBarSideColumn(
                icon: "heart.fill",
                value: petStats.happiness,
                tint: Color.pink.opacity(0.95),
                alignment: .trailing,
                growDirection: .fromTrailing
            )
            .frame(width: expanded ? 44 : 36, alignment: .trailing)
        }
    }

    private func statBarSideColumn(
        icon: String,
        value: Double,
        tint: Color,
        alignment: HorizontalAlignment,
        growDirection: StatBarView.GrowDirection
    ) -> some View {
        let barW: CGFloat = expanded ? 42 : 34
        let barH: CGFloat = expanded ? 5 : 4
        return VStack(alignment: alignment == .leading ? .leading : .trailing, spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: statIcon, weight: .semibold))
                .foregroundStyle(tint)
            StatBarView(
                value: value,
                tint: tint,
                width: barW,
                height: barH,
                growDirection: growDirection
            )
            .accessibilityLabel(accessibilityStatLabel(icon: icon, value: value))
        }
    }

    private func accessibilityStatLabel(icon: String, value: Double) -> String {
        let n = Int(min(100, max(0, value.rounded())))
        switch icon {
        case "leaf.fill": return "Energía \(n) por ciento"
        case "heart.fill": return "Vida \(n) por ciento"
        default: return "\(n) por ciento"
        }
    }

    private func refusalHintBubble(text: String) -> some View {
        Text(text)
            .font(.system(size: expanded ? 10 : 9, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.96))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.74))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
    }

    private var careActionsRow: some View {
        HStack(spacing: expanded ? 18 : 12) {
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
        VStack(alignment: .center, spacing: expanded ? 8 : 6) {
            MarqueeTitleView(
                text: trackTitleLine,
                fontSize: expanded ? 16 : 14,
                cycleSeconds: 10
            )
            .frame(maxWidth: .infinity)
            .frame(height: expanded ? 24 : 20)

            HStack(spacing: expanded ? 20 : 16) {
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
                .font(.system(size: expanded ? 22 : 20, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.92))
                .frame(minWidth: expanded ? 56 : 48, minHeight: expanded ? 44 : 36)
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
        if shouldDance { return nowPlaying.danceGifUsesAlternate ? "dance2" : "dance" }
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
        let side: CGFloat = expanded ? 39 : 33
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
                        petStats.beginRefusalAnimation(hint: PetStats.refusalHintWhenHungry)
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

    private var allowsIdleBlink: Bool {
        !petStats.isRefusing
            && !petStats.isEating
            && !petStats.isPlayAnimating
            && !petStats.isStrokeAnimating
            && !shouldDance
    }

    private func shouldShowBlink(at date: Date) -> Bool {
        guard allowsIdleBlink else { return false }
        let t = date.timeIntervalSinceReferenceDate
        let phase = t.truncatingRemainder(dividingBy: Self.blinkInterval)
        return phase < Self.blinkDuration
    }

    @ViewBuilder
    private func petSprite(timelineDate: Date) -> some View {
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
        } else if shouldDance {
            let primary = nowPlaying.danceGifUsesAlternate ? skin.danceGif2 : skin.danceGif
            let secondary = nowPlaying.danceGifUsesAlternate ? skin.danceGif : skin.danceGif2
            if let url = PetArt.gifURL(named: primary) ?? PetArt.gifURL(named: secondary) {
                gif(url: url, box: box)
            } else {
                staticPetBitmap(skin: skin, timelineDate: timelineDate)
            }
        } else {
            staticPetBitmap(skin: skin, timelineDate: timelineDate)
        }
    }

    private func staticPetBitmap(skin: PetSkinDefinition, timelineDate: Date) -> some View {
        let imageName = shouldShowBlink(at: timelineDate) ? skin.blinkImage : petImageName(skin: skin)
        return PetArt.image(named: imageName)
            .resizable()
            .interpolation(.none)
            .antialiased(false)
            .scaledToFit()
            .frame(width: petW, height: petH)
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
