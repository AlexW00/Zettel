#!/bin/bash

# Script to remove personal information from source files
# This prepares the codebase for open source publication

set -e

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Cleaning personal information from source files...${NC}"

# Find all Swift files and remove author information
find . -name "*.swift" -type f | while read -r file; do
    if grep -q "Created by Alexander Weichart" "$file"; then
        # Replace the "Created by" line with a generic comment
        sed -i '' 's/\/\/  Created by Alexander Weichart on [0-9][0-9]\.[0-9][0-9]\.[0-9][0-9]\./\/\/  Created for Zettel project/' "$file"
        echo "Cleaned: $file"
    fi
done

# Clean Xcode project file - remove personal development team and bundle identifier
PROJECT_FILE="Zettel.xcodeproj/project.pbxproj"
if [ -f "$PROJECT_FILE" ]; then
    # Replace development team IDs with empty strings
    sed -i '' 's/DEVELOPMENT_TEAM = [A-Z0-9]*;/DEVELOPMENT_TEAM = "";/g' "$PROJECT_FILE"
    
    # Replace bundle identifiers with empty strings (keep only Apple's default)
    sed -i '' 's/PRODUCT_BUNDLE_IDENTIFIER = com\.[^;]*;/PRODUCT_BUNDLE_IDENTIFIER = "";/g' "$PROJECT_FILE"
    
    echo "Cleaned: $PROJECT_FILE"
fi

echo -e "${GREEN}✓ Removed personal information from Swift files${NC}"
echo -e "${GREEN}✓ Removed personal information from Xcode project file${NC}"
echo -e "${GREEN}✓ Source files are ready for open source publication${NC}"
