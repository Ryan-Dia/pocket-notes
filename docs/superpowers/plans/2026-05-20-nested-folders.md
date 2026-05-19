# Nested Folders (3-Level) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 최대 3 레벨 중첩 폴더 지원 — 루트는 폴더 생성만, 내부는 노트(`+`) · 폴더(`folder.badge.plus`) 버튼 분리.

**Architecture:** `ContentView`의 `selectedFolderURL: URL?`을 `navigationStack: [NoteNode]`로 교체. 루트는 기존 `FolderListView`, depth ≥ 1은 신규 `FolderContentsView`로 렌더링. depth는 URL 경로 길이로 계산 (NotesStore 메서드). 버튼 표시는 depth에 따라 조건부.

**Tech Stack:** SwiftUI, AppKit, Foundation (FileManager)

---

## File Map

| 파일 | 변경 |
|------|------|
| `PocketNotes/Storage/NotesStore.swift` | `depth(of:)` + `findFolder(url:)` 추가 |
| `PocketNotes/UI/EditorView.swift` | `NoteCardsView` 제거, `NoteCardView`만 유지 |
| `PocketNotes/UI/FolderContentsView.swift` | 신규 생성 — depth ≥ 1 폴더 내부 뷰 |
| `PocketNotes/UI/ContentView.swift` | 네비게이션 스택으로 교체 |
| `PocketNotes/UI/SidebarView.swift` | 루트 헤더 버튼 + 컨텍스트 메뉴 업데이트 |

---

### Task 1: NotesStore에 depth · findFolder 추가

**Files:**
- Modify: `PocketNotes/Storage/NotesStore.swift`

- [ ] **Step 1: 두 메서드를 `// MARK: - Private` 바로 위에 추가**

```swift
// depth 계산: rootURL 기준 상대 깊이 (최상위 폴더=0, 상위=1, 하위=2)
func depth(of node: NoteNode) -> Int {
    node.url.pathComponents.count - rootURL.pathComponents.count - 1
}

// 폴더 존재 확인 (FolderContentsView의 삭제 감지용)
func findFolder(url: URL) -> NoteNode? {
    findNode(url: url, in: roots)
}
```

- [ ] **Step 2: 빌드 확인**

```bash
xcodebuild -project PocketNotes.xcodeproj -scheme PocketNotes -configuration Debug build -derivedDataPath build/DerivedData 2>&1 | grep -E "error:|BUILD"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 커밋**

```bash
git add PocketNotes/Storage/NotesStore.swift
git commit -m "feat: NotesStore에 depth(of:), findFolder(url:) 추가"
```

---

### Task 2: EditorView — NoteCardsView 제거, NoteCardView 유지

**Files:**
- Modify: `PocketNotes/UI/EditorView.swift`

`NoteCardsView`(폴더 래퍼)는 `FolderContentsView`로 완전 대체되므로 삭제. `NoteCardView`(카드 단위)는 `FolderContentsView`에서 재사용하므로 유지.

- [ ] **Step 1: EditorView.swift를 NoteCardView만 남기도록 교체**

`PocketNotes/UI/EditorView.swift` 전체를 아래로 교체:

```swift
import SwiftUI
import Combine

struct NoteCardView: View {
    @EnvironmentObject var store: NotesStore
    let note: NoteNode

    @State private var text = ""
    @State private var saveTimer: AnyCancellable?
    @FocusState private var isFocused: Bool

    private var dateString: String {
        let res = try? note.url.resourceValues(forKeys: [.contentModificationDateKey])
        guard let date = res?.contentModificationDate else { return "" }
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: date)
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(isFocused ? PNTheme.accent : PNTheme.accent.opacity(0.35))
                .frame(width: 3)
                .animation(.easeInOut(duration: 0.15), value: isFocused)

            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("노트를 작성하세요...")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $text)
                        .font(.system(size: 14))
                        .scrollContentBackground(.hidden)
                        .background(.clear)
                        .frame(minHeight: 90)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .focused($isFocused)
                }

                Divider().opacity(0.12)

                HStack(spacing: 14) {
                    Image(systemName: "textformat")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(dateString)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)

                    Spacer()

                    Button { store.delete(note) } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
        .background(PNTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(isFocused ? 0.12 : 0.06), radius: isFocused ? 8 : 4, x: 0, y: 2)
        .onAppear { text = store.readContent(of: note) }
        .onChange(of: note.url) { _, _ in text = store.readContent(of: note) }
        .onChange(of: text) { scheduleSave() }
    }

    private func scheduleSave() {
        saveTimer?.cancel()
        saveTimer = Just(text)
            .delay(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak store] content in store?.saveContent(content, to: note) }
    }
}
```

- [ ] **Step 2: 빌드 (ContentView가 NoteCardsView 참조 중이라 에러 예상)**

```bash
xcodebuild -project PocketNotes.xcodeproj -scheme PocketNotes -configuration Debug build -derivedDataPath build/DerivedData 2>&1 | grep -E "error:|BUILD"
```

Expected: `NoteCardsView` 관련 에러 — Task 4에서 ContentView 교체 시 해결됨.

---

### Task 3: FolderContentsView 생성

**Files:**
- Create: `PocketNotes/UI/FolderContentsView.swift`

depth ≥ 1인 모든 폴더 내부를 담당. 상단 하위 폴더 섹션 + 하단 노트 섹션. 버튼은 depth에 따라 조건부 표시.

- [ ] **Step 1: 파일 생성**

`PocketNotes/UI/FolderContentsView.swift`:

```swift
import SwiftUI

