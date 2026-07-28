#!/bin/bash
#
# release.sh — build, sign with Developer ID, notarize, staple,
# package as a DMG, and EdDSA-sign with Sparkle's key. Outputs
# dist/dab-<version>.dmg ready for upload to GitHub Releases, plus
# dist/dab-<version>.sig.txt with the Sparkle signature line to paste
# into docs/appcast.xml.
#
# Usage:
#   ./release.sh <version>
#   e.g. ./release.sh 0.4.2-beta
#
# Prerequisites (one-time):
#
# 1. Notary credentials in the keychain:
#      xcrun notarytool store-credentials dab-notary \
#        --apple-id <your-apple-id> \
#        --team-id GU57FJMCH4 \
#        --password <app-specific-password>
#
# 2. Sparkle EdDSA private key in the keychain:
#      .build/artifacts/sparkle/Sparkle/bin/generate_keys
#    (run once; back up immediately, see RELEASE_GUIDE.md)
#
# 3. Homebrew create-dmg:
#      brew install create-dmg

set -euo pipefail

SIGN_ID="Developer ID Application: Jesús Jaime Ortega Cruz (GU57FJMCH4)"
TEAM_ID="GU57FJMCH4"
NOTARY_PROFILE="dab-notary"
ENTITLEMENTS="dab.entitlements"
APP_BUNDLE="dab.app"
SPARKLE_BIN=".build/artifacts/sparkle/Sparkle/bin"

