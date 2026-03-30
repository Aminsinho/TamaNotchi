import Combine
import Foundation

/// Estadísticas de la mascota: decay automático e interacciones (comida / juego / caricias).
final class PetStats: ObservableObject {
    /// Hambre crítica: por debajo de este valor (0…100), prioridad absoluta sobre baile y cuidados que no sean comida.
    static let hungerHungryThreshold = 20

    /// Pérdida de hambre: 1 punto cada `hungerDecaySecondsPerUnit` s de tiempo real (incluido Mac dormido / app cerrada).
    static let hungerDecaySecondsPerUnit: TimeInterval = 300
    /// Pérdida de ánimo inactivo: `happinessLossPerTick` puntos cada `happinessDecaySecondsPerTick` s tras `happinessIdleSeconds`.
    static let happinessDecaySecondsPerTick: TimeInterval = 600
    private static let happinessIdleSeconds: TimeInterval = 15 * 60
    private static let happinessLossPerTick: Double = 2

    private enum UserDefaultsKeys {
        static let hunger = "TamaNotchi.PetStats.hunger"
        static let happiness = "TamaNotchi.PetStats.happiness"
        static let lastInteraction = "TamaNotchi.PetStats.lastInteractionAt"
        static let checkpoint = "TamaNotchi.PetStats.simulationCheckpoint"
    }

    /// Textos mostrados junto a `pet_refuse` durante la negación.
    static let refusalHintWhenHungry = "Tengo hambre"
    static let refusalHintWhenFull = "Ya no tengo hambre"

    @Published var hunger: Double = 80
    @Published var happiness: Double = 80
    @Published var lastInteractionAt: Date = .init()

    /// Última vez que se aplicó decaimiento según el reloj (disco + memoria).
    private(set) var lastSimulationCheckpoint: Date = .init()

    @Published private(set) var isEating: Bool = false
    @Published private(set) var isPlayAnimating: Bool = false
    @Published private(set) var isStrokeAnimating: Bool = false
    @Published private(set) var isRefusing: Bool = false
    /// Burbuja breve durante la negación (hambre o saciedad).
    @Published private(set) var refusalHint: String?

    private var lifecycleDecayTimer: Timer?
    private var eatingReset: AnyCancellable?
    private var playReset: AnyCancellable?
    private var strokeReset: AnyCancellable?
    private var refuseReset: AnyCancellable?

    var hungerClamped: Int {
        Int(hunger.rounded().clamped(to: 0...100))
    }

    var happinessClamped: Int {
        Int(happiness.rounded().clamped(to: 0...100))
    }

    var isVeryHungry: Bool {
        hungerClamped < Self.hungerHungryThreshold
    }

    /// Energía y vida al máximo: no acepta más comida.
    var isFullySatisfied: Bool {
        hungerClamped >= 100 && happinessClamped >= 100
    }

    var isHappyEnoughForDance: Bool {
        happinessClamped >= 40
    }

    init() {
        loadPersistedStats()
        synchronizeWallClockDecay()
    }

    func startLifecycleTimers() {
        stopLifecycleTimers()
        synchronizeWallClockDecay()

        lifecycleDecayTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.synchronizeWallClockDecay()
        }
        RunLoop.main.add(lifecycleDecayTimer!, forMode: .common)
    }

    func stopLifecycleTimers() {
        lifecycleDecayTimer?.invalidate()
        lifecycleDecayTimer = nil
    }

    /// Aplica hambre/ánimo según el tiempo real transcurrido (útil al abrir la app o al despertar el Mac).
    func synchronizeWallClockDecay() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastSimulationCheckpoint)
        guard elapsed > 0.5 else { return }

        let hungerLoss = elapsed / Self.hungerDecaySecondsPerUnit
        if hungerLoss > 0 {
            hunger = max(0, hunger - hungerLoss)
        }

        let idleOkFrom = lastInteractionAt.addingTimeInterval(Self.happinessIdleSeconds)
        let decayHappyFrom = max(lastSimulationCheckpoint, idleOkFrom)
        if now > decayHappyFrom {
            let happyDecaySeconds = now.timeIntervalSince(decayHappyFrom)
            let happyLoss = (happyDecaySeconds / Self.happinessDecaySecondsPerTick) * Self.happinessLossPerTick
            if happyLoss > 0 {
                happiness = max(0, happiness - happyLoss)
            }
        }

        lastSimulationCheckpoint = now
        persistStats()
    }

    func persistStatsForShutdown() {
        synchronizeWallClockDecay()
        persistStats()
    }

    private func loadPersistedStats() {
        let d = UserDefaults.standard
        if d.object(forKey: UserDefaultsKeys.hunger) != nil {
            hunger = min(100, max(0, d.double(forKey: UserDefaultsKeys.hunger)))
        }
        if d.object(forKey: UserDefaultsKeys.happiness) != nil {
            happiness = min(100, max(0, d.double(forKey: UserDefaultsKeys.happiness)))
        }
        if let t = d.object(forKey: UserDefaultsKeys.lastInteraction) as? TimeInterval {
            lastInteractionAt = Date(timeIntervalSince1970: t)
        }
        if let t = d.object(forKey: UserDefaultsKeys.checkpoint) as? TimeInterval {
            lastSimulationCheckpoint = Date(timeIntervalSince1970: t)
        } else {
            lastSimulationCheckpoint = Date()
        }
    }

    private func persistStats() {
        let d = UserDefaults.standard
        d.set(hunger, forKey: UserDefaultsKeys.hunger)
        d.set(happiness, forKey: UserDefaultsKeys.happiness)
        d.set(lastInteractionAt.timeIntervalSince1970, forKey: UserDefaultsKeys.lastInteraction)
        d.set(lastSimulationCheckpoint.timeIntervalSince1970, forKey: UserDefaultsKeys.checkpoint)
    }

    /// `true` si se aplicó comida; `false` si estaba saciada y solo negó.
    @discardableResult
    func feed() -> Bool {
        if isFullySatisfied {
            beginRefusalAnimation(hint: Self.refusalHintWhenFull)
            return false
        }
        touchInteraction()
        hunger = min(100, hunger + 28)
        happiness = min(100, happiness + 4)

        cancelRefusalAnimation()
        clearTransientAnimations()
        isEating = true
        eatingReset?.cancel()
        eatingReset = Just(())
            .delay(for: .seconds(2.4), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.isEating = false
            }
        persistStats()
        return true
    }

    func play() {
        if isVeryHungry {
            beginRefusalAnimation(hint: Self.refusalHintWhenHungry)
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
        persistStats()
    }

    func stroke() {
        if isVeryHungry {
            beginRefusalAnimation(hint: Self.refusalHintWhenHungry)
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
        persistStats()
    }

    /// `pet_refuse.gif` en bucle durante ~3 s; opcionalmente muestra `hint` como burbuja.
    func beginRefusalAnimation(hint: String? = nil) {
        refuseReset?.cancel()
        isRefusing = true
        refusalHint = hint
        refuseReset = Just(())
            .delay(for: .seconds(3), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.isRefusing = false
                self?.refusalHint = nil
            }
    }

    private func cancelRefusalAnimation() {
        refuseReset?.cancel()
        refuseReset = nil
        isRefusing = false
        refusalHint = nil
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

    deinit {
        stopLifecycleTimers()
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
