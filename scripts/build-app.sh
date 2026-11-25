#!/bin/bash
# Builds GamepadMouse.app into build/. With --install, copies it to ~/Applications and opens it.
#
# Signs with the first code signing certificate in your keychain that isn't revoked, so the
# Accessibility permission survives rebuilds (an ad-hoc signature changes on every build and
# macOS forgets the grant). Override with SIGN_IDENTITY="<SHA-1>".
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="build/GamepadMouse.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/GamepadMouse" "$APP/Contents/MacOS/GamepadMouse"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# True if the certificate with this SHA-1 is revoked. macOS treats an app signed with a
# revoked certificate as malware and moves it to the Trash on launch.
is_revoked() {
  local pem
  pem="$(mktemp)"
  security find-certificate -a -Z -p | awk -v h="$1" '
    /^SHA-1 hash:/ { keep = ($3 == h) }
    keep && /BEGIN CERTIFICATE/ { printing = 1 }
    printing { print }
    /END CERTIFICATE/ { printing = 0 }' > "$pem"
  local result
  result="$(security verify-cert -c "$pem" -p codeSign -R ocsp 2>&1 || true)"
  rm -f "$pem"
  [[ "$result" == *REVOKED* ]]
}

# The first code signing identity in the keychain that isn't revoked.
pick_identity() {
  local hash name
  while read -r hash name; do
    if is_revoked "$hash"; then
      echo "skipping revoked certificate $name" >&2
    else
      echo "$hash"
      return
    fi
  done < <(security find-identity -v -p codesigning | awk '/^ *[0-9]+\)/ { h = $2; $1 = $2 = ""; print h, $0 }')
}

IDENTITY="${SIGN_IDENTITY:-$(pick_identity)}"
if [ -n "$IDENTITY" ]; then
  if is_revoked "$IDENTITY"; then
    echo "error: SIGN_IDENTITY $IDENTITY is revoked; macOS would block the app as malware." >&2
    exit 1
  fi
  codesign --force --sign "$IDENTITY" "$APP"
  echo "Signed with $(security find-identity -v -p codesigning | awk -v h="$IDENTITY" '$2 == h { $1 = $2 = ""; print }')"
else
  echo "warning: no Apple Development certificate found, signing ad-hoc." >&2
  echo "         macOS will ask for Accessibility again after every rebuild." >&2
  codesign --force --sign - "$APP"
fi
echo "Built $APP"

if [ "${1:-}" = "--install" ]; then
  DEST="$HOME/Applications/GamepadMouse.app"
  pkill -x GamepadMouse 2>/dev/null && sleep 0.5 || true
  mkdir -p "$HOME/Applications"
  rm -rf "$DEST"
  cp -R "$APP" "$DEST"
  open "$DEST"
  echo "Installed and opened $DEST"
fi
