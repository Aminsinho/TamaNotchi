import SwiftUI

/// Isla a la derecha del notch: música siempre visible, mascota y cuidados compactos.
struct NotchPetView: View {
    @EnvironmentObject private var petStats: PetStats
    @EnvironmentObject private var notchHost: NotchWindowHost
    @EnvironmentObject private var nowPlaying: NowPlayingMonitor

    private var expanded: Bool { notchHost.isRevealed }

    private var shouldDance: Bool {
        expanded
            && nowPlaying.isPlaying
            && petStats.isHappyEnoughForDance
            && !petStats.isVeryHungry
            && !petStats.isEating
            && !petStats.isPlayAnimating
            && !petStats.isStrokeAnimating
    }

    private var petW: CGFloat {
        expanded ? NotchWindowMetrics.petLogicalWidth : NotchWindowMetrics.petPeekWidth
    }

    private var petH: CGFloat {
        expanded ? NotchWindowMetrics.petLogicalHeight : NotchWindowMetrics.petPeekHeight
    }

    private var miniStatFont: CGFloat { expanded ? 10 : 9 }
    private var miniStatIcon: CGFloat { expanded ? 10 : 8 }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !petStats.isVeryHungry)) { context in
            let shake: CGFloat = petStats.isVeryHungry
                ? CGFloat(sin(context.date.timeIntervalSinceReferenceDate * 13)) * 2.3
                : 0

            ZStack(alignment: .bottom) {
                Color.clear
                islandChrome
                    .offset(x: shake)
            }
            .frame(
                width: NotchWindowMetrics.windowWidth,
                height: NotchWindowMetrics.fullHeight,
                alignment: .bottom
            )
        }
    }

    private var islandChrome: some View {
        VStack(spacing: expanded ? 6 : 4) {
            musicBar

            petSprite
                .frame(width: petW, height: petH)
                .clipped()

            careAndStatsBar
        }
        .padding(.horizontal, expanded ? 12 : 8)
        .padding(.top, expanded ? 10 : 6)
        .padding(.bottom, expanded ? 9 : 6)
        .background {
            RoundedRectangle(cornerRadius: expanded ? 36 : 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.1),
                            Color(white: 0.06),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: expanded ? 36 : 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.22),
                                    Color.white.opacity(0.05),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: expanded ? 36 : 16, style: .continuous))
        .animation(.spring(response: 0.48, dampingFraction: 0.82), value: expanded)
        .animation(.easeInOut(duration: 0.18), value: petDisplayKey)
        .animation(.easeInOut(duration: 0.2), value: nowPlaying.isPlaying)
    }

    private var petDisplayKey: String {
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

    private var musicBar: some View {
        HStack(spacing: expanded ? 8 : 4) {
            Image(systemName: "waveform")
                .font(.system(size: expanded ? 12 : 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))

            Text(trackTitleLine)
                .font(.system(size: expanded ? 11 : 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 2)

            mediaIconButton(systemName: "backward.fill", help: "Canción anterior") {
                MediaHardwareKey.previousTrack.send()
                scheduleMediaRefresh()
            }

            mediaIconButton(
                systemName: nowPlaying.isPlaying ? "pause.fill" : "play.fill",
                help: nowPlaying.isPlaying ? "Pausar" : "Reproducir"
            ) {
                MediaPlayPauseKey.send()
                scheduleMediaRefresh()
            }

            mediaIconButton(systemName: "forward.fill", help: "Siguiente canción") {
                MediaHardwareKey.nextTrack.send()
                scheduleMediaRefresh()
            }
        }
        .foregroundStyle(.white)
    }

    private func mediaIconButton(systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: expanded ? 14 : 12, weight: .semibold))
                .frame(minWidth: 26, minHeight: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .help(help)
    }

    private func scheduleMediaRefresh() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            nowPlaying.refreshAll()
        }
    }

    private var careAndStatsBar: some View {
        HStack(spacing: expanded ? 8 : 5) {
            HStack(spacing: 3) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: miniStatIcon))
                Text("\(petStats.hungerClamped)")
                    .font(.system(size: miniStatFont, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(.mint.opacity(0.95))

            HStack(spacing: 3) {
                Image(systemName: "heart.fill")
                    .font(.system(size: miniStatIcon))
                Text("\(petStats.happinessClamped)")
                    .font(.system(size: miniStatFont, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(.pink.opacity(0.95))

            Spacer(minLength: 2)

            careIconButton(assetName: "icon_food", help: "Dar de comer") {
                petStats.feed()
            }
            careIconButton(assetName: "icon_play", help: "Jugar") {
                petStats.play()
            }
            careIconButton(assetName: "icon_hand", help: "Caricia") {
                petStats.stroke()
            }
        }
    }

    private func careIconButton(assetName: String, help: String, action: @escaping () -> Void) -> some View {
        let side: CGFloat = expanded ? 26 : 22
        return Button(action: action) {
            PetArt.image(named: assetName)
                .resizable()
                .interpolation(.none)
                .antialiased(false)
                .scaledToFit()
                .frame(width: side, height: side)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    @ViewBuilder
    private var petSprite: some View {
        let box = CGSize(width: petW, height: petH)
        if petStats.isEating, let url = PetArt.gifURL(named: "pet_eating") {
            gif(url: url, box: box)
        } else if petStats.isPlayAnimating, let url = PetArt.gifURL(named: "pet_happy_play") {
            gif(url: url, box: box)
        } else if petStats.isStrokeAnimating, let url = PetArt.gifURL(named: "pet_hand") {
            gif(url: url, box: box)
        } else if shouldDance, let url = PetArt.gifURL(named: "pet_happy_dance") {
            gif(url: url, box: box)
        } else {
            PetArt.image(named: petImageName)
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

    private var petImageName: String {
        if petStats.isVeryHungry {
            return "pet_hungry"
        }
        return "pet_idle"
    }
}

#if DEBUG
struct NotchPetView_Previews: PreviewProvider {
    static var previews: some View {
        NotchPetView()
            .environmentObject(PetStats())
            .environmentObject(NotchWindowHost())
            .environmentObject(NowPlayingMonitor())
            .frame(width: 360, height: 280)
            .background(Color.gray.opacity(0.25))
    }
}
#endif
