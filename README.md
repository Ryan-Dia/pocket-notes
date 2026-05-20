<div align="center">

# 🗒️ PocketNotes

**메뉴바에 상주하는 macOS 사이드 패널 노트앱**

![Swift](https://img.shields.io/badge/Swift-5.10-orange?style=flat-square&logo=swift)
![Platform](https://img.shields.io/badge/macOS-14.0+-blue?style=flat-square&logo=apple)
![Version](https://img.shields.io/badge/version-0.1.0-green?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-lightgrey?style=flat-square)

</div>

---

## 소개

PocketNotes는 메뉴바 아이콘을 클릭하면 화면 측면에서 슬라이드로 나타나는 빠른 노트 앱입니다.  
창을 전환하거나 앱을 전면에 띄울 필요 없이, 어느 작업 중에도 즉시 메모할 수 있습니다.

<img width="320" alt="PocketNotes 스크린샷" src="https://placehold.co/640x480/f7f2e3/c2634f?text=PocketNotes" />

---

## 기능

- **사이드 패널** — 화면 오른쪽(또는 왼쪽)에서 슬라이드 등장, 포커스를 잃으면 자동 닫힘
- **폴더 계층** — 최대 3 레벨 깊이의 폴더 구조 지원
- **자동 저장** — 입력 후 0.5초 디바운스로 자동 저장
- **폴더 검색** — 사이드바에서 폴더명 실시간 검색
- **노트 미리보기** — 폴더 목록에서 최근 노트 첫 줄 미리보기
- **멀티 모니터** — 마우스가 있는 모니터에서만 패널 표시
- **글로벌 단축키** — 어느 앱에서든 단축키로 패널 토글

---

## 요구사항

| 항목 | 버전 |
|------|------|
| macOS | 14.0 (Sonoma) 이상 |
| Xcode | 16.0 이상 |
| Swift | 5.10 이상 |

---

## 설치 (빌드 없이)

[Releases 페이지](https://github.com/Ryan-Dia/pocket-notes/releases)에서 최신 버전의 `PocketNotes-vX.X.X.zip`을 다운로드합니다.

```
1. zip 압축 해제
2. PocketNotes.app → /Applications 폴더로 이동
3. 실행
```

> **⚠️ "확인할 수 없는 개발자" 경고가 뜨는 경우**
>
> Apple 공증(Notarization)이 적용되지 않아 macOS Gatekeeper가 경고를 표시합니다.
>
> **해결 방법:** `PocketNotes.app`을 **우클릭(또는 Control+클릭) → 열기** 를 선택하면 한 번만 확인 후 정상 실행됩니다.  
> 이후 실행부터는 경고가 나타나지 않습니다.


---

## 사용법

1. 앱 실행 시 메뉴바에 노트 아이콘이 생깁니다
2. 아이콘 클릭 또는 글로벌 단축키로 패널을 열고 닫습니다
3. `folder.badge.plus` 버튼으로 폴더를 만들고, 폴더 안에서 `+` 버튼으로 노트를 추가합니다
4. 노트는 입력 즉시 자동 저장됩니다

### 폴더 구조

```
최상위 폴더 (depth 0)
├── 상위 폴더 (depth 1)
│   ├── 하위 폴더 (depth 2)  ← 최대 깊이
│   │   └── 노트.md
│   └── 노트.md
└── 노트.md
```

### 설정

| 항목 | 설명 |
|------|------|
| 패널 위치 | 오른쪽 / 왼쪽 선택 가능 |
| 포커스 해제 시 닫기 | 패널 외부 클릭 시 자동 닫힘 |
| 노트 저장 위치 | 기본값 `~/Documents/PocketNotes` |

---

## 프로젝트 구조

```
PocketNotes/
├── AppDelegate.swift          # 메뉴바 설정
├── Panel/
│   ├── PanelController.swift  # 슬라이드 애니메이션 & 화면 관리
│   └── SlidingPanel.swift     # NSPanel 서브클래스
├── Storage/
│   ├── NoteNode.swift         # 노트/폴더 트리 노드
│   ├── NotesStore.swift       # 파일 CRUD & 상태 관리
│   └── FolderWatcher.swift    # 파일시스템 변경 감지
└── UI/
    ├── ContentView.swift       # 네비게이션 스택
    ├── SidebarView.swift       # 폴더 목록
    ├── FolderContentsView.swift # 폴더 내부 뷰
    └── EditorView.swift        # 노트 카드
```

---

## 라이선스

MIT © [Ryan-Dia](https://github.com/Ryan-Dia)
