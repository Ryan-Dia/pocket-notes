# WKWebView 마크다운 미리보기 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** MarkdownPreview를 WKWebView 기반으로 교체하고, 포커스를 잃으면 자동 미리보기로 전환하며 미리보기 클릭 시 편집 모드로 복귀한다.

**Architecture:** 기존 `MarkdownPreview.swift` 파일을 `MarkdownWebView` (NSViewRepresentable)로 교체한다. Swift 인라인 마크다운 파서로 HTML을 생성하고 WKWebView로 렌더링한다. `NoteCardView`에서 `@FocusState` 변화를 감지해 포커스 이탈 시 자동 미리보기 전환하고, WKWebView의 `NSClickGestureRecognizer`로 클릭 시 편집 모드로 복귀한다.

**Tech Stack:** SwiftUI, WebKit (WKWebView, NSViewRepresentable), NSClickGestureRecognizer

> **주의:** `MarkdownPreview.swift`는 이미 Xcode 프로젝트에 포함된 파일이므로 내용을 교체하는 방식으로 진행한다. 새 파일을 bash로 생성하면 `.pbxproj`에 자동 추가되지 않아 빌드 실패가 발생한다.

---

## File Map

| 파일 | 변경 유형 | 역할 |
|------|----------|------|
| `PocketNotes/UI/MarkdownPreview.swift` | **Overwrite** | 파일명은 유지, `MarkdownWebView` 구조체로 전체 교체 |
| `PocketNotes/UI/EditorView.swift` | **Modify** | MarkdownWebView 사용, 포커스 이탈 자동 미리보기, 툴바 버튼 방향별 처리 |

---

### Task 1: MarkdownPreview.swift를 MarkdownWebView로 전체 교체

**Files:**
- Modify (overwrite): `PocketNotes/UI/MarkdownPreview.swift`

- [ ] **Step 1: 파일 전체를 아래 내용으로 교체**

`PocketNotes/UI/MarkdownPreview.swift` 의 전체 내용을 지우고 아래로 교체한다:

```swift
import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let text: String
    let accentColor: Color
    var onTap: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        let tap = NSClickGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        webView.addGestureRecognizer(tap)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onTap = onTap
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }

    // MARK: - HTML

    private var htmlContent: String {
        let accent = accentColor.toHexString()
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <meta name="color-scheme" content="light dark">
        <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
            font-size: 14px;
            color: canvastext;
            background: transparent;
            padding: 10px 16px;
            line-height: 1.6;
            word-wrap: break-word;
        }
        h1 { font-size: 1.35em; font-weight: 700; margin: 10px 0 4px; }
        h2 { font-size: 1.15em; font-weight: 600; margin: 8px 0 4px; }
        h3 { font-size: 1.0em;  font-weight: 600; margin: 6px 0 2px; }
        p  { margin: 4px 0; }
        ul, ol { padding-left: 20px; margin: 4px 0; }
        li { margin: 2px 0; }
        code {
            font-family: 'SF Mono', Menlo, Consolas, monospace;
            font-size: 0.85em;
            background: rgba(128,128,128,0.15);
            padding: 1px 5px;
            border-radius: 3px;
        }
        pre {
            background: rgba(128,128,128,0.1);
            border: 1px solid rgba(128,128,128,0.2);
            border-radius: 6px;
            padding: 10px 12px;
            margin: 6px 0;
            overflow-x: auto;
        }
        pre code { background: none; padding: 0; }
        blockquote {
            border-left: 3px solid \(accent);
            padding-left: 12px;
            margin: 6px 0;
            opacity: 0.75;
        }
        hr  { border: none; border-top: 1px solid rgba(128,128,128,0.25); margin: 10px 0; }
        a   { color: \(accent); text-decoration: none; }
        a:hover { text-decoration: underline; }
        strong { font-weight: 600; }
        em     { font-style: italic; }
        del    { text-decoration: line-through; opacity: 0.7; }
        </style>
        </head>
        <body>\(parseMarkdown(text))</body>
        </html>
        """
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate {
        var onTap: (() -> Void)?

        @objc func handleTap(_ gesture: NSClickGestureRecognizer) {
            onTap?()
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if action.navigationType == .linkActivated,
               let url = action.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

// MARK: - Markdown → HTML

private func parseMarkdown(_ input: String) -> String {
    var output = ""
    let lines = input.components(separatedBy: "\n")
    var i = 0

    while i < lines.count {
        let line = lines[i]

        // Fenced code block
        if line.hasPrefix("```") {
            var codeLines: [String] = []
            i += 1
            while i < lines.count && !lines[i].hasPrefix("```") {
                codeLines.append(lines[i].htmlEscaped)
                i += 1
            }
            output += "<pre><code>\(codeLines.joined(separator: "\n"))</code></pre>\n"
            i += 1
            continue
        }

        // Headings
        if line.hasPrefix("### ") {
            output += "<h3>\(inlineMarkdown(String(line.dropFirst(4))))</h3>\n"
        } else if line.hasPrefix("## ") {
            output += "<h2>\(inlineMarkdown(String(line.dropFirst(3))))</h2>\n"
        } else if line.hasPrefix("# ") {
            output += "<h1>\(inlineMarkdown(String(line.dropFirst(2))))</h1>\n"
        }
        // Horizontal rule
        else if line == "---" || line == "***" || line == "___" {
            output += "<hr>\n"
        }
        // Blockquote
        else if line.hasPrefix("> ") {
            output += "<blockquote><p>\(inlineMarkdown(String(line.dropFirst(2))))</p></blockquote>\n"
        }
        // Unordered list — consecutive items
        else if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
            var items: [String] = []
            while i < lines.count,
                  lines[i].hasPrefix("- ") || lines[i].hasPrefix("* ") || lines[i].hasPrefix("+ ") {
                items.append("<li>\(inlineMarkdown(String(lines[i].dropFirst(2))))</li>")
                i += 1
            }
            output += "<ul>\(items.joined())</ul>\n"
            continue
        }
        // Ordered list — consecutive items
        else if line.range(of: #"^\d+\. "#, options: .regularExpression) != nil {
            var items: [String] = []
            while i < lines.count,
                  lines[i].range(of: #"^\d+\. "#, options: .regularExpression) != nil {
                let content = lines[i].replacingOccurrences(
                    of: #"^\d+\. "#, with: "", options: .regularExpression
                )
                items.append("<li>\(inlineMarkdown(content))</li>")
                i += 1
            }
            output += "<ol>\(items.joined())</ol>\n"
            continue
        }
        // Empty line
        else if line.trimmingCharacters(in: .whitespaces).isEmpty {
            output += "<br>\n"
        }
        // Paragraph
        else {
            output += "<p>\(inlineMarkdown(line))</p>\n"
        }

        i += 1
    }
    return output
}