struct FolderContentsView: View {
    @EnvironmentObject var store: NotesStore
    let folder: NoteNode
    let onBack: () -> Void
    let onSelectSubfolder: (NoteNode) -> Void

    @State private var renaming: NoteNode? = nil
    @State private var renameText = ""

    private var depth: Int { store.depth(of: folder) }
    private var subfolders: [NoteNode] { folder.children?.filter { $0.isFolder } ?? [] }
    private var notes: [NoteNode] { folder.children?.filter { !$0.isFolder } ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.25)
            ScrollView {
                LazyVStack(spacing: 0) {
                    if !subfolders.isEmpty {
                        subfolderSection
                        Divider().opacity(0.25).padding(.vertical, 4)
                    }
                    noteSection
                }
            }
        }
        .background(PNTheme.bg)
        // 현재 폴더가 삭제되면 자동 뒤로 이동
        .onReceive(store.$roots) { _ in
            if store.findFolder(url: folder.url) == nil { onBack() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Button { onBack() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PNTheme.accent)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)

            Text(folder.name)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(PNTheme.heading)
                .lineLimit(1)

            Spacer()

            // 노트 생성: depth ≥ 1이면 항상 표시
            Button { store.createNote(in: folder) } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(PNTheme.accent)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)

            // 폴더 생성: depth < 2일 때만 표시 (depth 2 = 하위 폴더, 더 이상 불가)
            if depth < 2 {
                Button { store.createFolder(in: folder) } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(PNTheme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    // MARK: - Subfolder Section

    private var subfolderSection: some View {
        ForEach(subfolders) { node in
            if renaming?.id == node.id {
                renameRow(for: node)
            } else {
                subfolderRow(for: node)
            }
            Divider()
                .opacity(0.2)
                .padding(.leading, 56)
        }
    }

    private func subfolderRow(for node: NoteNode) -> some View {
        let noteCount = node.children?.filter { !$0.isFolder }.count ?? 0
        return HStack(spacing: 14) {
            Image(systemName: "folder")
                .font(.system(size: 20))
                .foregroundStyle(PNTheme.accent)
                .frame(width: 28)
            Text(node.name)
                .font(.system(size: 16))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer()
            Text("\(noteCount)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(PNTheme.accent.opacity(0.7))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .background(PNTheme.bg)
        .onTapGesture { onSelectSubfolder(node) }
        .contextMenu {
            Button("새 노트") { store.createNote(in: node) }
            Button("이름 변경") {
                renameText = node.name
                renaming = node
            }
            Divider()
            Button("삭제", role: .destructive) { store.delete(node) }
        }
    }

    private func renameRow(for node: NoteNode) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "folder")
                .font(.system(size: 20))
                .foregroundStyle(PNTheme.accent)
                .frame(width: 28)
            TextField("폴더 이름", text: $renameText)
                .onSubmit {
                    let t = renameText.trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty { store.rename(node, to: t) }
                    renaming = nil
                }
                .onExitCommand { renaming = nil }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Note Section

    private var noteSection: some View {
        Group {
            ForEach(notes) { note in
                NoteCardView(note: note)
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
            }
            if notes.isEmpty && subfolders.isEmpty {
                emptyHint
            }
        }
        .padding(.bottom, 12)
    }

    private var emptyHint: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(PNTheme.accent.opacity(0.4))
            Text("노트를 추가하세요")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
```

- [ ] **Step 2: Xcode 프로젝트에 파일 추가**

Xcode에서 `PocketNotes/UI` 그룹에 `FolderContentsView.swift` 드래그 추가.
또는 아래 확인으로 자동 포함 여부 체크 (xcodeproj가 glob 기반이면 자동):

```bash
grep -r "FolderContentsView" /Users/wonmac/code/pocket-notes/PocketNotes.xcodeproj/ | head -3
```

결과가 없으면 Xcode에서 수동으로 파일을 타겟에 추가해야 함.

---

### Task 4: ContentView 네비게이션 스택으로 교체

**Files:**
- Modify: `PocketNotes/UI/ContentView.swift`

- [ ] **Step 1: ContentView.swift 전체 교체**

```swift
import SwiftUI

enum PNTheme {
    static let bg      = Color(red: 0.969, green: 0.945, blue: 0.890)
    static let card    = Color(red: 0.984, green: 0.969, blue: 0.937)
    static let accent  = Color(red: 0.753, green: 0.388, blue: 0.314)
    static let heading = Color(red: 0.106, green: 0.313, blue: 0.376)
}

struct ContentView: View {
    @EnvironmentObject var store: NotesStore
    @State private var navigationStack: [NoteNode] = []

    var body: some View {
        ZStack {
            PNTheme.bg.ignoresSafeArea()
            currentView
                .id(navigationStack.count) // count 변경 시 전환 애니메이션 트리거
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.18), value: navigationStack.count)
    }

    @ViewBuilder
    private var currentView: some View {
        if navigationStack.isEmpty {
            FolderListView { folder in
                withAnimation { navigationStack.append(folder) }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .leading),
                removal: .move(edge: .leading)
            ))
        } else {
            FolderContentsView(
                folder: navigationStack.last!,
                onBack: {
                    withAnimation { navigationStack.removeLast() }
                },
                onSelectSubfolder: { subfolder in
                    withAnimation { navigationStack.append(subfolder) }
                }
            )
            .transition(.asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .trailing)
            ))
        }
    }
}
```

- [ ] **Step 2: 빌드 확인**

```bash
xcodebuild -project PocketNotes.xcodeproj -scheme PocketNotes -configuration Debug build -derivedDataPath build/DerivedData 2>&1 | grep -E "error:|BUILD"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 커밋 (Task 2~4 묶음)**

