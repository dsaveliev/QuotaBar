#!/bin/bash
# Builds the QuotaBar menu bar app bundle into build/QuotaBar.app.
set -euo pipefail

cd "$(dirname "$0")/.."

BUNDLE_ID="dev.dmitrii.quotabar"
APP_NAME="QuotaBar"
EXECUTABLE="quotabar"
APP="build/${APP_NAME}.app"

echo "==> Building ${EXECUTABLE} (release)"
swift build -c release --product quotabar

BINARY=".build/release/${EXECUTABLE}"
if [ ! -f "${BINARY}" ]; then
    echo "error: ${BINARY} was not produced by the build" >&2
    exit 1
fi

echo "==> Assembling ${APP}"
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"

cat > "${APP}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleExecutable</key>
    <string>${EXECUTABLE}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

cp "${BINARY}" "${APP}/Contents/MacOS/${EXECUTABLE}"
chmod +x "${APP}/Contents/MacOS/${EXECUTABLE}"

echo "==> Signing (ad-hoc)"
if ! codesign --force --sign - --timestamp=none "${APP}"; then
    echo "error: ad-hoc signing failed" >&2
    exit 1
fi

codesign --verify --verbose=2 "${APP}"

echo "==> Built ${APP}"