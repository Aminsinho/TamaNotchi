import Combine
import Foundation

/// Estadísticas de la mascota: decay automático e interacciones (comida / juego / caricias).
final class PetStats: ObservableObject {
    @Published var hunger: Double = 80
    @Published var happiness: Double = 80
    @Published var lastInteractionAt: Date = .init()

    @Published private(set) var isEating: Bool = false
    @Published private(set) var isPlayAnimating: Bool = false
    @Published private(set) var isStrokeAnimating: Bool = false

    private var hungerTimer: Timer?
    private var happinessTimer: Timer?
    private var eatingReset: AnyCancellable?
    private var playReset: AnyCancellable?
    private var strokeReset: AnyCancellable?

    var hungerClamped: Int {
        Int(hunger.rounded().clamped(to: 0...100))
    }

    var happinessClamped: Int {
        Int(happiness.rounded().clamped(to: 0...100))
    }

    var isVeryHungry: Bool {
        hungerClamped < 20
    }

    var isHappyEnoughForDance: Bool {
        happinessClamped >= 40
    }

    func startLifecycleTimers() {
        hungerTimer?.invalidate()
        happinessTimer?.invalidate()

        hungerTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.decayHungerStep()
        }
        RunLoop.main.add(hungerTimer!, forMode: .common)

        happinessTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            self?.decayHappinessIfIdle()
        }
        RunLoop.main.add(happinessTimer!, forMode: .common)
    }

    func stopLifecycleTimers() {
        hungerTimer?.invalidate()
        happinessTimer?.invalidate()
        hungerTimer = nil
        happinessTimer = nil
    }

    func feed() {
        touchInteraction()
        hunger = min(100, hunger + 28)
        happiness = min(100, happiness + 4)

        clearTransientAnimations()
        isEating = true
        eatingReset?.cancel()
        eatingReset = Just(())
            .delay(for: .seconds(2.4), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.isEating = false
            }
    }

    func play() {
        touchInteraction()
        happiness = min(100, happiness + 22)
        hunger = max(0, hunger - 3)

        clearTransientAnimations()
        isPlayAnimating = true
        playReset?.cancel()
        playReset = Just(())
            .delay(for: .seconds(2.6), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.isPlayAnimating = false
            }
    }

    func stroke() {
        touchInteraction()
        happiness = min(100, happiness + 16)

        clearTransientAnimations()
        isStrokeAnimating = true
        strokeReset?.cancel()
        strokeReset = Just(())
            .delay(for: .seconds(2.6), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.isStrokeAnimating = false
            }
    }

    private func clearTransientAnimations() {
        eatingReset?.cancel()
        playReset?.cancel()
        strokeReset?.cancel()
        isEating = false
        isPlayAnimating = false
        isStrokeAnimating = false
    }

    private func touchInteraction() {
        lastInteractionAt = Date()
    }

    private func decayHungerStep() {
        hunger = max(0, hunger - 1)
    }

    private func decayHappinessIfIdle() {
        let idleSeconds = Date().timeIntervalSince(lastInteractionAt)
        guard idleSeconds > 15 * 60 else { return }
        happiness = max(0, happiness - 2)
    }

    deinit {
        stopLifecycleTimers()
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
