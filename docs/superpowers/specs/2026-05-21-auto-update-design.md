# Auto Update 기능 설계 스펙

## 개요

PocketNotes에 Sparkle 프레임워크를 활용한 자동 업데이트 기능을 추가한다. 사용자는 설정창과 메뉴바 우클릭 메뉴에서 업데이트를 확인하고 설치할 수 있다.

## 배포 전제

- 배포 채널: GitHub Releases (DMG)
- 원격 저장소: `https://github.com/Ryan-Dia/pocket-notes`
- appcast.xml URL: `https://raw.githubusercontent.com/Ryan-Dia/pocket-notes/main/docs/appcast.xml`

---

## 구성 요소

### 1. Sparkle (SPM 의존성)

- **버전**: Sparkle 2.x
- **추가 위치**: `project.yml` SPM 의존성
- **사용 클래스**: `SPUStandardUpdaterController`

### 2. Info.plist 수정

```xml
<key>SUFeedURL</key>
<string>https://raw.githubusercontent.com/Ryan-Dia/pocket-notes/main/docs/appcast.xml</string>

<key>SUPublicEDKey</key>
<string><!-- generate_keys로 생성한 공개키 --></string>
```

### 3. AppDelegate 수정

- `SPUStandardUpdaterController` 프로퍼티 추가 및 초기화
- 메뉴바 컨텍스트 메뉴에 "업데이트 확인..." 항목 추가 (`checkForUpdates` 액션 연결)

**메뉴 구조 (변경 후):**
```
PocketNotes 열기
───────────────
설정...
업데이트 확인...
───────────────
종료
```

### 4. SettingsView 수정

- 기존 섹션 하단에 `Section("업데이트")` 추가
- 현재 버전(`CFBundleShortVersionString`) 표시
- "업데이트 확인" 버튼 → `updaterController.updater.checkForUpdates()` 호출

**UI:**
```
[업데이트]
현재 버전    0.1.0
             [업데이트 확인]
```

### 5. docs/appcast.xml

Sparkle appcast 형식의 XML 파일. 릴리즈마다 `generate-appcast.sh`로 갱신.

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>PocketNotes</title>
    <item>
      <title>0.1.0</title>
      <pubDate>Thu, 01 Jan 2026 00:00:00 +0000</pubDate>
      <sparkle:version>1</sparkle:version>
      <sparkle:shortVersionString>0.1.0</sparkle:shortVersionString>
      <enclosure
        url="https://github.com/Ryan-Dia/pocket-notes/releases/download/v0.1.0/PocketNotes-0.1.0.dmg"
        sparkle:edSignature="..."
        length="..."
        type="application/octet-stream"/>
    </item>
  </channel>
</rss>
```

### 6. Scripts/generate-appcast.sh

릴리즈 시 실행하는 스크립트:

1. Sparkle의 `generate_appcast` 도구 실행
2. DMG를 EdDSA 비밀키로 서명
3. `docs/appcast.xml` 갱신 (버전, 다운로드 URL, 서명값)

---

## 동작 흐름

```
앱 시작
  └─ Sparkle 백그라운드 자동 체크 (appcast.xml 폴링)
       ├─ 업데이트 없음 → 조용히 종료
       └─ 업데이트 있음 → Sparkle 네이티브 다이얼로그 표시
            └─ 사용자 "설치" 클릭 → DMG 다운로드 → 설치 → 재시작

수동 확인 (설정창 또는 메뉴바)
  └─ checkForUpdates() 호출
       ├─ 업데이트 없음 → "최신 버전입니다" 알림
       └─ 업데이트 있음 → Sparkle 네이티브 다이얼로그 표시
```

---

## 릴리즈 프로세스

1. `Info.plist` 버전 올리기 (예: `0.1.0` → `0.2.0`)
2. `Scripts/build-dmg.sh` 실행 → DMG 빌드
3. `Scripts/generate-appcast.sh` 실행 → `docs/appcast.xml` 갱신
4. `docs/appcast.xml` 커밋 + 푸시
5. GitHub Releases에 DMG 업로드 + 버전 태그

---

## 보안

- **EdDSA 키 쌍**: `generate_keys` 명령으로 최초 1회 생성
- **공개키**: `Info.plist`의 `SUPublicEDKey`에 삽입 (커밋 가능)
- **비밀키**: 로컬 Keychain에만 보관, 절대 커밋 금지

---

## 범위 외

- 델타 업데이트 (전체 DMG 다운로드로 충분)
- 자동 설치 스케줄 설정 UI (Sparkle 기본값 사용)
- 베타 채널 분리
