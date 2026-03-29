import AppKit
import SwiftUI

enum NotchWindowMetrics {
    static let windowWidth: CGFloat = 352
    static let peekHeight: CGFloat = 102
    static let fullHeight: CGFloat = 256
    static let petLogicalWidth: CGFloat = 108
    static let petLogicalHeight: CGFloat = 108
    static let petPeekWidth: CGFloat = 64
    static let petPeekHeight: CGFloat = 64
    static let hotZoneWidth: CGFloat = 220
    static let hotZoneHeight: CGFloat = 56
    static let screenTrailingMargin: CGFloat = 8
}

/// Ventana anclada a la **derecha del notch** (centro de pantalla + mitad estimada del notch).
private enum NotchWindowLayout {
    static var notchHalfWidth: CGFloat = 100
    static var gapFromNotch: CGFloat = 0

    static func windowOriginX(screen: NSScreen, windowWidth: CGFloat) -> CGFloat {
        let frame = screen.frame
        let middle = frame.midX
        let originX = middle + notchHalfWidth + gapFromNotch
        let maxLeft = frame.maxX - windowWidth - NotchWindowMetrics.screenTrailingMargin
        if originX > maxLeft {
            return (middle - windowWidth / 2).rounded()
        }
        return originX.rounded()
    }

    static func hoverRect(screen: NSScreen, windowWidth: CGFloat, windowMinX: CGFloat) -> NSRect {
        let frame = screen.frame
        let pad: CGFloat = 16
        let x = max(frame.minX, windowMinX - pad)
        let maxW = frame.maxX - x - NotchWindowMetrics.screenTrailingMargin
        let width = min(NotchWindowMetrics.hotZoneWidth + 2 * pad, maxW)
        return NSRect(
            x: x,
            y: frame.maxY - NotchWindowMetrics.hotZoneHeight,
            width: width,
            height: NotchWindowMetrics.hotZoneHeight
        )
    }
}

final class NotchWindowHost: ObservableObject {
    @Published fileprivate(set) var isRevealed: Bool = false
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

    private var collapseWorkItem: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.mainMenu = makeMinimalMenu()

        petStats.startLifecycleTimers()

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

        let host = NotchHostingRoot(rootView: AnyView(root))
        host.layer?.backgroundColor = NSColor.clear.cgColor

        let window = NotchKeyWindow(
            contentRect: initialFrame(),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true

        notchHost.window = window
        notchWindow = window
        applyWindowFrame(revealed: false, animated: false)
        window.makeKeyAndOrderFront(nil)
    }

    private func initialFrame() -> NSRect {
        guard let screen = targetScreen() else {
            return NSRect(x: 0, y: 0, width: NotchWindowMetrics.windowWidth, height: NotchWindowMetrics.peekHeight)
        }
        let h = NotchWindowMetrics.peekHeight
        let w = NotchWindowMetrics.windowWidth
        let x = NotchWindowLayout.windowOriginX(screen: screen, windowWidth: w)
        let y = screen.frame.maxY - h
        return NSRect(x: x, y: y, width: w, height: h)
    }

    private func targetScreen() -> NSScreen? {
        NSScreen.main ?? NSScreen.screens.first
    }

    private func applyWindowFrame(revealed: Bool, animated: Bool) {
        guard let window = notchWindow, let screen = window.screen ?? targetScreen() else { return }

        let height = revealed ? NotchWindowMetrics.fullHeight : NotchWindowMetrics.peekHeight
        let width = NotchWindowMetrics.windowWidth
        let x = NotchWindowLayout.windowOriginX(screen: screen, windowWidth: width)
        let y = screen.frame.maxY - height
        let target = NSRect(x: x, y: y, width: width, height: height)

        if notchHost.isRevealed == revealed, window.frame.almostEquals(to: target) {
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

        let windowX = NotchWindowLayout.windowOriginX(
            screen: screen,
            windowWidth: NotchWindowMetrics.windowWidth
        )
        let rect = NotchWindowLayout.hoverRect(
            screen: screen,
            windowWidth: NotchWindowMetrics.windowWidth,
            windowMinX: windowX
        )

        let inHotZone = rect.contains(point)
        let inIslandWindow = notchWindow.map { $0.frame.contains(point) } ?? false
        let shouldReveal = inHotZone || inIslandWindow

        if shouldReveal {
            collapseWorkItem?.cancel()
            collapseWorkItem = nil
            if notchHost.isRevealed == false {
                applyWindowFrame(revealed: true, animated: true)
            }
        } else {
            scheduleCollapseIfNeeded()
        }
    }

    private func scheduleCollapseIfNeeded() {
        guard notchHost.isRevealed else { return }
        collapseWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.applyWindowFrame(revealed: false, animated: true)
        }
        collapseWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: item)
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
        layer?.backgroundColor = NSColor.clear.cgColor
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
        addSubview(hv)
        NSLayoutConstraint.activate([
            hv.leadingAnchor.constraint(equalTo: leadingAnchor),
            hv.trailingAnchor.constraint(equalTo: trailingAnchor),
            hv.bottomAnchor.constraint(equalTo: bottomAnchor),
            hv.heightAnchor.constraint(equalToConstant: NotchWindowMetrics.fullHeight),
        ])
        hostingView = hv
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
