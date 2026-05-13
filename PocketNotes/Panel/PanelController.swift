import AppKit
import SwiftUI

enum PanelEdge: String {
    case right, left
}

final class PanelController {
    private let panel: SlidingPanel
    private var isVisible = false
    private var resignObserver: NSObjectProtocol?

    var edge: PanelEdge {
        get { PanelEdge(rawValue: UserDefaults.standard.string(forKey: "panelEdge") ?? "right") ?? .right }
    }

    var panelWidth: CGFloat { 320 }

    init(contentView: AnyView) {
        panel = SlidingPanel()
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.sizingOptions = []   // SwiftUI preferred size 무시, 패널 크기를 따름
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
        guard let screen = NSScreen.main else { return }
        let shownFrame = shownRect(for: screen)
        let hiddenFrame = hiddenRect(for: screen)

        // 먼저 올바른 높이로 화면 밖에서 시작
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
        let hiddenFrame = hiddenRect(for: NSScreen.main)

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(hiddenFrame ?? panel.frame, display: true)
        }, completionHandler: {
            self.panel.orderOut(nil)
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
