#!/bin/bash
# Builds 64 and installs it on the iPad or iPhone connected to this Mac.
#
#   curl -fsSL https://raw.githubusercontent.com/trustinelijah-ctrl/claude/claude/table-chess-ipad/install-64-on-ipad.sh | bash
#
# Needs: Xcode, signed in with your Apple ID (Xcode ▸ Settings ▸ Accounts), and the iPad or
# iPhone plugged in, unlocked, trusted, with Developer Mode on.
set -euo pipefail

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
fail() { printf '\n\033[31m%s\033[0m\n' "$*"; exit 1; }

command -v xcodebuild >/dev/null || fail "Xcode isn't installed. Install it from the App Store, open it once, then run this again."

say "1/5  Downloading the latest 64…"
DIR="$HOME/Desktop/64"
rm -rf "$DIR" && mkdir -p "$DIR" && cd "$DIR"
curl -fsSL -o 64.zip https://github.com/trustinelijah-ctrl/claude/archive/refs/heads/claude/table-chess-ipad.zip
unzip -q 64.zip
cd claude-claude-table-chess-ipad/sixtyfour

say "2/5  Finding your iPad or iPhone…"
# Xcode's device tool (devicectl) is the reliable source; xctrace is the fallback for older Xcode.
LIST=$(mktemp)
xcrun devicectl list devices --json-output "$LIST" >/dev/null 2>&1 || true
FOUND=$(/usr/bin/python3 - "$LIST" 2>/dev/null <<'PY' || true
import json, sys
try:
    devices = json.load(open(sys.argv[1]))["result"]["devices"]
except Exception:
    sys.exit()
ipads = [d for d in devices if d.get("hardwareProperties", {}).get("deviceType") in ("iPad", "iPhone")]
# Prefer one that is connected right now, then an iPad, then any paired device.
ipads.sort(key=lambda d: (d.get("connectionProperties", {}).get("tunnelState") != "connected",
                         d.get("hardwareProperties", {}).get("deviceType") != "iPad"))
for d in ipads:
    udid = d.get("hardwareProperties", {}).get("udid")
    if udid:
        print(udid + "|" + d.get("deviceProperties", {}).get("name", "device"))
        break
PY
)
UDID="${FOUND%%|*}"
NAME="${FOUND#*|}"
if [ -z "$UDID" ]; then
  LINE=$(xcrun xctrace list devices 2>/dev/null | grep -iE 'ipad|iphone' | grep -vi 'simulator' | head -1 || true)
  if [ -n "$LINE" ]; then
    UDID=$(echo "$LINE" | sed -E 's/.*\(([0-9A-Fa-f-]+)\)[[:space:]]*$/\1/')
    NAME="$LINE"
  fi
fi
if [ -z "$UDID" ]; then
  echo "   This is what the Mac sees:"
  xcrun devicectl list devices 2>&1 | sed 's/^/     /' | head -20
  fail "No iPad or iPhone found. Unplug and replug the cable, unlock it, tap Trust if asked, and run this again.
If it still isn't listed above: open Xcode ▸ Window ▸ Devices and Simulators and wait until it appears there."
fi
echo "   $NAME ($UDID)"

say "3/5  Finding your Apple ID team…"
TEAM=$(defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier 2>/dev/null | grep -oE 'teamID = [A-Z0-9]+' | head -1 | awk '{print $3}' || true)
[ -n "$TEAM" ] || TEAM=$(defaults read com.apple.dt.Xcode IDEProvisioningTeams 2>/dev/null | grep -oE 'teamID = [A-Z0-9]+' | head -1 | awk '{print $3}' || true)
[ -n "$TEAM" ] || fail "Xcode isn't signed in to an Apple ID yet.
Open Xcode ▸ Settings ▸ Accounts, click +, sign in with your Apple ID, then run this again."
echo "   Team $TEAM"
# A free Apple ID needs an app ID nobody else has used, so make one from your Mac user name.
ME=$(echo "${USER:-player}" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')
BUNDLE="com.${ME}.sixtyfour"

say "4/5  Building (takes a few minutes the first time)…"
xcodebuild -project SixtyFour.xcodeproj -scheme SixtyFour -configuration Debug \
  -destination "id=$UDID" -derivedDataPath build -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM" PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE" CODE_SIGN_STYLE=Automatic \
  build > build.log 2>&1 || {
    grep -E "error:" build.log | sort -u | head -20
    fail "The build didn't finish. The lines above say why; the full log is in $PWD/build.log"
  }

say "5/5  Installing on $NAME…"
APP=$(find build/Build/Products -maxdepth 2 -name 'SixtyFour.app' -path '*iphoneos*' | head -1)
[ -n "$APP" ] || fail "The app was built but couldn't be found in build/Build/Products."
xcrun devicectl device install app --device "$UDID" "$APP" >/dev/null
if xcrun devicectl device process launch --device "$UDID" "$BUNDLE" >/dev/null 2>&1; then
  say "Done. 64 is open on $NAME."
else
  say "Installed. One last step on $NAME:"
  echo "   Settings ▸ General ▸ VPN & Device Management ▸ your Apple ID ▸ Trust."
  echo "   Then tap the 64 icon on the home screen."
fi
echo "With a free Apple ID the app opens for 7 days; run this command again to renew it."
