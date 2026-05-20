# 로컬 단축키 (노트/폴더 생성) 기능 설계

## 목표

패널이 열린 상태에서만 동작하는 로컬 단축키 두 개를 추가한다.
- **노트 생성**: 현재 진입한 폴더에 새 노트 생성 (최상위 화면에서는 무시)
- **폴더 생성**: 현재 위치에 새 폴더 생성 (depth ≥ 2에서는 무시)

두 단축키 모두 설정창에서 자유롭게 변경할 수 있다.

---

## 파일 구조

| 파일 | 역할 |
|------|------|
| `Hotkey/LocalHotkeyMonitor.swift` | NSEvent 로컬 모니터 등록/해제, 키 매칭, Notification 포스트 (신규) |
| `AppDelegate.swift` | LocalHotkeyMonitor 생성, 설정 변경 시 재등록 |
| `UI/ContentView.swift` | Notification 수신 후 현재 네비게이션 기준으로 노트/폴더 생성 |
| `Settings/SettingsView.swift` | "노트 생성" / "폴더 생성" HotkeyRecorderView 행 추가 |

---

## LocalHotkeyMonitor

`NSEvent.addLocalMonitorForEvents(matching: .keyDown)` 로 패널이 key window일 때만 키 이벤트를 수신한다. (로컬 모니터는 자신이 key window인 앱에서만 발동하므로 별도 필터 불필요)

### 인터페이스

```swift
final class LocalHotkeyMonitor {
    init()
    func update(createNote: (keyCode: Int, modifiers: Int),
                createFolder: (keyCode: Int, modifiers: Int))
    func stop()
}
```

### 키 매칭

NSEvent의 modifierFlags를 Carbon 포맷으로 변환 후 저장된 값과 비교:

```swift
private func carbonMods(from flags: NSEvent.ModifierFlags) -> Int {
    var m = 0
    if flags.contains(.command) { m |= cmdKey }
    if flags.contains(.option)  { m |= optionKey }
    if flags.contains(.control) { m |= controlKey }
    if flags.contains(.shift)   { m |= shiftKey }
    return m
}
```

이벤트의 `keyCode`와 변환된 modifiers가 등록된 값과 일치하면 해당 Notification을 포스트하고 `nil`을 반환(이벤트 소비). 불일치 시 이벤트를 그대로 전달.

### Notification 이름

```swift
extension Notification.Name {
    static let pnCreateNote   = Notification.Name("pn.local.createNote")
    static let pnCreateFolder = Notification.Name("pn.local.createFolder")
}
```

---

## AppDelegate 변경

`setupHotkey()`에서 `LocalHotkeyMonitor`를 생성하고 초기값을 설정:

```swift
private var localMonitor: LocalHotkeyMonitor?

private func setupLocalHotkeys() {
    localMonitor = LocalHotkeyMonitor()
    applyLocalHotkeySettings()

    NotificationCenter.default.addObserver(
        forName: Notification.Name("pn.localHotkeyDidChange"),
        object: nil, queue: .main
    ) { [weak self] _ in self?.applyLocalHotkeySettings() }
}

private func applyLocalHotkeySettings() {
    let ud = UserDefaults.standard
    let noteKey  = ud.object(forKey: "createNoteKeyCode") == nil
                   ? kVK_ANSI_N : ud.integer(forKey: "createNoteKeyCode")
    let noteMod  = ud.object(forKey: "createNoteModifiers") == nil
                   ? cmdKey : ud.integer(forKey: "createNoteModifiers")
    let folderKey = ud.object(forKey: "createFolderKeyCode") == nil
                   ? kVK_ANSI_F : ud.integer(forKey: "createFolderKeyCode")
    let folderMod = ud.object(forKey: "createFolderModifiers") == nil
                   ? cmdKey : ud.integer(forKey: "createFolderModifiers")

    localMonitor?.update(
        createNote:   (noteKey,   noteMod),
        createFolder: (folderKey, folderMod)
    )
}
```

---

## ContentView 변경

`body`에 `onReceive` 두 개 추가:

```swift
.onReceive(NotificationCenter.default.publisher(for: .pnCreateNote)) { _ in
    guard let folder = navigationStack.last else { return }
    store.createNote(in: folder)
}
.onReceive(NotificationCenter.default.publisher(for: .pnCreateFolder)) { _ in
    if navigationStack.isEmpty {
        // 루트 화면: 최상위 폴더 생성
        store.createFolder(in: nil)
    } else if let folder = navigationStack.last, store.depth(of: folder) < 2 {
        store.createFolder(in: folder)
    }
    // depth >= 2: 무시
}
```

> `store.createFolder(in: nil)` — NotesStore에서 `NoteNode? = nil` 기본값으로 이미 지원됨.

---

## SettingsView 변경

기존 "단축키" 섹션에 두 행 추가:

```swift
Section("단축키") {
    LabeledContent("패널 토글") { /* 기존 */ }

    LabeledContent("노트 생성") {
        HotkeyRecorderView(
            keyCode: ...,   // createNoteKeyCode, 기본 kVK_ANSI_N
            modifiers: ..., // createNoteModifiers, 기본 cmdKey
            onChange: { code, mods in
                UserDefaults.standard.set(code, forKey: "createNoteKeyCode")
                UserDefaults.standard.set(mods, forKey: "createNoteModifiers")
                NotificationCenter.default.post(name: .init("pn.localHotkeyDidChange"), object: nil)
            }
        )
        .frame(width: 160, height: 28)
    }

    LabeledContent("폴더 생성") {
        HotkeyRecorderView(
            keyCode: ...,   // createFolderKeyCode, 기본 kVK_ANSI_F
            modifiers: ..., // createFolderModifiers, 기본 cmdKey
            onChange: { code, mods in
                UserDefaults.standard.set(code, forKey: "createFolderKeyCode")
                UserDefaults.standard.set(mods, forKey: "createFolderModifiers")
                NotificationCenter.default.post(name: .init("pn.localHotkeyDidChange"), object: nil)
            }
        )
        .frame(width: 160, height: 28)
    }

    Text("패널이 열린 상태에서만 동작합니다.")
        .font(.caption)
        .foregroundStyle(.tertiary)
}
```

---

## 기본값 요약

| 기능 | 기본 단축키 | keyCode | modifiers |
|------|-------------|---------|-----------|
| 패널 토글 | ⌥Space | kVK_Space (49) | optionKey (2048) |
| 노트 생성 | ⌘N | kVK_ANSI_N (45) | cmdKey (256) |
| 폴더 생성 | ⌘F | kVK_ANSI_F (3) | cmdKey (256) |

---

## 유효성 규칙

패널 토글 단축키와 동일한 규칙 적용:
- 수정자(⌘/⌥/⌃/⇧) 최소 1개 필수 (F1–F12 단독 허용)
- Escape: 녹화 취소
- Delete: 기본값 복원
