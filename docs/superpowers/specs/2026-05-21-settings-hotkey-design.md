# 커스텀 글로벌 단축키 설정 기능 설계

## 목표

설정창에서 PocketNotes 패널 토글 단축키를 사용자가 직접 변경할 수 있게 한다.  
변경 즉시(재시작 없이) 새 단축키가 적용된다.

## 아키텍처

### 파일 구조

| 파일 | 역할 |
|------|------|
| `Settings/HotkeyRecorderView.swift` | 키 녹화 UI 컴포넌트 (신규) |
| `Hotkey/GlobalHotkey.swift` | `update(keyCode:modifiers:)` 추가 |
| `AppDelegate.swift` | 단축키 변경 시 `hotkey?.update()` 연결 |
| `Settings/SettingsView.swift` | 하드코딩 텍스트 → `HotkeyRecorderView`로 교체 |

---

## HotkeyRecorderView

`NSViewRepresentable`로 구현. 내부에 `RecorderNSView`(NSView 서브클래스)를 포함한다.

### 상태

| 상태 | 표시 |
|------|------|
| idle | 현재 단축키 문자열 (예: `⌥Space`) |
| recording | `"키를 누르세요..."` (파란 테두리) |

### 인터페이스

```swift
HotkeyRecorderView(
    keyCode: Int,       // UserDefaults에서 읽은 현재 keyCode
    modifiers: Int,     // UserDefaults에서 읽은 현재 modifiers
    onChange: (Int, Int) -> Void  // (keyCode, modifiers) 저장 + 재등록 트리거
)
```

### 키 입력 처리 (RecorderNSView.keyDown)

1. `Escape` → 녹화 취소, idle 상태로 복귀
2. `Delete/BackSpace` → 단축키 초기화 (기본값 ⌥Space로 복원)
3. 그 외 키:
   - F1–F12 (`keyCode 122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111`) → 수정자 없어도 허용
   - 일반 키 → 수정자(⌘/⌥/⌃/⇧) 최소 1개 필수, 없으면 무시
4. 유효한 조합 → `onChange(keyCode, modifiers)` 호출 → idle 상태로 복귀

### 키 문자열 변환

`keyCode`와 `modifiers`(Carbon `UInt32`)를 사람이 읽을 수 있는 문자열로 변환하는 헬퍼:

```swift
static func displayString(keyCode: Int, modifiers: Int) -> String
// 예: "⌥Space", "⌘⇧N", "F5"
```

Carbon modifier 비트 → SF Symbol 문자 매핑:
- `cmdKey` → `⌘`
- `optionKey` → `⌥`
- `controlKey` → `⌃`
- `shiftKey` → `⇧`

keyCode → 문자 매핑은 주요 키 (Space, 알파벳, 숫자, F1–F12, 방향키 등) 포함.

---

## GlobalHotkey 변경

### 추가 메서드

```swift
func update(keyCode: Int, modifiers: Int) {
    unregister()
    // keyCode, modifiers를 인자로 받아 재등록
    register(keyCode: keyCode, modifiers: modifiers)
}
```

기존 `register()`를 파라미터를 받는 `register(keyCode:modifiers:)`로 리팩터.  
`init` 시에는 UserDefaults 값을 읽어 `register(keyCode:modifiers:)` 호출.

---

## AppDelegate 변경

`PocketNotesApp.swift`가 SwiftUI `Settings` scene에서 `SettingsView`를 직접 생성하므로,  
클로저 주입 대신 **NotificationCenter**를 사용한다.

`HotkeyRecorderView.onChange`에서:
1. UserDefaults에 저장
2. `Notification.Name("pn.hotkeyDidChange")` 포스트

`AppDelegate.setupHotkey()`에서 해당 Notification을 구독:
```swift
NotificationCenter.default.addObserver(
    forName: Notification.Name("pn.hotkeyDidChange"),
    object: nil,
    queue: .main
) { [weak self] _ in
    let keyCode = UserDefaults.standard.integer(forKey: "hotkeyKeyCode")
    let modifiers = UserDefaults.standard.integer(forKey: "hotkeyModifiers")
    self?.hotkey?.update(keyCode: keyCode, modifiers: modifiers)
}
```

---

## SettingsView 변경

기존 "단축키" 섹션:
```swift
// 변경 전
LabeledContent("패널 토글") {
    Text("⌥Space").foregroundStyle(.secondary)
}
Text("v2에서 커스텀 단축키 지원 예정")
```

변경 후:
```swift
LabeledContent("패널 토글") {
    HotkeyRecorderView(
        keyCode: currentKeyCode,
        modifiers: currentModifiers,
        onChange: { keyCode, modifiers in
            UserDefaults.standard.set(keyCode, forKey: "hotkeyKeyCode")
            UserDefaults.standard.set(modifiers, forKey: "hotkeyModifiers")
            NotificationCenter.default.post(name: .init("pn.hotkeyDidChange"), object: nil)
        }
    )
}
```

`currentKeyCode`, `currentModifiers`는 `@AppStorage`로 UserDefaults에서 직접 읽음.

---

## 유효성 규칙 요약

| 입력 | 허용 여부 |
|------|-----------|
| F1–F12 단독 | ✅ 허용 |
| 수정자 + 일반 키 (예: ⌥Space, ⌘N) | ✅ 허용 |
| 수정자 없는 일반 키 (예: N만) | ❌ 무시 |
| Escape | ❌ 녹화 취소 |
| Delete/BackSpace | ⏮ 기본값 복원 (⌥Space) |

---

## 기본값

- `hotkeyKeyCode`: `kVK_Space` (49)
- `hotkeyModifiers`: `optionKey` (2048)
- 표시: `⌥Space`
