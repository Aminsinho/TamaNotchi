import AppKit
import Combine
import SwiftUI

enum NotchWindowMetrics {
    static let windowWidth: CGFloat = 352
    /// Altura cuando está recogido: franja bajo el notch (ancho completo `windowWidth`).
    static let collapsedUnderNotchHeight: CGFloat = 10
    static let fullHeight: CGFloat = 256
    static let petLogicalWidth: CGFloat = 108
    static let petLogicalHeight: CGFloat = 108
    static let petPeekWidth: CGFloat = 64
    static let petPeekHeight: CGFloat = 64
    static let hotZoneWidth: CGFloat = 280
    static let hotZoneHeight: CGFloat = 56
    /// Franja superior central (solo cuando la isla está oculta) para deslizarla de nuevo.
    static let notchWakeStripHeight: CGFloat = 15
    static let notchWakeStripWidth: CGFloat = 240
    /// Inactividad antes del ocultamiento “genio” (ratón fuera + sin interacción).
    static let genieHideIdleSeconds: Double = 5
    /// Sube el borde superior de la isla (+Y AppKit) para alinearla con el notch real (calibración visual).
    static let windowTopExtraLift: CGFloat = 23
}

// MARK: - Integración Dynamic Island (coordenadas de pantalla absolutas)

/// Posicionamiento **absoluto** respecto a `NSScreen.frame` (origen abajo-izquierda, `y` hacia arriba).
private enum NotchIslandGeometry {
    /// Línea base bajo el menú (`NSStatusBar`); el borde superior real de la ventana añade `windowTopExtraLift`.
    static func menuBarBottomY(for screen: NSScreen) -> CGFloat {
        screen.frame.maxY - NSStatusBar.system.thickness
    }

    static func islandWindowTopY(for screen: NSScreen) -> CGFloat {
        menuBarBottomY(for: screen) + NotchWindowMetrics.windowTopExtraLift
    }

    static func petWindowFrame(screen: NSScreen, width: CGFloat, height: CGFloat) -> NSRect {
        let f = screen.frame
        let windowTopY = islandWindowTopY(for: screen)
        let x = f.midX - width / 2
        let y = windowTopY - height
        return NSRect(x: x, y: y, width: width, height: height)
    }

    static func hoverRect(screen: NSScreen) -> NSRect {
        let f = screen.frame
        let windowTopY = islandWindowTopY(for: screen)
        let w = min(NotchWindowMetrics.hotZoneWidth, f.width)
        let x = f.midX - w / 2
        let h = NotchWindowMetrics.hotZoneHeight
        let y = windowTopY - h
        return NSRect(x: x, y: y, width: w, height: h)
    }

    /// 15 pt de alto, centrados en X, pegados al borde inferior del notch / menú (`windowTopY`).
    static func wakeStripRect(screen: NSScreen) -> NSRect {
        let f = screen.frame
        let windowTopY = islandWindowTopY(for: screen)
        let w = min(NotchWindowMetrics.notchWakeStripWidth, f.width)
        let h = NotchWindowMetrics.notchWakeStripHeight
        let x = f.midX - w / 2
        let y = windowTopY - h
        return NSRect(x: x, y: y, width: w, height: h)
    }
}

final class NotchWindowHost: ObservableObject {
    @Published fileprivate(set) var isRevealed: Bool = true
    fileprivate weak var window: NSWindow?

    fileprivate func setRevealed(_ revealed: Bool) {
        guard isRevealed != revealed else { return }
        isRevealed = revealed
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchWindow: NSWindow?
    private var mousePollTimer: Timer?

    private let petStats = PetStats()
    private let notchHost = NotchWindowHost()
    private let nowPlaying = NowPlayingMonitor()

    private var presenceCancellable: AnyCancellable?

    /// La ventana está `orderOut` tras animación genio.
    private var isGenieHidden = false
    private var isGenieAnimatingOut = false
    /// Última vez que hubo ratón sobre la isla / franja hover o interacción con la mascota.
    private var lastUserPresenceAt = Date()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.mainMenu = makeMinimalMenu()

        petStats.startLifecycleTimers()

        SystemMediaRemoteCommands.registerPlaybackEventsHandler { [weak self] in
            self?.nowPlaying.refreshAll()
            self?.noteUserPresence()
        }

        presenceCancellable = petStats.$lastInteractionAt
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.noteUserPresence()
            }

