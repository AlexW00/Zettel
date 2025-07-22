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

# Clean Swift files first - remove author information
echo "Cleaning Swift files..."
find . -name "*.swift" -type f | while read -r file; do
    if grep -q "Created by Alexander Weichart" "$file"; then
        # Replace the "Created by" line with a generic comment
        sed -i '' 's/\/\/  Created by Alexander Weichart on [0-9][0-9]\.[0-9][0-9]\.[0-9][0-9]\./\/\/  Created for Zettel project/' "$file"
        echo "Cleaned: $file"
    fi
done

# Clean Xcode project file
echo "Cleaning Xcode project file..."

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

echo -e "${GREEN}✓ Cleaned Swift files${NC}"
echo -e "${GREEN}✓ Project cleaned and ready for open source distribution${NC}"
echo "Note: Remember to run './configure.sh' before building the project"