private func inlineMarkdown(_ text: String) -> String {
    var s = text.htmlEscaped
    // Inline code first (protect content from other patterns)
    s = s.replacingOccurrences(of: #"`([^`]+)`"#,
        with: "<code>$1</code>", options: .regularExpression)
    // Bold + italic
    s = s.replacingOccurrences(of: #"\*\*\*(.+?)\*\*\*"#,
        with: "<strong><em>$1</em></strong>", options: .regularExpression)
    // Bold
    s = s.replacingOccurrences(of: #"\*\*(.+?)\*\*"#,
        with: "<strong>$1</strong>", options: .regularExpression)
    // Italic (* and _)
    s = s.replacingOccurrences(of: #"(?<!\*)\*([^*\n]+)\*(?!\*)"#,
        with: "<em>$1</em>", options: .regularExpression)
    s = s.replacingOccurrences(of: #"(?<!_)_([^_\n]+)_(?!_)"#,
        with: "<em>$1</em>", options: .regularExpression)
    // Strikethrough
    s = s.replacingOccurrences(of: #"~~(.+?)~~"#,
        with: "<del>$1</del>", options: .regularExpression)
    // Links [text](url)
    s = s.replacingOccurrences(of: #"\[([^\]]+)\]\(([^)]+)\)"#,
        with: "<a href=\"$2\">$1</a>", options: .regularExpression)
    return s
}

// MARK: - Extensions

