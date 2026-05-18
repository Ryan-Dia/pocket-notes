import AppKit
import SwiftUI

enum PanelEdge: String {
    case right, left
}

final class PanelController {
    private let panel: SlidingPanel
    private var isVisible = false
    private var resignObserver: NSObjectProtocol?
    private var activeScreen: NSScreen?  // show() 시점의 화면을 고정

    var edge: PanelEdge {
        PanelEdge(rawValue: UserDefaults.standard.string(forKey: "panelEdge") ?? "right") ?? .right
    }

    var panelWidth: CGFloat { 320 }

    init(contentView: AnyView) {
        panel = SlidingPanel()
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.sizingOptions = []
        hostingView.autoresizingMask = [.width, .height]
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

    func show() {
        // show() 시점의 화면을 고정 — 이후 hide()도 같은 화면 좌표 사용
        activeScreen = NSScreen.main
        guard let screen = activeScreen else { return }
        let shownFrame = shownRect(for: screen)
        let hiddenFrame = hiddenRect(for: screen)

        panel.setFrame(hiddenFrame, display: false)
        panel.orderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(shownFrame, display: true)
        }
        isVisible = true
    }

    func hide() {
        guard isVisible else { return }
        // show() 때 고정한 화면 사용, 없으면 현재 main
        let screen = activeScreen ?? NSScreen.main
        let hiddenFrame = hiddenRect(for: screen)

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(hiddenFrame ?? panel.frame, display: true)
        }, completionHandler: {
            self.panel.orderOut(nil)
            self.activeScreen = nil
        })
        isVisible = false
    }

    private func shownRect(for screen: NSScreen?) -> NSRect {
        guard let screen else { return .zero }
        let f = screen.visibleFrame
        let x: CGFloat = edge == .right ? f.maxX - panelWidth : f.minX
        return NSRect(x: x, y: f.minY, width: panelWidth, height: f.height)
    }

    private func hiddenRect(for screen: NSScreen?) -> NSRect {
        guard let screen else { return .zero }
        let f = screen.visibleFrame
        let x: CGFloat = edge == .right ? f.maxX : f.minX - panelWidth
        return NSRect(x: x, y: f.minY, width: panelWidth, height: f.height)
    }
}
