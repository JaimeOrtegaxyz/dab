#!/bin/bash
set -e

APP_NAME="Pixelatolor"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"

echo "Building ${APP_NAME}..."
swift build -c release

echo "Creating app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS}"

cp "${BUILD_DIR}/${APP_NAME}" "${MACOS}/${APP_NAME}"
cp "Pixelatolor/App/Info.plist" "${CONTENTS}/Info.plist"

echo "Codesigning..."
codesign --force --sign - "${APP_BUNDLE}"

echo "Done! Created ${APP_BUNDLE}"
echo "You can run it with: open ${APP_BUNDLE}"
echo ""
echo "NOTE: If screen capture only shows the desktop, go to"
echo "  System Settings → Privacy & Security → Screen Recording"
echo "  Remove Pixelatolor if listed, re-run the app, and re-grant permission."
