# Markdown Preview Toggle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 각 노트 카드에 편집(TextEditor) ↔ 마크다운 미리보기(MarkdownPreview) 토글 버튼을 추가한다.

**Architecture:** `NoteCardView`에 `@State isPreviewMode` 플래그를 추가하고, 카드 본문 영역을 조건부로 TextEditor 또는 MarkdownPreview로 전환한다. 툴바의 정적 아이콘을 토글 버튼으로 교체한다. MarkdownPreview는 풀 마크다운 파싱을 사용하도록 업그레이드한다.

**Tech Stack:** SwiftUI, macOS, AttributedString (Foundation)

---

## File Map

| 파일 | 변경 유형 | 역할 |
|------|----------|------|
| `PocketNotes/UI/MarkdownPreview.swift` | Modify | 풀 마크다운 파싱으로 업그레이드 |
| `PocketNotes/UI/EditorView.swift` | Modify | isPreviewMode 상태 + 토글 버튼 + 조건부 뷰 전환 |

> 이 프로젝트에는 기존 테스트 인프라가 없다. 각 태스크는 빌드 후 앱 실행으로 수동 검증한다.

---

### Task 1: MarkdownPreview 풀 마크다운 파싱으로 업그레이드

**Files:**
- Modify: `PocketNotes/UI/MarkdownPreview.swift`

- [ ] **Step 1: 현재 파일 확인**

```swift
// 현재 MarkdownPreview.swift 내용 (확인용):
// options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
// → 인라인 서식만 파싱, 헤더/리스트 등 블록 문법 미지원
```

- [ ] **Step 2: `inlineOnlyPreservingWhitespace` 옵션 제거**

`PocketNotes/UI/MarkdownPreview.swift` 전체를 아래 내용으로 교체한다:

```swift
import SwiftUI

struct MarkdownPreview: View {
    let text: String

    private var attributed: AttributedString {
        (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }

    var body: some View {
        ScrollView {
            Text(attributed)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
    }
}
```

- [ ] **Step 3: 빌드 확인**

```bash
xcodebuild -scheme PocketNotes -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 커밋**

```bash
git add PocketNotes/UI/MarkdownPreview.swift
git commit -m "feat: MarkdownPreview 풀 마크다운 파싱으로 업그레이드"
```

---

### Task 2: NoteCardView에 isPreviewMode 상태 및 토글 버튼 추가

**Files:**
- Modify: `PocketNotes/UI/EditorView.swift`

- [ ] **Step 1: `@State private var isPreviewMode = false` 추가**

`EditorView.swift`의 기존 `@State` 선언들 아래에 추가한다. 변경 전:

```swift
@State private var isHandleHovered = false
```

변경 후:

```swift
@State private var isHandleHovered = false
@State private var isPreviewMode = false
```

- [ ] **Step 2: 본문 영역을 조건부 뷰 전환으로 교체**

기존 `ZStack(alignment: .topLeading)` 블록을 아래로 교체한다.

변경 전:

```swift
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
```

변경 후:

```swift
if isPreviewMode {
    MarkdownPreview(text: text)
        .frame(minHeight: 90)
} else {
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
}
```

- [ ] **Step 3: 툴바 `textformat` 정적 아이콘을 토글 버튼으로 교체**

변경 전:

```swift
Image(systemName: "textformat")
    .font(.system(size: 12))
    .foregroundStyle(.secondary)
```

변경 후:

```swift
Button {
    isPreviewMode.toggle()
} label: {
    Image(systemName: isPreviewMode ? "eye.fill" : "pencil")
        .font(.system(size: 12))
        .foregroundStyle(isPreviewMode ? theme.accent : .secondary)
}
.buttonStyle(.plain)
```

- [ ] **Step 4: 빌드 확인**

```bash
xcodebuild -scheme PocketNotes -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 수동 검증**

앱을 실행해 다음을 확인한다:

1. 노트 카드 툴바 왼쪽에 `pencil` 아이콘 버튼이 보인다
2. 클릭하면 `eye.fill` 아이콘으로 바뀌고 accent 색상으로 강조된다
3. 마크다운 문법(`**굵게**`, `# 제목`, `- 항목`)으로 작성 후 토글하면 렌더링된 텍스트가 보인다
4. 다시 클릭하면 편집 모드로 돌아오고 텍스트 내용이 유지된다
5. 카드 A를 미리보기로 전환해도 카드 B는 편집 모드 그대로다

- [ ] **Step 6: 커밋**

```bash
git add PocketNotes/UI/EditorView.swift
git commit -m "feat: 노트 카드 마크다운 미리보기 토글 추가"
```
