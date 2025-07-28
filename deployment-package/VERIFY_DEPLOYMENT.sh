#!/bin/bash

# SwargFood Task Management - Deployment Verification Script
# Verifies that the Google OAuth fix has been successfully deployed

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 SwargFood Google OAuth Fix - Deployment Verification${NC}"
echo -e "${BLUE}====================================================${NC}"
echo ""

# Test 1: Check main application
echo -e "${YELLOW}🌐 Testing main application...${NC}"
if curl -f -s https://ai.swargfood.com/task/ > /dev/null; then
    echo -e "${GREEN}✅ Main application is accessible${NC}"
else
    echo -e "${RED}❌ Main application is not accessible${NC}"
    exit 1
fi

# Test 2: Check base href
echo -e "${YELLOW}🔗 Checking base href configuration...${NC}"
BASE_HREF=$(curl -s https://ai.swargfood.com/task/ | grep -o '<base href="[^"]*"' | head -1)
if [[ "$BASE_HREF" == '<base href="/task/">' ]]; then
    echo -e "${GREEN}✅ Base href correctly set: $BASE_HREF${NC}"
else
    echo -e "${RED}❌ Base href incorrect: $BASE_HREF${NC}"
fi

# Test 3: Check for localhost URLs in deployed build
echo -e "${YELLOW}🔍 Checking for localhost URLs in deployed build...${NC}"
LOCALHOST_COUNT=$(curl -s https://ai.swargfood.com/task/main.dart.js | grep -c -i "localhost" || echo "0")
if [[ "$LOCALHOST_COUNT" == "0" ]]; then
    echo -e "${GREEN}✅ No localhost URLs found in deployed build${NC}"
else
    echo -e "${RED}❌ Found $LOCALHOST_COUNT localhost references in deployed build${NC}"
    echo -e "${RED}   Google OAuth will fail until this is fixed${NC}"
fi

# Test 4: Check for production URLs
echo -e "${YELLOW}🌍 Checking for production URLs in deployed build...${NC}"
PRODUCTION_COUNT=$(curl -s https://ai.swargfood.com/task/main.dart.js | grep -c -i "ai.swargfood.com" || echo "0")
if [[ "$PRODUCTION_COUNT" -gt "0" ]]; then
    echo -e "${GREEN}✅ Found $PRODUCTION_COUNT production URL references${NC}"
else
    echo -e "${YELLOW}⚠️ No production URLs found (may be compressed/minified)${NC}"
fi

# Test 5: Check API endpoint
echo -e "${YELLOW}🔌 Testing API endpoint...${NC}"
API_RESPONSE=$(curl -s https://ai.swargfood.com/task/api/ | jq -r '.message' 2>/dev/null || echo "")
if [[ "$API_RESPONSE" == "SwargFood Task Management API" ]]; then
    echo -e "${GREEN}✅ API endpoint responding correctly${NC}"
else
    echo -e "${RED}❌ API endpoint not responding correctly${NC}"
fi

# Test 6: Check Google OAuth endpoint
echo -e "${YELLOW}🔐 Testing Google OAuth endpoint...${NC}"
OAUTH_RESPONSE=$(curl -s -X POST https://ai.swargfood.com/task/api/auth/google \
    -H "Content-Type: application/json" \
    -d '{"token":"test"}' | jq -r '.error' 2>/dev/null || echo "")
if [[ "$OAUTH_RESPONSE" == "Invalid Google token" ]]; then
    echo -e "${GREEN}✅ Google OAuth endpoint responding correctly${NC}"
else
    echo -e "${RED}❌ Google OAuth endpoint not responding correctly${NC}"
fi

# Test 7: Check Google Client ID in HTML
echo -e "${YELLOW}🆔 Checking Google Client ID configuration...${NC}"
CLIENT_ID=$(curl -s https://ai.swargfood.com/task/ | grep -o 'google-signin-client_id" content="[^"]*"' | cut -d'"' -f3)
EXPECTED_CLIENT_ID="792432621176-nrigk87pmes9f28db8oj49dgc6obh24m.apps.googleusercontent.com"
if [[ "$CLIENT_ID" == "$EXPECTED_CLIENT_ID" ]]; then
    echo -e "${GREEN}✅ Google Client ID correctly configured${NC}"
else
    echo -e "${RED}❌ Google Client ID incorrect or missing${NC}"
    echo -e "   Expected: $EXPECTED_CLIENT_ID"
    echo -e "   Found: $CLIENT_ID"
fi

# Test 8: Check nginx configuration
echo -e "${YELLOW}🌐 Testing nginx routing...${NC}"
NGINX_HEADERS=$(curl -s -I https://ai.swargfood.com/task/ | grep -i "server\|x-")
if echo "$NGINX_HEADERS" | grep -q "nginx"; then
    echo -e "${GREEN}✅ Nginx is serving the application${NC}"
else
    echo -e "${YELLOW}⚠️ Server headers not showing nginx${NC}"
fi

# Test 9: Check CORS headers
echo -e "${YELLOW}🔒 Checking CORS configuration...${NC}"
CORS_HEADERS=$(curl -s -I https://ai.swargfood.com/task/api/ | grep -i "access-control\|cross-origin")
if [[ -n "$CORS_HEADERS" ]]; then
    echo -e "${GREEN}✅ CORS headers configured${NC}"
else
    echo -e "${YELLOW}⚠️ No CORS headers found${NC}"
fi

# Summary
echo ""
echo -e "${BLUE}📊 Verification Summary${NC}"
echo -e "${BLUE}======================${NC}"

# Overall status
if [[ "$LOCALHOST_COUNT" == "0" && "$API_RESPONSE" == "SwargFood Task Management API" && "$OAUTH_RESPONSE" == "Invalid Google token" ]]; then
    echo -e "${GREEN}🎉 DEPLOYMENT SUCCESSFUL!${NC}"
    echo -e "${GREEN}✅ Google OAuth should now work correctly${NC}"
    echo -e "${GREEN}✅ All critical tests passed${NC}"
    echo ""
    echo -e "${YELLOW}🧪 Ready for testing at: https://ai.swargfood.com/task/${NC}"
    echo -e "${YELLOW}   Try logging in with your Google account${NC}"
    exit 0
else
    echo -e "${RED}❌ DEPLOYMENT ISSUES DETECTED${NC}"
    echo -e "${RED}   Google OAuth may still fail${NC}"
    echo -e "${RED}   Review the test results above${NC}"
    exit 1
fi
