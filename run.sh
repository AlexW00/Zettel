#!/bin/bash
set -euo pipefail

CONFIGURATION=${CONFIGURATION:-Debug}
UDID=${UDID:-"00008101-0016146E36E8001E"}
DERIVED_DATA_PATH=${DERIVED_DATA_PATH:-build/DerivedData}

APP="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION-iphoneos/Zettel.app"

if [[ ! -d "$APP" ]]; then
  echo "error: app bundle not found at $APP. Run build.sh first or check your paths." >&2
  exit 1
fi

xcrun devicectl device install app --device "$UDID" "$APP"

BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")

xcrun devicectl device process launch --console --terminate-existing \
  --device "$UDID" "$BUNDLE_ID"
