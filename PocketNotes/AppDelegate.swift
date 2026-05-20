import AppKit
import Carbon
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let notesStore = NotesStore()
    private var panelController: PanelController?
    private var statusItem: NSStatusItem?
    private var hotkey: GlobalHotkey?
    private var contextMenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        setupPanel()
        setupHotkey()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }

        let img = NSImage(systemSymbolName: "note.text", accessibilityDescription: "PocketNotes")
        img?.isTemplate = true
        button.image = img

        // 좌클릭 = 패널 토글, 우클릭 = 컨텍스트 메뉴
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.action = #selector(handleStatusItemClick)
        button.target = self

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "PocketNotes 열기", action: #selector(showPanel), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "설정...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        contextMenu = menu
    }

    private func setupPanel() {
        let contentView = ContentView()
            .environmentObject(notesStore)
        panelController = PanelController(contentView: AnyView(contentView))
    }

    private func setupHotkey() {
        hotkey = GlobalHotkey { [weak self] in
            self?.togglePanel()
        }
        NotificationCenter.default.addObserver(
            forName: Notification.Name("pn.hotkeyDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let keyCode = UserDefaults.standard.integer(forKey: "hotkeyKeyCode")
            let modifiers = UserDefaults.standard.integer(forKey: "hotkeyModifiers")
            self?.hotkey?.update(
                keyCode: keyCode == 0 ? kVK_Space : keyCode,
                modifiers: modifiers == 0 ? optionKey : modifiers
            )
        }
    }

    @objc private func handleStatusItemClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            statusItem?.menu = contextMenu
            statusItem?.button?.performClick(nil)
            DispatchQueue.main.async { [weak self] in
                self?.statusItem?.menu = nil
            }
        } else {
            togglePanel()
        }
    }

    @objc func togglePanel() {
        panelController?.toggle()
    }

    @objc private func showPanel() {
        panelController?.show()
    }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