if [[ $# -lt 1 ]]; then
    echo "Usage: ./release.sh <version>"
    echo "Example: ./release.sh 0.4.2-beta"
    exit 1
fi

VERSION="$1"
DMG="dist/dab-${VERSION}.dmg"
SIG="dist/dab-${VERSION}.sig.txt"

# 1. Build via build.sh. Produces dab.app with Sparkle.framework
#    embedded, rpath patched, and ad-hoc dev signature applied (we
#    overwrite that with Developer ID below).
echo "==> Building dab.app via build.sh"
VERSION="${VERSION}" ./build.sh

if [[ ! -x "${SPARKLE_BIN}/sign_update" ]]; then
    echo "Sparkle's sign_update tool not found at ${SPARKLE_BIN}/sign_update."
    echo "Run 'swift build -c release' to fetch the Sparkle artifact."
    exit 1
fi

# 2. Re-sign Sparkle.framework with Developer ID + hardened runtime +
#    timestamp. --deep is the canonical recipe for Sparkle 2: the
#    framework has nested bundles at Versions/B/ (Updater.app,
#    Autoupdate.app, XPCServices/) that the default codesign rules
#    don't traverse. Without --deep only the framework's main binary
#    and ~6 resource files get sealed; with it all 78 inner files do.
echo "==> Re-signing Sparkle.framework with Developer ID (--deep)"
codesign --force --deep --options runtime --timestamp \
    --sign "${SIGN_ID}" \
    "${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework"

# 3. Re-sign the outer dab.app. Hardened runtime + timestamp are
#    required for notarization.
echo "==> Re-signing outer dab.app with Developer ID + hardened runtime"
codesign --force --options runtime --timestamp \
    --entitlements "${ENTITLEMENTS}" \
    --sign "${SIGN_ID}" \
    "${APP_BUNDLE}"
codesign --verify --strict --verbose=2 "${APP_BUNDLE}"

# 4. Build the DMG. We use DMG (not zip) because zip extraction by
#    Finder creates AppleDouble files (._Current) next to the
#    Versions/Current symlink inside Sparkle.framework. Those files
#    aren't covered by the framework's seal, and spctl then rejects
#    with "unsealed contents present in the root directory of an
#    embedded framework". DMGs preserve the bundle byte-for-byte.
mkdir -p dist

# Build the branded window background as a HiDPI TIFF. packaging/dmg-background.png
# is the @2x master (1360x800); we downscale a @1x rep and pack both into one TIFF
# via tiffutil so Retina shows the crisp 2x image while the Finder window stays a
# logical 680x400. The icon coordinates below are in those logical points: the app
# sits at the arrow's tail, the Applications alias at its head.
DMG_BG_SRC="packaging/dmg-background.png"
DMG_BG_1X="dist/dmg-bg-1x.png"
DMG_BG_TIFF="dist/dmg-bg.tiff"
echo "==> Building DMG background TIFF"
sips -z 400 680 "${DMG_BG_SRC}" --out "${DMG_BG_1X}" >/dev/null
tiffutil -cathidpicheck "${DMG_BG_1X}" "${DMG_BG_SRC}" -out "${DMG_BG_TIFF}" >/dev/null 2>&1

rm -f "${DMG}"
echo "==> Building DMG with create-dmg"
create-dmg \
    --volname "dab" \
    --volicon "dab/Resources/AppIcon.icns" \
    --background "${DMG_BG_TIFF}" \
    --window-pos 200 120 \
    --window-size 680 400 \
    --icon-size 110 \
    --icon "${APP_BUNDLE}" 200 205 \
    --app-drop-link 480 205 \
    --hide-extension "${APP_BUNDLE}" \
    --no-internet-enable \
    "${DMG}" \
    "${APP_BUNDLE}"

# 4b. Codesign the DMG itself (Developer ID + timestamp). Notarization works
#     without this, but a signed DMG passes the stricter primary-signature
#     Gatekeeper assessment and makes tampering of the disk image detectable.
echo "==> Codesigning the DMG"
codesign --force --timestamp --sign "${SIGN_ID}" "${DMG}"

# 5. Submit the DMG to Apple's notary service and wait for the verdict.
echo "==> Submitting DMG to Apple notary service (this can take 1-15 min)"
xcrun notarytool submit "${DMG}" \
    --keychain-profile "${NOTARY_PROFILE}" \
    --wait

# 6. Staple the notarization ticket onto the DMG itself, so Gatekeeper
#    can verify offline at first launch (mounted DMG -> inner .app
#    inherits the ticket via the disk image's notarization metadata).
echo "==> Stapling notarization ticket to DMG"
xcrun stapler staple "${DMG}"
xcrun stapler validate "${DMG}"

# 7. Sign the DMG with Sparkle's EdDSA private key. The signature line
#    is what goes into the appcast's <enclosure> tag. This is a
#    separate trust path from Apple's notarization — even if Apple's
#    notary were compromised, Sparkle verifies our specific approval
#    of this exact byte sequence using the public key baked into the
#    installed app.
echo "==> Signing DMG with Sparkle EdDSA key"
"${SPARKLE_BIN}/sign_update" "${DMG}" > "${SIG}"

# 7b. Verify the Sparkle signature and that the declared length matches the
#     actual DMG bytes. A length/signature mismatch is the #1 cause of "update
#     available but installation fails" — fail loudly here rather than discover
#     it after users are already pulling a broken appcast.
ED_SIG=$(sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p' "${SIG}")
DECLARED_LEN=$(sed -n 's/.*length="\([0-9]*\)".*/\1/p' "${SIG}")
ACTUAL_LEN=$(stat -f %z "${DMG}")
if [[ -z "${ED_SIG}" ]]; then
    echo "ERROR: Sparkle signature not found in ${SIG}"
    exit 1
fi
if [[ "${DECLARED_LEN}" != "${ACTUAL_LEN}" ]]; then
    echo "ERROR: Sparkle length ${DECLARED_LEN} does not match actual DMG size ${ACTUAL_LEN}"
    exit 1
fi
"${SPARKLE_BIN}/sign_update" --verify "${DMG}" "${ED_SIG}"
echo "==> Sparkle signature verified (length ${ACTUAL_LEN})"

# 8. Final Gatekeeper sanity check on the inner app (mounted DMGs
#    inherit the staple, so spctl on the .app inside should accept).
echo "==> Final Gatekeeper assessment:"
spctl -a -vvv -t install "${APP_BUNDLE}" || true

echo ""
echo "Release artifacts:"
echo "  DMG:       ${DMG}"
echo "  Sparkle:   ${SIG}"
echo ""
echo "Next steps:"
echo "  1. gh release create v${VERSION} ${DMG} --title v${VERSION} --prerelease"
echo "  2. Add a new <item> block to docs/appcast.xml with:"
echo "       sparkle:version=${VERSION}"
echo "       enclosure url pointing at the release asset"
echo "       enclosure attrs from ${SIG}"
echo "  3. git add docs/appcast.xml && git commit && git push"
