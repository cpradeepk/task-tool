#!/bin/bash

# Fix SSL Setup Script for task.amtariksha.com
# This script fixes the SSL certificate issue by using HTTP-only config first

set -e

# Configuration
DOMAIN="task.amtariksha.com"
NGINX_CONFIG_FILE="/etc/nginx/sites-available/$DOMAIN"
NGINX_ENABLED_FILE="/etc/nginx/sites-enabled/$DOMAIN"
REPO_DIR="/srv/task-tool"

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
    exit 1
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

log "🔧 Fixing SSL setup for $DOMAIN"
echo "=" | tr '\n' '=' | head -c 50; echo

# Check if running with sudo
if [[ $EUID -eq 0 ]]; then
    error "This script should not be run as root. Run as a regular user with sudo access."
fi

# Step 1: Backup current config
if [ -f "$NGINX_CONFIG_FILE" ]; then
    log "📋 Creating backup of current config..."
    sudo cp "$NGINX_CONFIG_FILE" "$NGINX_CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Step 2: Use HTTP-only configuration temporarily
log "🔄 Switching to HTTP-only configuration..."
if [ -f "$REPO_DIR/nginx-configs/$DOMAIN.http-only" ]; then
    sudo cp "$REPO_DIR/nginx-configs/$DOMAIN.http-only" "$NGINX_CONFIG_FILE"
    log "✅ HTTP-only configuration installed"
else
    error "HTTP-only configuration file not found: $REPO_DIR/nginx-configs/$DOMAIN.http-only"
fi

# Step 3: Test nginx configuration
log "🧪 Testing nginx configuration..."
if sudo nginx -t; then
    log "✅ Nginx configuration test passed"
else
    error "❌ Nginx configuration test still failed"
fi

# Step 4: Reload nginx
log "🔄 Reloading nginx..."
sudo systemctl reload nginx
log "✅ Nginx reloaded"

# Step 5: Test HTTP access
log "🌐 Testing HTTP access..."
if curl -f -s -I "http://$DOMAIN/task/health" > /dev/null 2>&1; then
    log "✅ HTTP access working"
else
    warn "⚠️  HTTP access test failed - check manually"
fi

# Step 6: Install SSL certificate with Certbot
log "🔒 Installing SSL certificate with Certbot..."
if ! command -v certbot &> /dev/null; then
    log "Installing Certbot..."
    sudo apt update
    sudo apt install -y certbot python3-certbot-nginx
fi

# Run certbot for the domain
info "Running Certbot for $DOMAIN..."
info "Certbot will automatically modify the nginx configuration to add HTTPS"

if sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email amtariksha@gmail.com; then
    log "✅ SSL certificate installed successfully"
    
    # Test HTTPS access
    log "🔒 Testing HTTPS access..."
    sleep 2  # Give nginx a moment to reload
    
    if curl -f -s -I "https://$DOMAIN/task/health" > /dev/null 2>&1; then
        log "✅ HTTPS access working"
    else
        warn "⚠️  HTTPS access test failed - check manually"
    fi
    
else
    error "❌ SSL certificate installation failed"
fi

# Step 7: Final verification
log "🏥 Running final verification..."

# Check HTTP redirect
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$DOMAIN/" 2>/dev/null || echo "000")
if [ "$HTTP_STATUS" = "301" ] || [ "$HTTP_STATUS" = "302" ]; then
    log "✅ HTTP to HTTPS redirect: OK"
else
    warn "⚠️  HTTP redirect status: $HTTP_STATUS"
fi

# Check HTTPS
if curl -f -s -I "https://$DOMAIN/task/" > /dev/null 2>&1; then
    log "✅ HTTPS Task Tool: OK"
else
    warn "⚠️  HTTPS Task Tool check failed"
fi

# Step 8: Display final information
echo
log "🎉 SSL setup completed successfully!"
echo "=" | tr '\n' '=' | head -c 50; echo
echo
info "Your task tool is now available at:"
info "  - HTTPS: https://$DOMAIN/task/"
info "  - API Health: https://$DOMAIN/task/health"
info "  - API Base: https://$DOMAIN/task/api/"
echo
info "SSL Certificate Details:"
info "  - Certificate: /etc/letsencrypt/live/$DOMAIN/fullchain.pem"
info "  - Private Key: /etc/letsencrypt/live/$DOMAIN/privkey.pem"
info "  - Auto-renewal: Enabled (certbot will renew automatically)"
echo
info "Configuration Files:"
info "  - Nginx Config: $NGINX_CONFIG_FILE"
info "  - Backup: $NGINX_CONFIG_FILE.backup.*"
echo
log "✅ Setup complete! Your domain is now fully configured with SSL!"

# Optional: Show certificate info
info "SSL Certificate Information:"
sudo certbot certificates -d $DOMAIN 2>/dev/null | grep -E "(Certificate Name|Domains|Expiry Date)" || true
