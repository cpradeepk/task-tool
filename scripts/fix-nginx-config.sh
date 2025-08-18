#!/bin/bash

# Quick fix for nginx configuration syntax error
# This script fixes the invalid "must-revalidate" value in the nginx config

set -e

# Configuration
DOMAIN="task.amtariksha.com"
NGINX_CONFIG_FILE="/etc/nginx/sites-available/$DOMAIN"
REPO_DIR="/srv/task-tool"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

log "🔧 Fixing nginx configuration syntax error for $DOMAIN"

# Check if running with sudo
if [[ $EUID -eq 0 ]]; then
    error "This script should not be run as root. Run as a regular user with sudo access."
fi

# Check if config file exists
if [ ! -f "$NGINX_CONFIG_FILE" ]; then
    error "Nginx config file not found: $NGINX_CONFIG_FILE"
fi

# Create backup
log "📋 Creating backup of current config..."
sudo cp "$NGINX_CONFIG_FILE" "$NGINX_CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"

# Apply fixes
log "🔧 Applying configuration fixes..."

# Fix 1: Replace invalid referrer-policy value
sudo sed -i 's/no-referrer-when-downgrade/strict-origin-when-cross-origin/g' "$NGINX_CONFIG_FILE"

# Fix 2: Remove invalid gzip_proxied value
sudo sed -i 's/gzip_proxied expired no-cache no-store private must-revalidate auth;/gzip_proxied expired no-cache no-store private auth;/g' "$NGINX_CONFIG_FILE"

log "✅ Configuration fixes applied"

# Test nginx configuration
log "🧪 Testing nginx configuration..."
if sudo nginx -t; then
    log "✅ Nginx configuration test passed!"
    
    # Reload nginx
    log "🔄 Reloading nginx..."
    sudo systemctl reload nginx
    log "✅ Nginx reloaded successfully"
    
    # Test the site
    log "🌐 Testing site accessibility..."
    if curl -f -s -I "https://$DOMAIN/task/health" > /dev/null 2>&1; then
        log "✅ Site is accessible and working!"
    else
        warn "⚠️  Site test failed - check manually"
    fi
    
else
    error "❌ Nginx configuration test still failed. Please check the configuration manually."
fi

log "🎉 Nginx configuration fix completed successfully!"
echo
log "You can now proceed with the domain setup:"
log "  1. Test the configuration: sudo nginx -t"
log "  2. Continue with SSL setup: sudo certbot --nginx -d $DOMAIN"
log "  3. Run the full verification: ./scripts/verify-domain.sh"