        setupNotchWindow()
        startMouseProximityPolling()

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        mousePollTimer?.invalidate()
        petStats.stopLifecycleTimers()
    }

    private func setupNotchWindow() {
        let root = NotchPetView()
            .environmentObject(petStats)
            .environmentObject(notchHost)
            .environmentObject(nowPlaying)
            .ignoresSafeArea(.all)

        let host = NotchHostingRoot(rootView: AnyView(root))
        host.layer?.backgroundColor = NSColor.black.cgColor

        let window = NotchKeyWindow(
            contentRect: initialFrame(),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        window.isOpaque = true
        window.backgroundColor = NSColor.black
        window.hasShadow = false
        /// Por encima de la barra de menús (integración notch / sin corte con el menú).
        window.level = .popUpMenu
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true

        notchHost.window = window
        notchWindow = window
        applyWindowFrame(revealed: true, animated: false)
        window.makeKeyAndOrderFront(nil)
        noteUserPresence()
    }

    private func initialFrame() -> NSRect {
        guard let screen = targetScreen() else {
            return NSRect(x: 0, y: 0, width: NotchWindowMetrics.windowWidth, height: NotchWindowMetrics.fullHeight)
        }
        return NotchIslandGeometry.petWindowFrame(
            screen: screen,
            width: NotchWindowMetrics.windowWidth,
            height: NotchWindowMetrics.fullHeight
        )
    }

    private func targetScreen() -> NSScreen? {
        NSScreen.main ?? NSScreen.screens.first
    }

    private func applyWindowFrame(revealed: Bool, animated: Bool) {
        guard !isGenieHidden, !isGenieAnimatingOut,
              let window = notchWindow, let screen = window.screen ?? targetScreen() else { return }

        let height = revealed ? NotchWindowMetrics.fullHeight : NotchWindowMetrics.collapsedUnderNotchHeight
        let width = NotchWindowMetrics.windowWidth
        let target = NotchIslandGeometry.petWindowFrame(screen: screen, width: width, height: height)

        let syncIslandCorners = {
            (window.contentView as? NotchHostingRoot)?.syncIslandCornerRadius(revealed: revealed)
        }

        if notchHost.isRevealed == revealed, window.frame.almostEquals(to: target) {
            syncIslandCorners()
            return
        }

        let update: () -> Void = {
            window.setFrame(target, display: true, animate: false)
        }

        notchHost.setRevealed(revealed)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.52
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 0.9, 0.32, 1.02)
                context.allowsImplicitAnimation = true
                window.animator().setFrame(target, display: true)
            }
        } else {
            update()
        }
        syncIslandCorners()
    }

    private func startMouseProximityPolling() {
        mousePollTimer = Timer.scheduledTimer(withTimeInterval: 1 / 30.0, repeats: true) { [weak self] _ in
            self?.mousePollFired()
        }
        RunLoop.main.add(mousePollTimer!, forMode: .common)
    }

    private func mousePollFired() {
        guard let screen = targetScreen() else { return }
        let point = NSEvent.mouseLocation

        if isGenieHidden {
            if NotchIslandGeometry.wakeStripRect(screen: screen).contains(point) {
                restoreFromGenie(screen: screen)
            }
            return
        }

        let inHotZone = NotchIslandGeometry.hoverRect(screen: screen).contains(point)
        let inIslandWindow = notchWindow.map { $0.frame.contains(point) } ?? false

        if inHotZone || inIslandWindow {
            noteUserPresence()
        }

        if notchHost.isRevealed == false, inHotZone || inIslandWindow {
            applyWindowFrame(revealed: true, animated: true)
        }

        if !isGenieHidden, !isGenieAnimatingOut,
           Date().timeIntervalSince(lastUserPresenceAt) >= NotchWindowMetrics.genieHideIdleSeconds {
            performGenieHide(fallbackScreen: screen)
        }
    }

    private func noteUserPresence() {
        lastUserPresenceAt = Date()
    }

    private func performGenieHide(fallbackScreen: NSScreen) {
        guard let window = notchWindow,
              !isGenieHidden, !isGenieAnimatingOut else { return }

        let screen = window.screen ?? fallbackScreen
        isGenieAnimatingOut = true
        notchHost.setRevealed(false)

        let topY = NotchIslandGeometry.islandWindowTopY(for: screen)
        let w = max(80, window.frame.width)
        let endH: CGFloat = 1
        let endFrame = NSRect(x: window.frame.midX - w / 2, y: topY - endH, width: w, height: endH)

        window.alphaValue = 1
        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = 0.72
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.33, 0.0, 0.2, 1.0)
                context.allowsImplicitAnimation = true
                window.animator().setFrame(endFrame, display: true)
                window.animator().alphaValue = 0
            },
            completionHandler: { [weak self] in
                guard let self, let window = self.notchWindow else { return }
                window.orderOut(nil)
                window.alphaValue = 1
                self.isGenieHidden = true
                self.isGenieAnimatingOut = false
            }
        )
    }

    private func restoreFromGenie(screen fallback: NSScreen) {
        guard let window = notchWindow, isGenieHidden else { return }
        let screen = window.screen ?? fallback
        isGenieHidden = false
        isGenieAnimatingOut = false
        window.alphaValue = 1
        notchHost.setRevealed(true)

        let topY = NotchIslandGeometry.islandWindowTopY(for: screen)
        let full = NotchIslandGeometry.petWindowFrame(
            screen: screen,
            width: NotchWindowMetrics.windowWidth,
            height: NotchWindowMetrics.fullHeight
        )
        let peekH: CGFloat = 4
        let start = NSRect(
            x: full.midX - NotchWindowMetrics.windowWidth / 2,
            y: topY - peekH,
            width: NotchWindowMetrics.windowWidth,
            height: peekH
        )
        window.alphaValue = 0
        window.setFrame(start, display: true, animate: false)
        window.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.62
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 0.9, 0.28, 1.0)
            context.allowsImplicitAnimation = true
            window.animator().alphaValue = 1
            window.animator().setFrame(full, display: true)
        }

        noteUserPresence()
    }

    private func makeMinimalMenu() -> NSMenu {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        appItem.submenu = NSMenu()
        appItem.submenu?.title = "TamaNotchi"
        appItem.submenu?.addItem(
            withTitle: "Salir de TamaNotchi",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(appItem)
        return menu
    }
}

