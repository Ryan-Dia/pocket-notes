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
