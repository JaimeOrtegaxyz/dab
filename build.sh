#!/bin/bash
set -euo pipefail

APP_NAME="dab"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"
FRAMEWORKS="${CONTENTS}/Frameworks"
SOURCE_RESOURCES="dab/Resources"
ENTITLEMENTS="dab.entitlements"

# Dev-build signing identity. TCC (Accessibility, Screen Recording) keys its
# grant to bundle ID + the *signing identity*, so a STABLE identity makes the
# grant survive rebuilds. Resolution order, first hit wins:
#   1. $SIGNING_IDENTITY env override (explicit).
#   2. a self-signed "dab Dev" cert -> portable: recreate by name on each Mac
#      (Keychain Access > Certificate Assistant > Create a Certificate,
#       name "dab Dev", type Code Signing, self-signed).
#   3. the machine's "Apple Development" identity -> stable per-Mac, ships with Xcode.
#   4. ad-hoc "-" -> builds fine, but Screen Recording must be re-granted each rebuild.
# (Was a hardcoded cert SHA-1, which only existed on one Mac and hard-failed elsewhere.)
DEV_SIGN_NAME="${DEV_SIGN_NAME:-dab Dev}"

resolve_signing_identity() {
    if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
        printf '%s' "${SIGNING_IDENTITY}"
        return
    fi
    local list hash
    list="$(security find-identity -v -p codesigning 2>/dev/null || true)"
    hash="$(printf '%s\n' "${list}" | grep -F "\"${DEV_SIGN_NAME}\"" | head -1 | awk '{print $2}' || true)"
    if [[ -n "${hash}" ]]; then printf '%s' "${hash}"; return; fi
    hash="$(printf '%s\n' "${list}" | grep -F 'Apple Development:' | head -1 | awk '{print $2}' || true)"
    if [[ -n "${hash}" ]]; then printf '%s' "${hash}"; return; fi
    printf '%s' '-'
}
SIGNING_IDENTITY="$(resolve_signing_identity)"
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

# Universal (fat) build so the same app runs on Apple silicon and Intel.
# `swift build --arch arm64 --arch x86_64` would do this in one shot, but that
# mode requires full Xcode (xcbuild); with only Command Line Tools installed it
# fails. So build each arch separately via --triple and lipo them together.
echo "Building ${APP_NAME} via SwiftPM (arm64)..."
swift build -c release --triple arm64-apple-macosx
echo "Building ${APP_NAME} via SwiftPM (x86_64)..."
swift build -c release --triple x86_64-apple-macosx

ARM64_BIN=".build/arm64-apple-macosx/release/${APP_NAME}"
X86_64_BIN=".build/x86_64-apple-macosx/release/${APP_NAME}"
BINARY_PATH=".build/${APP_NAME}-universal"
# Sparkle ships as a prebuilt universal xcframework, so the copy in either
# arch's build dir already contains both slices — no lipo needed for it.
SPARKLE_FRAMEWORK=".build/arm64-apple-macosx/release/Sparkle.framework"

for thin in "${ARM64_BIN}" "${X86_64_BIN}"; do
    if [[ ! -f "${thin}" ]]; then
        echo "Build did not produce expected binary at ${thin}"
        exit 1
    fi
done

echo "Creating universal binary with lipo..."
lipo -create "${ARM64_BIN}" "${X86_64_BIN}" -output "${BINARY_PATH}"

# Fail loudly if the binary somehow came out thin — an arm64-only binary here
# would ship a release that silently won't launch on Intel Macs.
BUILT_ARCHS="$(lipo -archs "${BINARY_PATH}")"
if [[ "${BUILT_ARCHS}" != *x86_64* || "${BUILT_ARCHS}" != *arm64* ]]; then
    echo "Expected a universal binary, but lipo reports: ${BUILT_ARCHS}"
    exit 1
fi

# Fail loudly if the build somehow came out thin — an arm64-only binary here
# would ship a release that silently won't launch on Intel Macs.
BUILT_ARCHS="$(lipo -archs "${BINARY_PATH}")"
if [[ "${BUILT_ARCHS}" != *x86_64* || "${BUILT_ARCHS}" != *arm64* ]]; then
    echo "Expected a universal binary, but lipo reports: ${BUILT_ARCHS}"
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
if [[ "${SIGNING_IDENTITY}" == "-" ]]; then
    echo "Codesigning ad-hoc (no 'dab Dev' or Apple Development cert found)."
    echo "  -> Screen Recording / Accessibility must be re-granted after each rebuild."
    echo "  -> For a stable grant, create a self-signed 'dab Dev' Code Signing cert"
    echo "     in Keychain Access (Certificate Assistant > Create a Certificate)."
else
    echo "Codesigning with identity: ${SIGNING_IDENTITY}"
fi
codesign --force --deep --sign "${SIGNING_IDENTITY}" "${FRAMEWORKS}/Sparkle.framework"
codesign --force --sign "${SIGNING_IDENTITY}" --entitlements "${ENTITLEMENTS}" "${APP_BUNDLE}"

echo "Done! Created ${APP_BUNDLE}"
echo "You can run it with: open ${APP_BUNDLE}"
