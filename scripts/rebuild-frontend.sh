#!/bin/bash

# SwargFood Task Management - Frontend Rebuild Script
# Rebuilds the Flutter web application with proper routing fixes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔄 SwargFood Frontend Rebuild${NC}"
echo -e "${BLUE}=============================${NC}"
echo ""

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter is not installed or not in PATH${NC}"
    echo "Please install Flutter SDK and add it to your PATH"
    exit 1
fi

# Navigate to frontend directory
cd frontend

echo -e "${YELLOW}📦 Getting Flutter dependencies...${NC}"
flutter pub get

echo -e "${YELLOW}🧹 Cleaning previous build...${NC}"
flutter clean

echo -e "${YELLOW}🏗️ Building Flutter web application...${NC}"
flutter build web --release --base-href="/task/"

# Check if build was successful
if [ -f "build/web/index.html" ]; then
    echo -e "${GREEN}✅ Flutter build completed successfully${NC}"
    
    # Verify base href is correct
    if grep -q 'base href="/task/"' build/web/index.html; then
        echo -e "${GREEN}✅ Base href is correctly set to /task/${NC}"
    else
        echo -e "${YELLOW}⚠️ Base href might not be set correctly${NC}"
    fi
    
    # Show build size
    BUILD_SIZE=$(du -sh build/web | cut -f1)
    echo -e "${BLUE}📊 Build size: ${BUILD_SIZE}${NC}"
    
    # List main files
    echo -e "${BLUE}📁 Main build files:${NC}"
    ls -la build/web/ | head -10
    
else
    echo -e "${RED}❌ Flutter build failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 Frontend rebuild completed successfully!${NC}"
echo -e "${BLUE}Next steps:${NC}"
echo -e "  1. The Flutter app has been rebuilt with routing fixes"
echo -e "  2. The app should now properly handle authentication redirects"
echo -e "  3. Test the application at: https://ai.swargfood.com/task/"
echo ""
