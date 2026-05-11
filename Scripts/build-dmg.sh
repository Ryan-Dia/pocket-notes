#!/usr/bin/env bash
set -euo pipefail

SCHEME="PocketNotes"
ARCHIVE_PATH="build/PocketNotes.xcarchive"
EXPORT_PATH="build/export"
DMG_NAME="PocketNotes.dmg"
EXPORT_OPTIONS="Scripts/ExportOptions.plist"

echo "==> 아카이브 빌드 중..."
xcodebuild archive \
  -scheme "$SCHEME" \
  -archivePath "$ARCHIVE_PATH" \
  -destination "platform=macOS" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

echo "==> 앱 내보내기..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS"

echo "==> DMG 생성 중..."
rm -f "$DMG_NAME"
hdiutil create \
  -volname "PocketNotes" \
  -srcfolder "$EXPORT_PATH/PocketNotes.app" \
  -ov \
  -format UDZO \
  "$DMG_NAME"

echo "==> 완료: $DMG_NAME"
