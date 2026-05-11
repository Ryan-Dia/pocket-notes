import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let notesStore = NotesStore()
    private var panelController: PanelController?
    private var statusItem: NSStatusItem?
    private var hotkey: GlobalHotkey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupMenuBar()
        setupPanel()
        setupHotkey()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "PocketNotes")
        button.image?.isTemplate = true
        button.action = #selector(togglePanel)
        button.target = self

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "PocketNotes 열기", action: #selector(togglePanel), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "설정...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    private func setupPanel() {
        let contentView = ContentView()
            .environmentObject(notesStore)
        panelController = PanelController(contentView: AnyView(contentView))
    }

    private func setupHotkey() {
        hotkey = GlobalHotkey {
            self.togglePanel()
        }
    }

    @objc func togglePanel() {
        statusItem?.menu = nil
        statusItem?.button?.action = #selector(togglePanel)
        panelController?.toggle()
    }

    @objc func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
