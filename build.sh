#!/bin/bash
set -euo pipefail

APP_NAME="dab"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"
FRAMEWORKS="${CONTENTS}/Frameworks"
SOURCE_RESOURCES="dab/Resources"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-B6263C6F33FB6C841AB4CE6026F1B2B24768B222}"
ENTITLEMENTS="dab.entitlements"
# release.sh passes the real version via the environment; standalone dev builds
# get a placeholder so the bundle is never left with a stale hardcoded version.
VERSION="${VERSION:-0.0.0-dev}"

# Reject a malformed version early. PlistBuddy re-parses the value by whitespace,
# so a stray space (e.g. "1.0 beta") would silently corrupt the stamped plist;
# fail loudly instead of sealing a broken Info.plist into the signed bundle.
if [[ ! "${VERSION}" =~ ^[0-9A-Za-z.+-]+$ ]]; then
    echo "Invalid VERSION '${VERSION}': only [0-9A-Za-z.+-] are allowed."
    exit 1
fi

echo "Building ${APP_NAME} via SwiftPM..."
swift build -c release

BINARY_PATH=".build/release/${APP_NAME}"
SPARKLE_FRAMEWORK=".build/release/Sparkle.framework"

if [[ ! -f "${BINARY_PATH}" ]]; then
    echo "Build did not produce expected binary at ${BINARY_PATH}"
    exit 1
fi

if [[ ! -d "${SPARKLE_FRAMEWORK}" ]]; then
    echo "Sparkle.framework not found at ${SPARKLE_FRAMEWORK}"
    echo "Run 'swift package resolve' to fetch the Sparkle binary artifact."
    exit 1
fi

echo "Creating app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS}" "${RESOURCES}" "${FRAMEWORKS}"

cp "${BINARY_PATH}" "${MACOS}/${APP_NAME}"
cp "dab/App/Info.plist" "${CONTENTS}/Info.plist"

# Stamp the build version into the copied plist. Must happen before codesign
# (below) so the signature seals the edited plist, and before any DMG/notarize
# steps in release.sh — otherwise Sparkle compares the appcast's version against
# a stale CFBundleVersion and either loops or never sees the update as installed.
echo "Stamping version ${VERSION} into Info.plist..."
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString '${VERSION}'" \
    -c "Set :CFBundleVersion '${VERSION}'" \
    "${CONTENTS}/Info.plist"

if [[ -d "${SOURCE_RESOURCES}" ]]; then
    find "${SOURCE_RESOURCES}" -type f \
        \( -name '*.icns' -o -name '*.svg' -o -name '*.pdf' -o -name '*.png' -o -name '*.ttf' -o -name '*.otf' \) \
        ! -path "*/AppIcon.iconset/*" \
        -exec cp {} "${RESOURCES}/" \;
fi

# Embed Sparkle.framework. ditto preserves the framework's Versions/Current
# symlinks intact — cp -R would too, but ditto is the safer default for
# bundles. Sparkle's nested XPC services come along inside.
echo "Embedding Sparkle.framework..."
ditto "${SPARKLE_FRAMEWORK}" "${FRAMEWORKS}/Sparkle.framework"

# Swift's linker only sets rpath to @loader_path (the binary's own directory).
# Sparkle.framework lives in Contents/Frameworks/, so dyld needs an explicit
# rpath relative to the executable. Without this, launch fails with:
#   "Library not loaded: @rpath/Sparkle.framework/Versions/B/Sparkle".
echo "Patching rpath for Frameworks/..."
install_name_tool -add_rpath "@executable_path/../Frameworks" "${MACOS}/${APP_NAME}"

# Sign the inner framework first (with --deep so its nested bundles —
# Updater.app, Autoupdate.app, XPCServices — all get signed too), then
# sign the outer app. Signing has to walk inner-out.
echo "Codesigning with identity: ${SIGNING_IDENTITY}"
codesign --force --deep --sign "${SIGNING_IDENTITY}" "${FRAMEWORKS}/Sparkle.framework"
codesign --force --sign "${SIGNING_IDENTITY}" --entitlements "${ENTITLEMENTS}" "${APP_BUNDLE}"

echo "Done! Created ${APP_BUNDLE}"
echo "You can run it with: open ${APP_BUNDLE}"