private final class NotchHostingRoot: NSView {
    private var hostingView: NSHostingView<AnyView>?

    init(rootView: AnyView) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.masksToBounds = true
        embed(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func embed(rootView: AnyView) {
        hostingView?.removeFromSuperview()
        let hv = NSHostingView(rootView: rootView)
        hv.translatesAutoresizingMaskIntoConstraints = false
        hv.wantsLayer = true
        hv.layer?.backgroundColor = NSColor.black.cgColor
        addSubview(hv)
        NSLayoutConstraint.activate([
            hv.topAnchor.constraint(equalTo: topAnchor),
            hv.leadingAnchor.constraint(equalTo: leadingAnchor),
            hv.trailingAnchor.constraint(equalTo: trailingAnchor),
            hv.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        hostingView = hv
    }

    /// Alineado con `NotchPetView.islandBottomCornerRadius` (solo esquinas inferiores).
    func syncIslandCornerRadius(revealed: Bool) {
        let height = revealed ? NotchWindowMetrics.fullHeight : NotchWindowMetrics.collapsedUnderNotchHeight
        let radius: CGFloat = revealed ? 36 : min(16, max(2, height * 0.5))
        let bottomCorners: CACornerMask = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        layer?.cornerRadius = radius
        layer?.maskedCorners = bottomCorners
        layer?.masksToBounds = true
        if #available(macOS 11.0, *) {
            layer?.cornerCurve = .continuous
        }
        hostingView?.layer?.cornerRadius = radius
        hostingView?.layer?.maskedCorners = bottomCorners
        hostingView?.layer?.masksToBounds = true
        if #available(macOS 11.0, *) {
            hostingView?.layer?.cornerCurve = .continuous
        }
    }
}

private extension NSRect {
    func almostEquals(to other: NSRect, tolerance: CGFloat = 0.5) -> Bool {
        abs(origin.x - other.origin.x) <= tolerance
            && abs(origin.y - other.origin.y) <= tolerance
            && abs(size.width - other.size.width) <= tolerance
            && abs(size.height - other.size.height) <= tolerance
    }
}
