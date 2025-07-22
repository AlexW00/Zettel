#!/bin/bash

# Script to clean/reset the Xcode project configuration
# This removes any configured values and restores the project to its open-source state

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Cleaning Zettel project configuration...${NC}"

# Restore project file from backup if it exists
if [ -f Zettel.xcodeproj/project.pbxproj.backup ]; then
    cp Zettel.xcodeproj/project.pbxproj.backup Zettel.xcodeproj/project.pbxproj
    echo -e "${GREEN}✓ Restored project.pbxproj from backup${NC}"
else
    # Reset values to empty strings
    sed -i '' 's/DEVELOPMENT_TEAM = [^;]*;/DEVELOPMENT_TEAM = "";/g' Zettel.xcodeproj/project.pbxproj
    sed -i '' 's/PRODUCT_BUNDLE_IDENTIFIER = [^;]*;/PRODUCT_BUNDLE_IDENTIFIER = "";/g' Zettel.xcodeproj/project.pbxproj
    echo -e "${GREEN}✓ Reset DEVELOPMENT_TEAM and PRODUCT_BUNDLE_IDENTIFIER to empty values${NC}"
fi

echo -e "${GREEN}✓ Project cleaned and ready for open source distribution${NC}"
echo "Note: Remember to run './configure.sh' before building the project"
