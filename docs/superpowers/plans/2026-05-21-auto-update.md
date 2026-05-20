# Auto Update (Sparkle) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sparkle 프레임워크를 사용해 메뉴바 우클릭 메뉴와 설정창에서 업데이트를 확인하고 설치할 수 있는 자동 업데이트 기능을 추가한다.

**Architecture:** `SPUStandardUpdaterController`를 AppDelegate에서 소유하고, 메뉴바 컨텍스트 메뉴와 SettingsView 양쪽에서 `checkForUpdates()` 를 호출한다. appcast.xml은 `docs/appcast.xml`에 두고 GitHub raw URL로 Sparkle이 폴링한다.

**Tech Stack:** Sparkle 2.x (SPM), XcodeGen (project.yml), SwiftUI + AppKit

---

## 파일 맵

| 파일 | 변경 |
|---|---|
| `project.yml` | Sparkle SPM 패키지 + 타겟 의존성 추가 |
| `PocketNotes/Info.plist` (project.yml 경유) | `SUFeedURL`, `SUPublicEDKey` 추가 |
| `PocketNotes/AppDelegate.swift` | `SPUStandardUpdaterController` 초기화, 메뉴 항목 추가 |
| `PocketNotes/Settings/SettingsView.swift` | "업데이트" 섹션 추가, `onCheckForUpdates` 파라미터 추가 |
| `docs/appcast.xml` | 신규 생성 (v0.1.0 초기 릴리즈 정보) |
| `Scripts/generate-appcast.sh` | 신규 생성 (릴리즈 시 appcast.xml 갱신 스크립트) |

---

## Task 1: Sparkle SPM 의존성 추가

**Files:**
- Modify: `project.yml`

- [ ] **Step 1: project.yml에 Sparkle 패키지 선언 추가**

`targets:` 블록 바로 위에 `packages:` 섹션을 추가하고, 타겟에 의존성을 추가한다.

```yaml
# project.yml 전체 (변경 후)
name: PocketNotes
options:
  bundleIdPrefix: com.ryandia
  deploymentTarget:
    macOS: "14.0"
  xcodeVersion: "16.0"
  generateEmptyDirectories: true

settings:
  base:
    SWIFT_VERSION: "5.10"
    MACOSX_DEPLOYMENT_TARGET: "14.0"
    PRODUCT_BUNDLE_IDENTIFIER: com.ryandia.PocketNotes
    PRODUCT_NAME: PocketNotes
    MARKETING_VERSION: "0.1.0"
    CURRENT_PROJECT_VERSION: "1"
    CODE_SIGN_STYLE: Automatic
    CODE_SIGN_IDENTITY: "-"
    DEVELOPMENT_TEAM: ""

packages:
  Sparkle:
    url: https://github.com/sparkle-project/Sparkle
    from: 2.7.0

targets:
  PocketNotes:
    type: application
    platform: macOS
    deploymentTarget: "14.0"
    sources:
      - path: PocketNotes
        excludes:
          - "**/*.plist"
    info:
      path: PocketNotes/Info.plist
      properties:
        CFBundleName: PocketNotes
        CFBundleDisplayName: PocketNotes
        CFBundleIdentifier: com.ryandia.PocketNotes
        CFBundleVersion: "1"
        CFBundleShortVersionString: "0.1.0"
        NSPrincipalClass: NSApplication
        LSMinimumSystemVersion: "14.0"
        LSUIElement: true
        NSHumanReadableCopyright: "Copyright © 2026 Ryan-Dia. All rights reserved."
        CFBundleIconFile: AppIcon
    entitlements:
      path: PocketNotes/PocketNotes.entitlements
    dependencies:
      - package: Sparkle
    settings:
      base:
        CODE_SIGN_ENTITLEMENTS: PocketNotes/PocketNotes.entitlements
```

- [ ] **Step 2: XcodeGen으로 xcodeproj 재생성**

```bash
xcodegen generate
```

Expected: `Generating plists...`, `Generating project...`, `⚙️  Generated: PocketNotes.xcodeproj` 출력

