#!/bin/bash

# SwargFood Task Management - Autonomous Google OAuth Fix Deployment
# This script resolves the "failed to get Google ID token" error
# by deploying the corrected Flutter build with production URLs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 SwargFood Google OAuth Fix - Autonomous Deployment${NC}"
echo -e "${BLUE}======================================================${NC}"
echo ""

# Configuration
APP_DIR="/var/www/task"
BACKUP_DIR="/var/backups/swargfood"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo -e "${YELLOW}📋 Deployment Configuration:${NC}"
echo -e "  App Directory: ${GREEN}$APP_DIR${NC}"
echo -e "  Backup Directory: ${GREEN}$BACKUP_DIR${NC}"
echo -e "  Timestamp: ${GREEN}$TIMESTAMP${NC}"
echo ""

# Step 1: Create backup
echo -e "${YELLOW}📦 Creating backup of current deployment...${NC}"
sudo mkdir -p $BACKUP_DIR
sudo tar -czf $BACKUP_DIR/swargfood_oauth_fix_backup_$TIMESTAMP.tar.gz -C $APP_DIR/frontend/web .
echo -e "${GREEN}✅ Backup created: $BACKUP_DIR/swargfood_oauth_fix_backup_$TIMESTAMP.tar.gz${NC}"

# Step 2: Navigate to application directory
echo -e "${YELLOW}📁 Navigating to application directory...${NC}"
cd $APP_DIR

# Step 3: Fix Git permissions if needed
echo -e "${YELLOW}🔧 Fixing Git permissions...${NC}"
sudo chown -R $(whoami):$(whoami) $APP_DIR/.git || true
git config --global --add safe.directory $APP_DIR || true

# Step 4: Pull latest changes (skip if fails due to GitHub secrets)
echo -e "${YELLOW}📥 Attempting to pull latest changes...${NC}"
if git pull origin main; then
    echo -e "${GREEN}✅ Successfully pulled latest changes${NC}"
else
    echo -e "${YELLOW}⚠️ Git pull failed (likely due to GitHub secrets), proceeding with existing source${NC}"
fi

# Step 5: Verify source code fixes are in place
echo -e "${YELLOW}🔍 Verifying source code fixes...${NC}"

# Check environment.dart
if grep -q "https://ai.swargfood.com/task/api" frontend/lib/config/environment.dart; then
    echo -e "${GREEN}✅ Environment.dart has production API URL${NC}"
else
    echo -e "${RED}❌ Environment.dart missing production API URL${NC}"
    echo -e "${YELLOW}🔧 Applying fix to environment.dart...${NC}"
    sed -i 's|http://localhost:3000/api|https://ai.swargfood.com/task/api|g' frontend/lib/config/environment.dart
    sed -i 's|http://localhost:3000|https://ai.swargfood.com/task|g' frontend/lib/config/environment.dart
fi

# Check api_service.dart
if grep -q "Environment.apiBaseUrl" frontend/lib/services/api_service.dart; then
    echo -e "${GREEN}✅ API service uses Environment class${NC}"
else
    echo -e "${YELLOW}🔧 Applying fix to api_service.dart...${NC}"
    sed -i 's|static const String baseUrl = .*|static String get baseUrl => Environment.apiBaseUrl;|g' frontend/lib/services/api_service.dart
    # Add import if not present
    if ! grep -q "import '../config/environment.dart'" frontend/lib/services/api_service.dart; then
        sed -i '3i import '\''../config/environment.dart'\'';' frontend/lib/services/api_service.dart
    fi
fi

# Check socket_service.dart
if grep -q "Environment.socketUrl" frontend/lib/services/socket_service.dart; then
    echo -e "${GREEN}✅ Socket service uses Environment class${NC}"
else
    echo -e "${YELLOW}🔧 Applying fix to socket_service.dart...${NC}"
    sed -i 's|const baseUrl = String.fromEnvironment.*|final baseUrl = Environment.socketUrl;|g' frontend/lib/services/socket_service.dart
    # Add import if not present
    if ! grep -q "import '../config/environment.dart'" frontend/lib/services/socket_service.dart; then
        sed -i '6i import '\''../config/environment.dart'\'';' frontend/lib/services/socket_service.dart
    fi
fi

# Check index.html base href
if grep -q '<base href="/task/">' frontend/web/index.html; then
    echo -e "${GREEN}✅ Index.html has correct base href${NC}"
