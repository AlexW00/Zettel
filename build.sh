#!/bin/bash

set -euo pipefail

usage() {
    cat <<EOF
Usage: ./build.sh <platform>

Platforms:
  ios      Build iOS app (device, and optional simulator if INCLUDE_SIMULATOR is enabled)
  macos    Build macOS app
EOF
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
    usage
    exit 0
fi

if [[ $# -ne 1 ]]; then
    echo "error: build.sh requires exactly one platform argument." >&2
    usage >&2
    exit 1
fi

PLATFORM="$1"

# Configure project with environment variables
./configure.sh

# Set defaults if not provided
CONFIGURATION=${CONFIGURATION:-Debug}
SIMULATOR_DEVICE=${SIMULATOR_DEVICE:-"iPhone 17"}
INCLUDE_SIMULATOR=${INCLUDE_SIMULATOR:-0}

case "$PLATFORM" in
    ios)
        SCHEME=${SCHEME:-Zettel}
        echo "Building Zettel for iOS device..."
        xcodebuild -project Zettel.xcodeproj \
            -scheme "$SCHEME" \
            -configuration "$CONFIGURATION" \
            -derivedDataPath build/DerivedData \
            -destination "generic/platform=iOS" \
            build

        case "$INCLUDE_SIMULATOR" in
            1|true|TRUE|yes|YES)
                echo "Building Zettel for iOS simulator ($SIMULATOR_DEVICE)..."
                xcodebuild -project Zettel.xcodeproj \
                    -scheme "$SCHEME" \
                    -configuration "$CONFIGURATION" \
                    -derivedDataPath build/DerivedData \
                    -destination "platform=iOS Simulator,name=$SIMULATOR_DEVICE" \
                    build
                ;;
        esac
        ;;
    macos)
        SCHEME=${SCHEME:-ZettelMac}
        echo "Building Zettel for macOS..."
        xcodebuild -project Zettel.xcodeproj \
            -scheme "$SCHEME" \
            -configuration "$CONFIGURATION" \
            -derivedDataPath build/DerivedData \
            -destination "platform=macOS" \
            build
        ;;
    *)
        echo "error: unsupported platform '$PLATFORM'." >&2
        usage >&2
        exit 1
        ;;
esac
