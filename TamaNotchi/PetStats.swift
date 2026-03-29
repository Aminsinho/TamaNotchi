import Combine
import Foundation

/// Estadísticas de la mascota: decay automático e interacciones (comida / juego / caricias).
final class PetStats: ObservableObject {
    /// Por debajo de este valor (hambre en escala 0…100), la mascota está hambrienta y de mal humor.
    static let hungerHungryThreshold = 20

    @Published var hunger: Double = 80
    @Published var happiness: Double = 80
    @Published var lastInteractionAt: Date = .init()

    @Published private(set) var isEating: Bool = false
    @Published private(set) var isPlayAnimating: Bool = false
    @Published private(set) var isStrokeAnimating: Bool = false
    @Published private(set) var isRefusing: Bool = false
    /// Burbuja “Primero, ¡comida!” sobre la mascota (isla).
    @Published private(set) var showFoodFirstHint: Bool = false

    private var hungerTimer: Timer?
    private var happinessTimer: Timer?
    private var eatingReset: AnyCancellable?
    private var playReset: AnyCancellable?
    private var strokeReset: AnyCancellable?
    private var refuseReset: AnyCancellable?
    private var foodHintReset: AnyCancellable?

    var hungerClamped: Int {
        Int(hunger.rounded().clamped(to: 0...100))
    }

    var happinessClamped: Int {
        Int(happiness.rounded().clamped(to: 0...100))
    }

    var isVeryHungry: Bool {
        hungerClamped < Self.hungerHungryThreshold
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

        cancelRefusalAndHint()
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
        if isVeryHungry {
            beginRefusalAnimation()
            return
        }
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
        if isVeryHungry {
            beginRefusalAnimation()
            return
        }
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

    /// Animación `pet_refuse` (~2.5 s) y burbuja de comida; se puede llamar al abrir el panel con hambre o al pulsar Jugar/Caricia bloqueados.
    func beginRefusalAnimation() {
        refuseReset?.cancel()
        isRefusing = true
        refuseReset = Just(())
            .delay(for: .seconds(2.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.isRefusing = false
            }
        flashFoodFirstHint()
    }

    private func flashFoodFirstHint() {
        showFoodFirstHint = true
        foodHintReset?.cancel()
        foodHintReset = Just(())
            .delay(for: .seconds(2.3), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.showFoodFirstHint = false
            }
    }

    private func cancelRefusalAndHint() {
        refuseReset?.cancel()
        refuseReset = nil
        isRefusing = false
        foodHintReset?.cancel()
        foodHintReset = nil
        showFoodFirstHint = false
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