extension String {
    var htmlEscaped: String {
        self
            .replacingOccurrences(of: "&",  with: "&amp;")
            .replacingOccurrences(of: "<",  with: "&lt;")
            .replacingOccurrences(of: ">",  with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

extension Color {
    func toHexString() -> String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .systemBlue
        let r = Int((ns.redComponent   * 255).rounded())
        let g = Int((ns.greenComponent * 255).rounded())
        let b = Int((ns.blueComponent  * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
```

- [ ] **Step 2: 빌드 확인**

```bash
xcodebuild -scheme PocketNotes -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 커밋**

```bash
git add PocketNotes/UI/MarkdownPreview.swift
git commit -m "feat: MarkdownPreview → MarkdownWebView (WKWebView 기반 마크다운 렌더러)"
```

---

### Task 2: EditorView를 MarkdownWebView로 전환 + 자동 미리보기 동작 추가

**Files:**
- Modify: `PocketNotes/UI/EditorView.swift`

현재 `EditorView.swift` 전체 내용:

```swift
import SwiftUI
import Combine

struct NoteCardView: View {
    @EnvironmentObject var store: NotesStore
    @EnvironmentObject var theme: ThemeStore
    let note: NoteNode

    @State private var text = ""
    @State private var saveTimer: AnyCancellable?
    @FocusState private var isFocused: Bool
    @State private var isHandleHovered = false
    @State private var isPreviewMode = false

    // ... (dateFormatter, dateString, body, scheduleSave)
}
```

세 곳을 수정한다.

- [ ] **Step 1: 미리보기 블록을 MarkdownWebView + onTap 핸들러로 교체**

변경 전 (line 49-51):
```swift
if isPreviewMode {
    MarkdownPreview(text: text)
        .frame(minHeight: 90)
```

변경 후:
```swift
if isPreviewMode {
    MarkdownWebView(text: text, accentColor: theme.accent) {
        isPreviewMode = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isFocused = true
        }
    }
    .frame(minHeight: 90)
```

- [ ] **Step 2: 툴바 버튼 액션을 편집→미리보기 / 미리보기→편집 방향별로 분리**

변경 전 (lines 77-80):
```swift
Button {
    saveTimer?.cancel()
    store.saveContent(text, to: note)
    isPreviewMode.toggle()
} label: {
    Image(systemName: isPreviewMode ? "eye.fill" : "pencil")
```

변경 후:
```swift
Button {
    if isPreviewMode {
        isPreviewMode = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isFocused = true
        }
    } else {
        saveTimer?.cancel()
        store.saveContent(text, to: note)
        isPreviewMode = true
    }
} label: {
    Image(systemName: isPreviewMode ? "eye.fill" : "pencil")
```

- [ ] **Step 3: 포커스 이탈 시 자동 미리보기 전환 onChange 추가**

`.onChange(of: text) { scheduleSave() }` 바로 뒤, `}` (body 닫기) 앞에 추가:

변경 전:
```swift
        .onChange(of: text) { scheduleSave() }
    }

    private func scheduleSave() {
```

변경 후:
```swift
        .onChange(of: text) { scheduleSave() }
        .onChange(of: isFocused) { _, focused in
            if !focused && !isPreviewMode && !text.isEmpty {
                saveTimer?.cancel()
                store.saveContent(text, to: note)
                isPreviewMode = true
            }
        }
    }

    private func scheduleSave() {
```

- [ ] **Step 4: 빌드 확인**

```bash
xcodebuild -scheme PocketNotes -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 커밋**

```bash
git add PocketNotes/UI/EditorView.swift
git commit -m "feat: 포커스 이탈 자동 미리보기 + MarkdownWebView 연결 + 클릭-투-편집"
```

---

### Task 3: 앱 실행 및 수동 검증

**Files:** 없음 (검증 전용)

- [ ] **Step 1: 앱 실행**

```bash
open "/Users/wonmac/Library/Developer/Xcode/DerivedData/PocketNotes-btlzyujqvvyqutfozwabxzgftqhi/Build/Products/Debug/PocketNotes.app"
```

앱 경로가 다르면:
```bash
find ~/Library/Developer/Xcode/DerivedData -name "PocketNotes.app" -path "*/Debug/*" 2>/dev/null
```

- [ ] **Step 2: 마크다운 렌더링 확인**

노트 카드에 아래 텍스트 입력 후 카드 바깥 클릭:

```
# 제목 1
## 제목 2

**굵게** *기울임* ~~취소선~~

- 항목 A
- 항목 B

1. 순서 1
2. 순서 2

> 인용문 블록

`인라인 코드`
```

기대 결과:
- `# 제목 1` → 크고 굵은 텍스트 렌더링
- `**굵게**` → 굵게 표시
- `- 항목` → 불릿 리스트
- `` `인라인 코드` `` → 배경색 있는 모노스페이스
- `> 인용문` → 왼쪽 accent 컬러 세로선

- [ ] **Step 3: 자동 미리보기 동작 확인**

1. 노트를 클릭해 텍스트 입력 모드 진입
2. 텍스트 입력
3. 카드 바깥 아무 곳이나 클릭
4. 기대: 자동 저장 후 미리보기 모드로 전환

- [ ] **Step 4: 클릭-투-편집 확인**

1. 미리보기 상태의 노트 클릭 (또는 pencil 버튼 클릭)
2. 기대: 편집 모드로 전환, TextEditor 포커스

- [ ] **Step 5: 카드별 독립 동작 확인**

1. 노트 A 편집 모드 진입
2. 노트 B 클릭
3. 기대: A는 미리보기로 자동 전환, B는 편집 모드로 진입

- [ ] **Step 6: 스크린샷 캡처**

```bash
screencapture -x /tmp/markdown_preview_result.png
```
