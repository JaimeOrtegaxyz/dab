#!/bin/bash
#
# release.sh — build, sign with Developer ID, notarize, and (if Xcode's
# stapler is available) staple dab.app for distribution. Outputs
# dist/dab-<version>.zip ready for upload to GitHub Releases.
#
# Usage:
#   ./release.sh <version>
#   e.g. ./release.sh 0.4.1-beta
#
# One-time setup (stores notary credentials in the keychain so this
# script can submit unattended):
#
#   xcrun notarytool store-credentials dab-notary \
#     --apple-id <your-apple-id> \
#     --team-id GU57FJMCH4 \
#     --password <app-specific-password>
#
# Generate the app-specific password at https://appleid.apple.com
#   Account -> Sign-In and Security -> App-Specific Passwords

set -euo pipefail

SIGN_ID="Developer ID Application: Jesús Jaime Ortega Cruz (GU57FJMCH4)"
TEAM_ID="GU57FJMCH4"
NOTARY_PROFILE="dab-notary"
ENTITLEMENTS="dab.entitlements"
APP_BUNDLE="dab.app"

if [[ $# -lt 1 ]]; then
    echo "Usage: ./release.sh <version>"
    echo "Example: ./release.sh 0.4.1-beta"
    exit 1
fi

VERSION="$1"
ZIP="dist/dab-${VERSION}.zip"

# 1. Build via build.sh (ad-hoc dev sign — we re-sign below).
echo "==> Building dab.app via build.sh"
./build.sh

# 2. Re-sign with Developer ID + hardened runtime + secure timestamp.
#    --force overrides the dev-cert signature build.sh applied.
echo "==> Re-signing with Developer ID + hardened runtime"
codesign --force --options runtime --timestamp \
    --entitlements "${ENTITLEMENTS}" \
    --sign "${SIGN_ID}" \
    "${APP_BUNDLE}"
codesign --verify --strict --verbose=2 "${APP_BUNDLE}"

# 3. Zip for notary submission. ditto preserves bundle structure;
#    plain `zip` mangles it.
mkdir -p dist
rm -f "${ZIP}"
echo "==> Zipping for notary submission"
ditto -c -k --keepParent "${APP_BUNDLE}" "${ZIP}"

# 4. Submit to Apple's notary service and wait for the verdict.
echo "==> Submitting to Apple notary service (this can take 1-15 min)"
xcrun notarytool submit "${ZIP}" \
    --keychain-profile "${NOTARY_PROFILE}" \
    --wait

# 5. Staple the ticket onto the bundle if the Xcode stapler is around,
#    then re-zip so the distributable contains the stapled bundle.
echo "==> Notarization accepted. Attempting to staple"
if xcrun --find stapler >/dev/null 2>&1; then
    xcrun stapler staple "${APP_BUNDLE}"
    rm "${ZIP}"
    ditto -c -k --keepParent "${APP_BUNDLE}" "${ZIP}"
    echo "==> Stapled and re-zipped"
else
    echo "==> stapler not found (full Xcode required); shipping without"
    echo "    staple. Online Gatekeeper verification will still pass."
fi

# 6. Final assessment for the operator.
echo "==> Final Gatekeeper assessment:"
spctl -a -vvv -t install "${APP_BUNDLE}" || true

echo ""
echo "Release ready: ${ZIP}"
echo "Next: gh release create v${VERSION} ${ZIP} --title v${VERSION} --prerelease"