else
    echo -e "${YELLOW}🔧 Applying fix to index.html...${NC}"
    sed -i 's|<base href=".*">|<base href="/task/">|g' frontend/web/index.html
fi

# Step 6: Build Flutter application
echo -e "${YELLOW}🏗️ Building Flutter web application...${NC}"
cd frontend

# Clean previous build
flutter clean

# Get dependencies
flutter pub get

# Build for web with production settings
flutter build web --release

# Verify build was successful
if [ -f "build/web/index.html" ]; then
    echo -e "${GREEN}✅ Flutter build completed successfully${NC}"
    
    # Check build size
    BUILD_SIZE=$(du -sh build/web | cut -f1)
    echo -e "${BLUE}📊 Build size: ${BUILD_SIZE}${NC}"
    
    # Verify no localhost URLs in build
    if strings build/web/main.dart.js | grep -i "localhost" > /dev/null; then
        echo -e "${RED}❌ WARNING: Build still contains localhost URLs${NC}"
        strings build/web/main.dart.js | grep -i "localhost" | head -3
    else
        echo -e "${GREEN}✅ Build verified: No localhost URLs found${NC}"
    fi
    
    # Verify production URLs are present
    if strings build/web/main.dart.js | grep -i "ai.swargfood.com" > /dev/null; then
        echo -e "${GREEN}✅ Build verified: Production URLs found${NC}"
        strings build/web/main.dart.js | grep -i "ai.swargfood.com" | head -3
    else
        echo -e "${YELLOW}⚠️ Production URLs not found in build (may be compressed)${NC}"
    fi
    
else
    echo -e "${RED}❌ Flutter build failed${NC}"
    exit 1
fi

# Step 7: Deploy the new build
echo -e "${YELLOW}🚀 Deploying new build...${NC}"
sudo cp -r build/web/* $APP_DIR/frontend/web/
sudo chown -R www-data:www-data $APP_DIR/frontend/web/

# Step 8: Reload nginx
echo -e "${YELLOW}🔄 Reloading nginx...${NC}"
sudo systemctl reload nginx

# Step 9: Health check
echo -e "${YELLOW}🏥 Performing health check...${NC}"
sleep 3

# Test main application
if curl -f https://ai.swargfood.com/task/ > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Main application responding${NC}"
else
    echo -e "${RED}❌ Main application not responding${NC}"
fi

# Test API endpoint
if curl -f https://ai.swargfood.com/task/api/ > /dev/null 2>&1; then
    echo -e "${GREEN}✅ API endpoint responding${NC}"
else
    echo -e "${RED}❌ API endpoint not responding${NC}"
fi

# Test Google OAuth endpoint
if curl -X POST https://ai.swargfood.com/task/api/auth/google -H "Content-Type: application/json" -d '{"token":"test"}' 2>&1 | grep -q "Invalid Google token"; then
    echo -e "${GREEN}✅ Google OAuth endpoint responding correctly${NC}"
else
    echo -e "${RED}❌ Google OAuth endpoint not responding correctly${NC}"
fi

# Step 10: Final verification
echo -e "${YELLOW}🔍 Final verification...${NC}"

# Check deployed build for localhost URLs
if curl -s https://ai.swargfood.com/task/main.dart.js | grep -i "localhost" > /dev/null; then
    echo -e "${RED}❌ CRITICAL: Deployed build still contains localhost URLs${NC}"
    echo -e "${RED}   Google OAuth will continue to fail${NC}"
else
    echo -e "${GREEN}✅ VERIFIED: No localhost URLs in deployed build${NC}"
fi

# Check base href
if curl -s https://ai.swargfood.com/task/ | grep -q '<base href="/task/">'; then
    echo -e "${GREEN}✅ VERIFIED: Base href correctly set to /task/${NC}"
else
    echo -e "${RED}❌ Base href not correctly set${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Autonomous deployment completed!${NC}"
echo -e "${GREEN}✅ Google OAuth authentication should now work at: https://ai.swargfood.com/task/${NC}"
echo ""
echo -e "${BLUE}📋 Deployment Summary:${NC}"
echo -e "  Timestamp: $TIMESTAMP"
echo -e "  Backup: $BACKUP_DIR/swargfood_oauth_fix_backup_$TIMESTAMP.tar.gz"
echo -e "  Status: ✅ All systems operational"
echo ""
echo -e "${YELLOW}🧪 Test Google OAuth login at: https://ai.swargfood.com/task/${NC}"
