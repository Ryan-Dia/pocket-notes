import AppKit
import Carbon
import Combine
import SwiftUI
import Sparkle

final class AppDelegate: NSObject, NSApplicationDelegate {
    let notesStore = NotesStore()
    let themeStore = ThemeStore()
    private var panelController: PanelController?
    private var themeCancellable: AnyCancellable?
    private var statusItem: NSStatusItem?
    private var hotkey: GlobalHotkey?
    private var contextMenu: NSMenu?
    private var settingsWindow: NSWindow?
    private var localMonitor: LocalHotkeyMonitor?
    private var updaterController: SPUStandardUpdaterController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        setupMenuBar()
        setupPanel()
        setupHotkey()
        setupLocalHotkeys()
        setupThemeObserver()
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

        let updateItem = NSMenuItem(title: "업데이트 확인...", action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        contextMenu = menu
    }

    private func setupPanel() {
        let contentView = ContentView()
            .environmentObject(notesStore)
            .environmentObject(themeStore)
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
            let keyCode: Int
            let modifiers: Int
            if UserDefaults.standard.object(forKey: "hotkeyKeyCode") == nil {
                keyCode = kVK_Space; modifiers = optionKey
            } else {
                keyCode = UserDefaults.standard.integer(forKey: "hotkeyKeyCode")
                modifiers = UserDefaults.standard.integer(forKey: "hotkeyModifiers")
            }
            self?.hotkey?.update(keyCode: keyCode, modifiers: modifiers)
        }
    }

    private func setupLocalHotkeys() {
        localMonitor = LocalHotkeyMonitor()
        applyLocalHotkeySettings()
        NotificationCenter.default.addObserver(
            forName: Notification.Name("pn.localHotkeyDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.applyLocalHotkeySettings() }
    }

    private func setupThemeObserver() {
        themeCancellable = themeStore.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                DispatchQueue.main.async { self?.updateWindowAppearance() }
            }
        updateWindowAppearance()
    }

    private func updateWindowAppearance() {
        let appearance = NSAppearance(named: themeStore.isDark ? .darkAqua : .aqua)
        panelController?.panel.appearance = appearance
        settingsWindow?.appearance = appearance
    }

    private func applyLocalHotkeySettings() {
        let ud = UserDefaults.standard
        let noteKey   = ud.object(forKey: "createNoteKeyCode")     == nil ? kVK_ANSI_N : ud.integer(forKey: "createNoteKeyCode")
        let noteMod   = ud.object(forKey: "createNoteModifiers")   == nil ? cmdKey     : ud.integer(forKey: "createNoteModifiers")
        let folderKey = ud.object(forKey: "createFolderKeyCode")   == nil ? kVK_ANSI_F : ud.integer(forKey: "createFolderKeyCode")
        let folderMod = ud.object(forKey: "createFolderModifiers") == nil ? cmdKey     : ud.integer(forKey: "createFolderModifiers")
        localMonitor?.update(
            createNote:   (noteKey,   noteMod),
            createFolder: (folderKey, folderMod)
        )
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

    @objc private func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(onCheckForUpdates: { [weak self] in
                self?.updaterController.checkForUpdates(nil)
            })
            .environmentObject(notesStore)
            .environmentObject(themeStore)
            let hosting = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hosting)
            window.title = "설정"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
