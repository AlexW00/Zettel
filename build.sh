#!/bin/bash

set -euo pipefail

# Configure project with environment variables
./configure.sh

# Set defaults if not provided
CONFIGURATION=${CONFIGURATION:-Debug}
SCHEME=${SCHEME:-Zettel}
SIMULATOR_DEVICE=${SIMULATOR_DEVICE:-"iPhone 17"}
INCLUDE_SIMULATOR=${INCLUDE_SIMULATOR:-0}

echo "Building Zettel for device (iphoneos)..."
xcodebuild -project Zettel.xcodeproj \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath build/DerivedData \
    -destination "generic/platform=iOS" \
    build

case "$INCLUDE_SIMULATOR" in
    1|true|TRUE|yes|YES)
        echo "Building Zettel for simulator ($SIMULATOR_DEVICE)..."
    xcodebuild -project Zettel.xcodeproj \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -derivedDataPath build/DerivedData \
        -destination "platform=iOS Simulator,name=$SIMULATOR_DEVICE" \
        build
        ;;
esac
