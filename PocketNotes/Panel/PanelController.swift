import AppKit
import SwiftUI

enum PanelEdge: String {
    case right, left
}

final class PanelController {
    let panel: SlidingPanel
    private var isVisible = false
    private var resignObserver: NSObjectProtocol?
    private var activeScreen: NSScreen?

    var edge: PanelEdge {
        PanelEdge(rawValue: UserDefaults.standard.string(forKey: "panelEdge") ?? "right") ?? .right
    }

    var panelWidth: CGFloat { 320 }

    init(contentView: AnyView) {
        panel = SlidingPanel()
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.sizingOptions = []
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        panel.contentView = hostingView

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            guard UserDefaults.standard.bool(forKey: "hideOnLostFocus") else { return }
            self?.hide()
        }
    }

    deinit {
        if let obs = resignObserver { NotificationCenter.default.removeObserver(obs) }
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    private var mouseScreen: NSScreen {
        let loc = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(loc) }) ?? NSScreen.main ?? NSScreen.screens[0]
    }

    func show() {
        activeScreen = mouseScreen
        guard let screen = activeScreen else { return }

        // 창은 항상 화면 안에 고정 — 옆 모니터 영역 침범 없음
        panel.setFrame(shownRect(for: screen), display: false)

        // 콘텐츠를 창 밖으로 밀기 (창이 클립하므로 화면에 안 보임)
        let layer = panel.contentView?.layer
        layer?.removeAllAnimations()
        let offset = edge == .right ? panelWidth : -panelWidth
        layer?.transform = CATransform3DMakeTranslation(offset, 0, 0)
        panel.orderFront(nil)

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.22)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        layer?.transform = CATransform3DIdentity
        CATransaction.commit()

        isVisible = true
    }

    func hide() {
        guard isVisible else { return }
        let layer = panel.contentView?.layer
        let offset = edge == .right ? panelWidth : -panelWidth

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.18)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeIn))
        CATransaction.setCompletionBlock {
            self.panel.orderOut(nil)
            layer?.removeAllAnimations()
            layer?.transform = CATransform3DIdentity
            self.activeScreen = nil
        }
        layer?.transform = CATransform3DMakeTranslation(offset, 0, 0)
        CATransaction.commit()

        isVisible = false
    }

    private func shownRect(for screen: NSScreen?) -> NSRect {
        guard let screen else { return .zero }
        let f = screen.visibleFrame
        let x: CGFloat = edge == .right ? f.maxX - panelWidth : f.minX
        return NSRect(x: x, y: f.minY, width: panelWidth, height: f.height)
    }
}
