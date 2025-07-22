#!/bin/bash

# Script to configure Xcode project with environment variables
# This script should be run before building the project

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Configuring Zettel project...${NC}"

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found!${NC}"
    echo "Please copy .env.example to .env and fill in your values:"
    echo "  cp .env.example .env"
    echo "  # Edit .env with your Apple Developer Team ID and Bundle Identifier"
    exit 1
fi

# Load environment variables
set -o allexport
source .env
set +o allexport

# Validate required variables
if [ -z "$DEVELOPMENT_TEAM" ] || [ "$DEVELOPMENT_TEAM" = "YOUR_TEAM_ID_HERE" ]; then
    echo -e "${RED}Error: DEVELOPMENT_TEAM not set in .env file${NC}"
    echo "Please set your Apple Developer Team ID in .env"
    exit 1
fi

if [ -z "$BUNDLE_IDENTIFIER" ] || [ "$BUNDLE_IDENTIFIER" = "com.yourcompany.Zettel" ]; then
    echo -e "${RED}Error: BUNDLE_IDENTIFIER not set in .env file${NC}"
    echo "Please set your Bundle Identifier in .env"
    exit 1
fi

# Backup the original project file
if [ ! -f Zettel.xcodeproj/project.pbxproj.backup ]; then
    cp Zettel.xcodeproj/project.pbxproj Zettel.xcodeproj/project.pbxproj.backup
    echo "Created backup of project.pbxproj"
fi

# Update project file with environment variables
sed -i '' "s/DEVELOPMENT_TEAM = \"\";/DEVELOPMENT_TEAM = $DEVELOPMENT_TEAM;/g" Zettel.xcodeproj/project.pbxproj
sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = \"\";/PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_IDENTIFIER;/g" Zettel.xcodeproj/project.pbxproj

echo -e "${GREEN}✓ Configured project with:${NC}"
echo "  Development Team: $DEVELOPMENT_TEAM"
echo "  Bundle Identifier: $BUNDLE_IDENTIFIER"
echo -e "${GREEN}✓ Project is ready to build!${NC}"
