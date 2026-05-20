#!/bin/bash
# 사용법: ./Scripts/generate-appcast.sh <version> <build> <dmg_path>
#   version: 마케팅 버전 (예: 0.2.0) — CFBundleShortVersionString
#   build:   빌드 번호 (예: 2) — CFBundleVersion
#   dmg_path: DMG 파일 경로
# 사전 조건: SPARKLE_TOOLS_PATH 환경변수로 Sparkle bin 디렉토리 경로 지정
#   예) export SPARKLE_TOOLS_PATH=/tmp/sparkle-tools/bin
# 어느 디렉토리에서 실행해도 동작한다.

set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(dirname "$SCRIPT_DIR")

VERSION="$1"
BUILD="$2"
DMG_PATH="$3"
TOOLS="${SPARKLE_TOOLS_PATH:-/tmp/sparkle-tools/bin}"
APPCAST_PATH="$REPO_ROOT/docs/appcast.xml"
DOWNLOAD_URL="https://github.com/Ryan-Dia/pocket-notes/releases/download/v${VERSION}/PocketNotes-${VERSION}.dmg"

if [ -z "$VERSION" ] || [ -z "$BUILD" ] || [ -z "$DMG_PATH" ]; then
    echo "Usage: $0 <version> <build> <dmg_path>"
    echo "Example: $0 0.2.0 2 PocketNotes-0.2.0.dmg"
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
SIGN_OUTPUT=$("$TOOLS/sign_update" "$DMG_PATH") || {
    echo "Error: sign_update failed"
    exit 1
}

SIGNATURE=$(echo "$SIGN_OUTPUT" | grep -o 'sparkle:edSignature="[^"]*"' | cut -d'"' -f2)
LENGTH=$(echo "$SIGN_OUTPUT" | grep -o 'length="[^"]*"' | cut -d'"' -f2)

if [ -z "$SIGNATURE" ] || [ -z "$LENGTH" ]; then
    echo "Error: Failed to parse sign_update output:"
    echo "$SIGN_OUTPUT"
    exit 1
fi

PUB_DATE=$(LANG=C LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")

cat > "$APPCAST_PATH" << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>PocketNotes</title>
    <item>
      <title>${VERSION}</title>
      <pubDate>${PUB_DATE}</pubDate>
      <sparkle:version>${BUILD}</sparkle:version>
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

xmllint --noout "$APPCAST_PATH" || { echo "Error: Invalid XML generated"; exit 1; }
echo "✓ $APPCAST_PATH 갱신 완료 (v${VERSION}, build ${BUILD})"
echo ""
echo "다음 단계:"
echo "  git add docs/appcast.xml && git commit -m 'chore: appcast.xml 갱신 (v${VERSION})'"
echo "  GitHub Releases에 $DMG_PATH 업로드"