- [ ] **Step 3: 빌드 확인 (Sparkle 패키지 다운로드 포함)**

```bash
xcodebuild -project PocketNotes.xcodeproj -scheme PocketNotes -destination 'platform=macOS' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 커밋**

```bash
git add project.yml PocketNotes.xcodeproj
git commit -m "feat: Sparkle 2 SPM 의존성 추가"
```

---

## Task 2: EdDSA 키 생성 및 Info.plist 업데이트

**Files:**
- Modify: `project.yml` (SUFeedURL, SUPublicEDKey 추가)

- [ ] **Step 1: Sparkle Tools 다운로드**

Sparkle GitHub Releases에서 최신 `Sparkle-2.x.x.tar.xz` 다운로드 후 압축 해제:

```bash
cd /tmp && curl -L -o sparkle.tar.xz \
  https://github.com/sparkle-project/Sparkle/releases/download/2.7.2/Sparkle-2.7.2.tar.xz \
  && mkdir -p sparkle-tools && tar -xf sparkle.tar.xz -C sparkle-tools
ls /tmp/sparkle-tools/bin/
```

Expected: `generate_appcast  generate_keys  sign_update` 파일 존재

- [ ] **Step 2: EdDSA 키 쌍 생성**

```bash
/tmp/sparkle-tools/bin/generate_keys
```

Expected: 다음과 유사한 출력:
```
A private key has been generated and saved to your Keychain.
If you lose access to your Keychain, you will not be able to sign future updates.

Public key (SUPublicEDKey):
<BASE64_PUBLIC_KEY>
```

출력에서 `<BASE64_PUBLIC_KEY>` 값을 복사해둔다.

- [ ] **Step 3: project.yml에 SUFeedURL과 SUPublicEDKey 추가**

`project.yml`의 `info.properties` 섹션 내 `CFBundleIconFile` 아래에 추가:

```yaml
        SUFeedURL: "https://raw.githubusercontent.com/Ryan-Dia/pocket-notes/main/docs/appcast.xml"
        SUPublicEDKey: "<Step 2에서 복사한 BASE64_PUBLIC_KEY>"
```

- [ ] **Step 4: XcodeGen 재생성 후 빌드 확인**

```bash
xcodegen generate && xcodebuild -project PocketNotes.xcodeproj -scheme PocketNotes -destination 'platform=macOS' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Info.plist에 키가 들어갔는지 확인**

```bash
/usr/libexec/PlistBuddy -c "Print SUFeedURL" PocketNotes/Info.plist
/usr/libexec/PlistBuddy -c "Print SUPublicEDKey" PocketNotes/Info.plist
```

Expected: 각각 URL과 공개키 출력

- [ ] **Step 6: 커밋 (비밀키는 Keychain에만, 공개키는 커밋)**

```bash
git add project.yml PocketNotes.xcodeproj
git commit -m "feat: Info.plist에 Sparkle SUFeedURL 및 SUPublicEDKey 추가"
```

---

## Task 3: AppDelegate에 SPUStandardUpdaterController 통합

**Files:**
- Modify: `PocketNotes/AppDelegate.swift`

- [ ] **Step 1: AppDelegate.swift 수정**

파일 전체를 다음으로 교체한다:

```swift
import AppKit
import Carbon
import SwiftUI
import Sparkle

final class AppDelegate: NSObject, NSApplicationDelegate {
    let notesStore = NotesStore()
    private var panelController: PanelController?
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
            }).environmentObject(notesStore)
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
```

- [ ] **Step 2: 빌드 확인**

