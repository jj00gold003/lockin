#!/bin/bash
# 用法：APPLE_IDENTITY="Developer ID Application: Your Name" NOTARY_PROFILE="lockin-notary" bash scripts/release.sh
set -euo pipefail

cd "$(dirname "$0")/.."
CONFIG="Release"
VERSION=$(grep MARKETING_VERSION project.yml | head -1 | sed 's/.*"\(.*\)"/\1/')

xcodegen generate
xcodebuild -project LockIn.xcodeproj -scheme LockIn -configuration "$CONFIG" \
    clean build CONFIGURATION_BUILD_DIR=build

APP="build/LockIn.app"
codesign --deep --force --options runtime --timestamp \
    --sign "${APPLE_IDENTITY:?需要 APPLE_IDENTITY 环境变量}" "$APP"

hdiutil create -volname LockIn -srcfolder "$APP" -ov -format UDZO "LockIn-${VERSION}.dmg"

xcrun notarytool submit "LockIn-${VERSION}.dmg" \
    --keychain-profile "${NOTARY_PROFILE:?需要 NOTARY_PROFILE 环境变量}" --wait
xcrun stapler staple "LockIn-${VERSION}.dmg"

echo "✅ LockIn-${VERSION}.dmg 已公证，可上传 GitHub Release"
