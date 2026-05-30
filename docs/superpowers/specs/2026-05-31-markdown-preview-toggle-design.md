# Markdown Preview Toggle — Design Spec

**Date:** 2026-05-31
**Status:** Approved

## Summary

노트 카드마다 편집 모드(TextEditor) ↔ 마크다운 미리보기 모드(MarkdownPreview)를 독립적으로 전환할 수 있는 토글 기능을 추가한다.

## Goals

- 마크다운 문법(`# 제목`, `**굵게**`, `- 리스트`, `` `코드` `` 등)으로 작성한 노트를 렌더링해서 볼 수 있다.
- 각 카드의 토글 상태는 독립적이다 (카드 A가 미리보기여도 카드 B는 편집 가능).
- 앱 재시작 시 모든 카드는 편집 모드로 초기화된다.

## Non-Goals

- 노트별 모드 영속화 (재시작 후 유지)
- 전역 일괄 전환
- WYSIWYG 인라인 렌더링
- 키보드 단축키 토글

## Architecture

### 변경 파일 1: `MarkdownPreview.swift`

`inlineOnlyPreservingWhitespace` 옵션을 제거해 기본 풀 마크다운 파싱으로 전환한다. 이로써 헤더, 리스트, 코드블록, 링크 등 블록 레벨 문법도 렌더링된다.

```swift
// Before (인라인만 파싱)
options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)

// After (풀 마크다운 파싱)
// options 파라미터 제거 → 기본값은 .full (CommonMark 전체 파싱)
```

SwiftUI `Text`가 `AttributedString`의 `PresentationIntent` 속성을 해석하므로 헤더(폰트 크기 차등), 리스트(들여쓰기), 인라인 서식(굵게·기울임·코드·링크)이 렌더링된다. 테이블, 수평선 등 일부 요소는 SwiftUI Text 제약상 시각적 렌더링이 제한될 수 있다.

미리보기 컴포넌트는 상태를 갖지 않는 순수 뷰로 유지한다.

### 변경 파일 2: `EditorView.swift` (NoteCardView)

**상태 추가:**
```swift
@State private var isPreviewMode = false
```

**body 전환 로직:**
- `isPreviewMode == false` → 기존 `TextEditor` 표시
- `isPreviewMode == true` → `MarkdownPreview(text: text)` 표시
- 두 경우 모두 동일한 카드 레이아웃(드래그 핸들, 툴바) 유지

**툴바 토글 버튼:**
- 기존 `textformat` 아이콘 자리에 모드 버튼 배치
- 편집 모드: `pencil` 아이콘 (클릭 시 미리보기로 전환)
- 미리보기 모드: `eye.fill` 아이콘 (클릭 시 편집으로 전환)
- accent 색상으로 현재 활성 모드 강조

## Data Flow

```
isPreviewMode (Bool) — NoteCardView @State
     ↓
  false → TextEditor (편집, onChange로 scheduleSave 호출)
  true  → MarkdownPreview(text: text) (읽기 전용, 저장 없음)
```

텍스트 원본(`text: String`)은 편집/미리보기 양쪽에서 동일하게 참조한다. 미리보기 중에도 `text`는 보존되므로 편집 모드로 돌아왔을 때 내용이 유지된다.

## Layout Considerations

- 미리보기 모드에서 `minHeight: 90` 제약을 유지하되, 내용이 길면 ScrollView가 처리
- `MarkdownPreview` 내부에 `ScrollView`가 이미 있으므로 카드 높이는 `minHeight`로 하한 고정

## Error Handling

- 잘못된 마크다운 문법 → `AttributedString` 파싱 실패 시 `?? AttributedString(text)` 폴백으로 원문 표시 (기존 로직 유지)
