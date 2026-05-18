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

    private var mouseScreen: NSScreen {
        let loc = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(loc) }) ?? NSScreen.main ?? NSScreen.screens[0]
    }

    func show() {
        activeScreen = mouseScreen
        guard let screen = activeScreen else { return }
        let shownFrame = shownRect(for: screen)
        let hiddenFrame = hiddenRect(for: screen)

        panel.alphaValue = 0  // orderFront 전 투명으로 — 옆 모니터에 순간 노출 방지
        panel.setFrame(hiddenFrame, display: false)
        panel.orderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(shownFrame, display: true)
            panel.animator().alphaValue = 1
        }
        isVisible = true
    }

    func hide() {
        guard isVisible else { return }
        let screen = activeScreen ?? mouseScreen
        let hiddenFrame = hiddenRect(for: screen)

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(hiddenFrame ?? panel.frame, display: true)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            self.panel.orderOut(nil)
            self.panel.alphaValue = 1  // 다음 show()를 위해 초기화
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