```bash
git add PocketNotes/UI/EditorView.swift PocketNotes/UI/FolderContentsView.swift PocketNotes/UI/ContentView.swift
git commit -m "feat: FolderContentsView 추가 및 네비게이션 스택 기반 중첩 폴더 탐색 구현"
```

---

### Task 5: SidebarView 루트 버튼 · 컨텍스트 메뉴 업데이트

**Files:**
- Modify: `PocketNotes/UI/SidebarView.swift`

루트 헤더의 `plus` → `folder.badge.plus`. 폴더 row 컨텍스트 메뉴에 "새 하위 폴더" 추가.

- [ ] **Step 1: 헤더 버튼 아이콘 변경**

`header` 계산 프로퍼티에서:

기존:
```swift
Button { store.createFolder() } label: {
    Image(systemName: "plus")
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(PNTheme.accent)
}
.buttonStyle(.plain)
```

변경:
```swift
Button { store.createFolder() } label: {
    Image(systemName: "folder.badge.plus")
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(PNTheme.accent)
}
.buttonStyle(.plain)
```

- [ ] **Step 2: folderRow 컨텍스트 메뉴에 "새 하위 폴더" 추가**

`folderRow(for:)` 내 `.contextMenu`:

기존:
```swift
.contextMenu {
    Button("새 노트") { store.createNote(in: node) }
    Divider()
    Button("이름 변경") {
        renameText = node.name
        renaming = node
    }
    Divider()
    Button("삭제", role: .destructive) { store.delete(node) }
}
```

변경:
```swift
.contextMenu {
    Button("새 노트") { store.createNote(in: node) }
    Button("새 하위 폴더") { store.createFolder(in: node) }
    Divider()
    Button("이름 변경") {
        renameText = node.name
        renaming = node
    }
    Divider()
    Button("삭제", role: .destructive) { store.delete(node) }
}
```

- [ ] **Step 3: 빌드 확인**

```bash
xcodebuild -project PocketNotes.xcodeproj -scheme PocketNotes -configuration Debug build -derivedDataPath build/DerivedData 2>&1 | grep -E "error:|BUILD"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 커밋**

```bash
git add PocketNotes/UI/SidebarView.swift
git commit -m "feat: 루트 헤더 folder.badge.plus 버튼, 컨텍스트 메뉴 새 하위 폴더 추가"
```

---

### Task 6: 앱 실행 및 수동 검증

- [ ] **Step 1: 빌드 후 실행**

```bash
pkill -x PocketNotes 2>/dev/null
xcodebuild -project PocketNotes.xcodeproj -scheme PocketNotes -configuration Debug build -derivedDataPath build/DerivedData 2>&1 | tail -3
open build/DerivedData/Build/Products/Debug/PocketNotes.app
```

- [ ] **Step 2: 수동 체크리스트**

루트 화면:
- [ ] 헤더에 `folder.badge.plus` 버튼만 있음 (노트 `+` 없음)
- [ ] 탭 → 최상위 폴더 생성
- [ ] 폴더 우클릭 → "새 노트", "새 하위 폴더" 메뉴 표시

depth-1 폴더 내부:
- [ ] `+`(노트) · `folder.badge.plus`(폴더) 버튼 둘 다 표시
- [ ] `+` → 노트 카드 생성
- [ ] `folder.badge.plus` → 하위 폴더 생성 후 섹션 분리 표시
- [ ] 하위 폴더 탭 → depth-2 뷰로 이동

depth-2 폴더 내부:
- [ ] `+`(노트) 버튼만 있음 (`folder.badge.plus` 없음)
- [ ] `←` → depth-1로 복귀
- [ ] `←` 한 번 더 → 루트로 복귀

삭제 감지:
- [ ] depth-2 폴더 안에 있을 때 Finder에서 해당 폴더 삭제 → 자동으로 depth-1로 이동

- [ ] **Step 3: 푸시**

```bash
git push
```
