#!/bin/bash
set -euo pipefail

APP_NAME="Pixelatolor"
BUILD_ROOT=".build"
BUILD_DIR="${BUILD_ROOT}/release"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
SWIFT_MODULE_CACHE="${BUILD_ROOT}/swift-module-cache"
CLANG_MODULE_CACHE="${BUILD_ROOT}/clang-module-cache"

resolve_sdk() {
    local candidates=()
    local default_sdk

    default_sdk="$(xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)"
    if [[ -n "${default_sdk}" ]]; then
        candidates+=("${default_sdk}")
    fi

    candidates+=(
        "/Library/Developer/CommandLineTools/SDKs/MacOSX13.3.sdk"
        "/Library/Developer/CommandLineTools/SDKs/MacOSX13.sdk"
        "/Library/Developer/CommandLineTools/SDKs/MacOSX12.3.sdk"
        "/Library/Developer/CommandLineTools/SDKs/MacOSX12.sdk"
        "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
    )

    for sdk in "${candidates[@]}"; do
        if [[ -d "${sdk}" ]]; then
            printf '%s\n' "${sdk}"
            return 0
        fi
    done

    return 1
}

resolve_target() {
    case "$(basename "$1")" in
        MacOSX12*)
            printf '%s\n' "arm64-apple-macos12.0"
            ;;
        *)
            printf '%s\n' "arm64-apple-macos13.0"
            ;;
    esac
}

SDKROOT="$(resolve_sdk)" || {
    echo "Unable to locate a macOS SDK."
    exit 1
}
TARGET="$(resolve_target "${SDKROOT}")"

mkdir -p "${BUILD_DIR}" "${SWIFT_MODULE_CACHE}" "${CLANG_MODULE_CACHE}"

SWIFT_SOURCES=()
while IFS= read -r source; do
    SWIFT_SOURCES+=("${source}")
done < <(find "Pixelatolor" -name '*.swift' | sort)

if [[ "${#SWIFT_SOURCES[@]}" -eq 0 ]]; then
    echo "No Swift source files found."
    exit 1
fi

echo "Building ${APP_NAME}..."
swiftc \
    -O \
    -sdk "${SDKROOT}" \
    -target "${TARGET}" \
    -module-cache-path "${SWIFT_MODULE_CACHE}" \
    -Xcc "-fmodules-cache-path=${CLANG_MODULE_CACHE}" \
    "${SWIFT_SOURCES[@]}" \
    -o "${BUILD_DIR}/${APP_NAME}"

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
