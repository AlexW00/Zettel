#!/bin/bash

# Configure project with environment variables
./configure.sh

# Load environment variables
if [ -f .env ]; then
    set -o allexport
    source .env
    set +o allexport
fi

# Set defaults if not provided
CONFIGURATION=${CONFIGURATION:-Debug}
SIMULATOR_DEVICE=${SIMULATOR_DEVICE:-"iPhone 16"}

# Build the project
xcodebuild -project Zettel.xcodeproj -scheme Zettel -configuration "$CONFIGURATION" build -destination "platform=iOS Simulator,name=$SIMULATOR_DEVICE"