#!/bin/bash

# Domain Verification Script for task.amatariksha.com
# This script verifies that the domain configuration is working correctly

set -e

# Configuration
DOMAIN="task.amatariksha.com"
API_BASE="https://$DOMAIN"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

fail() {
    echo -e "${RED}❌ $1${NC}"
}

log "🔍 Verifying domain configuration for $DOMAIN"
echo "=" | tr '\n' '=' | head -c 70; echo

# Test 1: DNS Resolution
info "Testing DNS resolution..."
if nslookup $DOMAIN > /dev/null 2>&1; then
    DNS_IP=$(nslookup $DOMAIN | grep -A1 "Name:" | tail -1 | awk '{print $2}')
    success "DNS resolves to: $DNS_IP"
else
    fail "DNS resolution failed"
    exit 1
fi

# Test 2: HTTPS Certificate
info "Testing HTTPS certificate..."
if curl -f -s -I "https://$DOMAIN" > /dev/null 2>&1; then
    success "HTTPS certificate is valid"
else
    fail "HTTPS certificate test failed"
fi

# Test 3: HTTP to HTTPS Redirect
info "Testing HTTP to HTTPS redirect..."
HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://$DOMAIN")
if [ "$HTTP_RESPONSE" = "301" ] || [ "$HTTP_RESPONSE" = "302" ]; then
    success "HTTP to HTTPS redirect working (Status: $HTTP_RESPONSE)"
else
    fail "HTTP to HTTPS redirect not working (Status: $HTTP_RESPONSE)"
fi

# Test 4: Root Redirect
info "Testing root redirect to /task/..."
ROOT_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN/")
if [ "$ROOT_RESPONSE" = "301" ] || [ "$ROOT_RESPONSE" = "302" ]; then
    success "Root redirect working (Status: $ROOT_RESPONSE)"
else
    warn "Root redirect may not be working (Status: $ROOT_RESPONSE)"
fi

# Test 5: Backend Health Check
info "Testing backend health check..."
if curl -f -s "$API_BASE/task/health" > /dev/null; then
    HEALTH_RESPONSE=$(curl -s "$API_BASE/task/health")
    success "Backend health check passed"
    info "Health response: $HEALTH_RESPONSE"
else
    fail "Backend health check failed"
fi

# Test 6: API Endpoints
info "Testing API endpoints..."
if curl -f -s -I "$API_BASE/task/api/master/statuses" > /dev/null; then
    success "API endpoints accessible"
else
    fail "API endpoints not accessible"
fi

# Test 7: Frontend Application
info "Testing frontend application..."
if curl -f -s -I "$API_BASE/task/" > /dev/null; then
    success "Frontend application accessible"
else
    fail "Frontend application not accessible"
fi

# Test 8: Static Assets
info "Testing static assets..."
if curl -f -s -I "$API_BASE/task/favicon.ico" > /dev/null; then
    success "Static assets accessible"
else
    warn "Some static assets may not be accessible"
fi

# Test 9: Socket.IO
info "Testing Socket.IO endpoint..."
SOCKET_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$API_BASE/task/socket.io/")
if [ "$SOCKET_RESPONSE" = "200" ] || [ "$SOCKET_RESPONSE" = "400" ]; then
    success "Socket.IO endpoint accessible (Status: $SOCKET_RESPONSE)"
else
    warn "Socket.IO endpoint may have issues (Status: $SOCKET_RESPONSE)"
fi

# Test 10: File Upload Directory
info "Testing file upload directory..."
UPLOAD_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$API_BASE/task/uploads/")
if [ "$UPLOAD_RESPONSE" = "403" ] || [ "$UPLOAD_RESPONSE" = "200" ]; then
    success "Upload directory configured (Status: $UPLOAD_RESPONSE)"
else
    warn "Upload directory may have issues (Status: $UPLOAD_RESPONSE)"
fi

# Test 11: Security Headers
info "Testing security headers..."
HEADERS=$(curl -s -I "https://$DOMAIN/task/" | grep -E "(X-Frame-Options|X-XSS-Protection|X-Content-Type-Options|Strict-Transport-Security)")
if [ -n "$HEADERS" ]; then
    success "Security headers present"
    echo "$HEADERS" | while read -r line; do
        info "  $line"
    done
else
    warn "Security headers may be missing"
fi

# Test 12: Gzip Compression
info "Testing Gzip compression..."
GZIP_TEST=$(curl -s -H "Accept-Encoding: gzip" -I "$API_BASE/task/" | grep -i "content-encoding: gzip")
if [ -n "$GZIP_TEST" ]; then
    success "Gzip compression enabled"
else
    warn "Gzip compression may not be enabled"
fi

echo
log "🎉 Domain verification completed!"
echo "=" | tr '\n' '=' | head -c 70; echo
echo
info "Domain: https://$DOMAIN"
info "Task Tool: https://$DOMAIN/task/"
info "API Health: https://$DOMAIN/task/health"
info "API Base: https://$DOMAIN/task/api/"
echo
info "All tests completed. Check any warnings above."
log "✅ Domain verification finished!"