```bash
xcodebuild -project PocketNotes.xcodeproj -scheme PocketNotes -destination 'platform=macOS' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 커밋**

```bash
git add PocketNotes/AppDelegate.swift
git commit -m "feat: AppDelegate에 SPUStandardUpdaterController 및 메뉴바 업데이트 항목 추가"
```

---

## Task 4: SettingsView에 업데이트 섹션 추가

**Files:**
- Modify: `PocketNotes/Settings/SettingsView.swift`

- [ ] **Step 1: SettingsView.swift 수정**

`struct SettingsView: View {` 선언 바로 아래, `@EnvironmentObject` 위에 파라미터 추가. `저장 위치` 섹션 뒤, `.formStyle` 전에 업데이트 섹션 추가. frame height를 460 → 520으로 조정:

```swift
import SwiftUI
import Carbon

struct SettingsView: View {
    var onCheckForUpdates: () -> Void = {}

    @EnvironmentObject var store: NotesStore

    @AppStorage("panelEdge") private var panelEdge = "right"
    @AppStorage("hideOnLostFocus") private var hideOnLostFocus = false
    @AppStorage("hotkeyKeyCode") private var hotkeyKeyCode = 0
    @AppStorage("hotkeyModifiers") private var hotkeyModifiers = 0
    @AppStorage("createNoteKeyCode")     private var createNoteKeyCode     = 0
    @AppStorage("createNoteModifiers")   private var createNoteModifiers   = 0
    @AppStorage("createFolderKeyCode")   private var createFolderKeyCode   = 0
    @AppStorage("createFolderModifiers") private var createFolderModifiers = 0

    var body: some View {
        Form {
            Section("패널") {
                Picker("슬라이드 방향", selection: $panelEdge) {
                    Text("오른쪽").tag("right")
                    Text("왼쪽").tag("left")
                }
                .pickerStyle(.segmented)

                Toggle("다른 앱 클릭 시 자동 닫기", isOn: $hideOnLostFocus)
            }

            Section("단축키") {
                LabeledContent("패널 토글") {
                    HotkeyRecorderView(
                        keyCode: UserDefaults.standard.object(forKey: "hotkeyKeyCode") == nil ? kVK_Space : hotkeyKeyCode,
                        modifiers: UserDefaults.standard.object(forKey: "hotkeyModifiers") == nil ? optionKey : hotkeyModifiers,
                        onChange: { code, mods in
                            UserDefaults.standard.set(code, forKey: "hotkeyKeyCode")
                            UserDefaults.standard.set(mods, forKey: "hotkeyModifiers")
                            NotificationCenter.default.post(name: .init("pn.hotkeyDidChange"), object: nil)
                        }
                    )
                    .frame(width: 160, height: 28)
                }
                LabeledContent("노트 생성") {
                    HotkeyRecorderView(
                        keyCode: UserDefaults.standard.object(forKey: "createNoteKeyCode") == nil ? kVK_ANSI_N : createNoteKeyCode,
                        modifiers: UserDefaults.standard.object(forKey: "createNoteModifiers") == nil ? cmdKey : createNoteModifiers,
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
                        keyCode: UserDefaults.standard.object(forKey: "createFolderKeyCode") == nil ? kVK_ANSI_F : createFolderKeyCode,
                        modifiers: UserDefaults.standard.object(forKey: "createFolderModifiers") == nil ? cmdKey : createFolderModifiers,
                        onChange: { code, mods in
                            UserDefaults.standard.set(code, forKey: "createFolderKeyCode")
                            UserDefaults.standard.set(mods, forKey: "createFolderModifiers")
                            NotificationCenter.default.post(name: .init("pn.localHotkeyDidChange"), object: nil)
                        }
                    )
                    .frame(width: 160, height: 28)
                }
                Text("패널이 열린 상태에서만 동작합니다. 클릭 후 키 조합 입력, Delete로 기본값 복원.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Section("저장 위치") {
                LabeledContent("노트 폴더") {
                    Text(store.rootURL.path)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .foregroundStyle(.secondary)
                }
                Button("폴더 변경...") { choosFolder() }
                Button("Finder에서 열기") {
                    NSWorkspace.shared.open(store.rootURL)
                }
            }

            Section("업데이트") {
                LabeledContent("현재 버전") {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                        .foregroundStyle(.secondary)
                }
                Button("업데이트 확인") { onCheckForUpdates() }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 520)
        .navigationTitle("설정")
    }

    private func choosFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "선택"
        if panel.runModal() == .OK, let url = panel.url {
            store.rootURL = url
        }
    }
}
```

- [ ] **Step 2: 빌드 확인**

```bash
xcodebuild -project PocketNotes.xcodeproj -scheme PocketNotes -destination 'platform=macOS' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 커밋**

```bash
git add PocketNotes/Settings/SettingsView.swift
git commit -m "feat: SettingsView에 업데이트 섹션 추가"
```

---

## Task 5: docs/appcast.xml 초기 파일 생성

**Files:**
- Create: `docs/appcast.xml`

- [ ] **Step 1: 기존 DMG 서명**

루트 디렉토리에 `PocketNotes-0.1.0.dmg`가 있다. `sign_update`로 서명값과 파일 크기를 얻는다:

```bash
/tmp/sparkle-tools/bin/sign_update PocketNotes-0.1.0.dmg
```

Expected 출력 (값은 실제로 다름):
```
    sparkle:edSignature="ABCD1234...==" length="12345678"
```

출력에서 `edSignature` 값과 `length` 값을 복사해둔다.

- [ ] **Step 2: docs/appcast.xml 생성**

아래 템플릿에서 `SIGNATURE`와 `LENGTH`를 Step 1 출력값으로 교체한다:

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>PocketNotes</title>
    <item>
      <title>0.1.0</title>
      <pubDate>Wed, 21 May 2026 00:00:00 +0000</pubDate>
      <sparkle:version>1</sparkle:version>
      <sparkle:shortVersionString>0.1.0</sparkle:shortVersionString>
      <enclosure
        url="https://github.com/Ryan-Dia/pocket-notes/releases/download/v0.1.0/PocketNotes-0.1.0.dmg"
        sparkle:edSignature="SIGNATURE"
        length="LENGTH"
        type="application/octet-stream"/>
    </item>
  </channel>
</rss>
```

- [ ] **Step 3: XML 유효성 확인**

```bash
xmllint --noout docs/appcast.xml && echo "XML valid"
```

Expected: `XML valid`

- [ ] **Step 4: 커밋**

```bash
git add docs/appcast.xml
git commit -m "feat: 초기 appcast.xml 추가 (v0.1.0)"
```

---

## Task 6: Scripts/generate-appcast.sh 생성

**Files:**
- Create: `Scripts/generate-appcast.sh`

- [ ] **Step 1: 스크립트 작성**

```bash
#!/bin/bash
# 사용법: ./Scripts/generate-appcast.sh <version> <dmg_path>
# 사전 조건: SPARKLE_TOOLS_PATH 환경변수로 Sparkle bin 디렉토리 경로 지정
#   예) export SPARKLE_TOOLS_PATH=/tmp/sparkle-tools/bin
# 릴리즈마다 docs/appcast.xml을 갱신하고 커밋한다.

set -e

VERSION="$1"
DMG_PATH="$2"
TOOLS="${SPARKLE_TOOLS_PATH:-/tmp/sparkle-tools/bin}"
APPCAST_PATH="docs/appcast.xml"
DOWNLOAD_URL="https://github.com/Ryan-Dia/pocket-notes/releases/download/v${VERSION}/PocketNotes-${VERSION}.dmg"

if [ -z "$VERSION" ] || [ -z "$DMG_PATH" ]; then
    echo "Usage: $0 <version> <dmg_path>"
    echo "Example: $0 0.2.0 PocketNotes-0.2.0.dmg"
    exit 1
fi

if [ ! -f "$DMG_PATH" ]; then
    echo "Error: DMG not found at $DMG_PATH"
    exit 1
fi

if [ ! -x "$TOOLS/sign_update" ]; then
    echo "Error: sign_update not found at $TOOLS/sign_update"
    echo "Download Sparkle tools: https://github.com/sparkle-project/Sparkle/releases"
    exit 1
fi

echo "→ DMG 서명 중..."
SIGN_OUTPUT=$("$TOOLS/sign_update" "$DMG_PATH")
SIGNATURE=$(echo "$SIGN_OUTPUT" | grep -o 'sparkle:edSignature="[^"]*"' | cut -d'"' -f2)
LENGTH=$(echo "$SIGN_OUTPUT" | grep -o 'length="[^"]*"' | cut -d'"' -f2)
PUB_DATE=$(date -u "+%a, %d %b %Y %H:%M:%S +0000")

cat > "$APPCAST_PATH" << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>PocketNotes</title>
    <item>
      <title>${VERSION}</title>
      <pubDate>${PUB_DATE}</pubDate>
      <sparkle:version>${VERSION}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <enclosure
        url="${DOWNLOAD_URL}"
        sparkle:edSignature="${SIGNATURE}"
        length="${LENGTH}"
        type="application/octet-stream"/>
    </item>
  </channel>
</rss>
EOF

xmllint --noout "$APPCAST_PATH"
echo "✓ $APPCAST_PATH 갱신 완료 (v${VERSION})"
echo ""
echo "다음 단계:"
echo "  git add $APPCAST_PATH && git commit -m 'chore: appcast.xml 갱신 (v${VERSION})'"
echo "  GitHub Releases에 $DMG_PATH 업로드"
```

- [ ] **Step 2: 실행 권한 부여**

```bash
chmod +x Scripts/generate-appcast.sh
```

- [ ] **Step 3: 스크립트 dry-run 확인 (파라미터 누락 오류 확인)**

```bash
./Scripts/generate-appcast.sh
```

Expected:
```
Usage: ./Scripts/generate-appcast.sh <version> <dmg_path>
Example: ./Scripts/generate-appcast.sh 0.2.0 PocketNotes-0.2.0.dmg
```

- [ ] **Step 4: 커밋**

```bash
git add Scripts/generate-appcast.sh
git commit -m "feat: 릴리즈 시 appcast.xml 갱신 스크립트 추가"
```

---

## Task 7: 수동 동작 검증

- [ ] **Step 1: 앱 빌드 및 실행**

```bash
xcodebuild -project PocketNotes.xcodeproj -scheme PocketNotes -destination 'platform=macOS' build 2>&1 | tail -3
open build/Build/Products/Debug/PocketNotes.app
```

- [ ] **Step 2: 메뉴바 우클릭 메뉴 확인**

메뉴바 아이콘을 우클릭 → "업데이트 확인..." 항목이 보이는지 확인

- [ ] **Step 3: 설정창 업데이트 섹션 확인**

메뉴바 우클릭 → "설정..." → "업데이트" 섹션에 현재 버전과 "업데이트 확인" 버튼이 보이는지 확인

- [ ] **Step 4: 업데이트 확인 동작 확인**

"업데이트 확인" 버튼 또는 메뉴 항목 클릭 → Sparkle 다이얼로그 또는 "최신 버전입니다" 알림이 표시되는지 확인

  - appcast.xml이 GitHub에 아직 푸시되지 않은 경우 네트워크 오류 알림이 뜰 수 있음 — 정상
  - appcast.xml을 GitHub에 푸시한 뒤 재확인 시 "최신 버전입니다" 메시지 확인

---

## 릴리즈 체크리스트 (구현 완료 후 참고)

다음 버전(예: 0.2.0) 배포 시:

```bash
# 1. Info.plist 버전 올리기 (project.yml의 MARKETING_VERSION, CFBundleShortVersionString)
# 2. DMG 빌드
./Scripts/build-dmg.sh

# 3. appcast.xml 갱신
export SPARKLE_TOOLS_PATH=/tmp/sparkle-tools/bin
./Scripts/generate-appcast.sh 0.2.0 PocketNotes-0.2.0.dmg

# 4. 커밋 및 푸시
git add docs/appcast.xml
git commit -m "chore: appcast.xml 갱신 (v0.2.0)"
git push

# 5. GitHub Releases에 DMG 업로드 + v0.2.0 태그 생성
```
