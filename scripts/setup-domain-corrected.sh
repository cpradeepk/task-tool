#!/bin/bash

# Domain Configuration Setup Script for task.amtariksha.com
# This script configures the new subdomain to serve only task tool routes

set -e  # Exit on any error

# Configuration
DOMAIN="task.amtariksha.com"
NGINX_CONFIG_FILE="/etc/nginx/sites-available/$DOMAIN"
NGINX_ENABLED_FILE="/etc/nginx/sites-enabled/$DOMAIN"
REPO_DIR="/srv/task-tool"
WEB_DIR="/var/www/task/frontend/web"
BACKEND_DIR="$REPO_DIR/backend"

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

# Check if running as root or with sudo
if [[ $EUID -eq 0 ]]; then
    error "This script should not be run as root. Run as a regular user with sudo access."
fi

# Check if user has sudo access
if ! sudo -n true 2>/dev/null; then
    error "This script requires sudo access. Please run with a user that has sudo privileges."
fi

log "🚀 Starting domain configuration for $DOMAIN"
echo "=" | tr '\n' '=' | head -c 70; echo

# Step 1: Verify DNS configuration (more robust)
log "🔍 Checking DNS configuration for $DOMAIN..."

# Try multiple DNS lookup methods
DNS_RESOLVED=false
DNS_IP=""

# Method 1: nslookup
if command -v nslookup >/dev/null 2>&1; then
    if nslookup $DOMAIN >/dev/null 2>&1; then
        DNS_IP=$(nslookup $DOMAIN 2>/dev/null | grep -A1 "Name:" | tail -1 | awk '{print $2}' 2>/dev/null || echo "")
        if [ -n "$DNS_IP" ] && [ "$DNS_IP" != "" ]; then
            DNS_RESOLVED=true
        fi
    fi
fi

# Method 2: dig (if available)
if [ "$DNS_RESOLVED" = false ] && command -v dig >/dev/null 2>&1; then
    DNS_IP=$(dig +short $DOMAIN 2>/dev/null | head -1)
    if [ -n "$DNS_IP" ] && [ "$DNS_IP" != "" ]; then
        DNS_RESOLVED=true
    fi
fi

# Method 3: host (if available)
if [ "$DNS_RESOLVED" = false ] && command -v host >/dev/null 2>&1; then
    DNS_IP=$(host $DOMAIN 2>/dev/null | grep "has address" | awk '{print $4}' | head -1)
    if [ -n "$DNS_IP" ] && [ "$DNS_IP" != "" ]; then
        DNS_RESOLVED=true
    fi
fi

if [ "$DNS_RESOLVED" = true ]; then
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "unknown")
    info "DNS resolves to: $DNS_IP"
    info "Server IP: $SERVER_IP"
    
    if [ "$DNS_IP" != "$SERVER_IP" ] && [ "$SERVER_IP" != "unknown" ]; then
        warn "DNS IP ($DNS_IP) doesn't match server IP ($SERVER_IP)"
        warn "This might be okay if you're using a CDN or load balancer"
    else
        log "✅ DNS configuration looks correct"
    fi
else
    warn "⚠️  Could not resolve DNS for $DOMAIN"
    warn "This could be due to:"
    warn "  1. DNS records not yet configured"
    warn "  2. DNS propagation still in progress (can take up to 48 hours)"
    warn "  3. Network connectivity issues"
    warn "  4. DNS server issues"
    echo
    info "You can continue with the setup, but SSL certificate installation will fail if DNS isn't working."
    info "You can always run the SSL setup later with: sudo certbot --nginx -d $DOMAIN"
    echo
    read -p "Do you want to continue with the setup? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "Setup cancelled. Please configure DNS first and try again."
    fi
fi

# Step 2: Check if nginx is installed
log "🔧 Checking Nginx installation..."
if ! command -v nginx &> /dev/null; then
    error "Nginx is not installed. Please install nginx first: sudo apt install nginx"
fi
log "✅ Nginx is installed"

# Step 3: Create nginx configuration
log "📝 Creating Nginx configuration for $DOMAIN..."
if [ -f "$NGINX_CONFIG_FILE" ]; then
    warn "Nginx config already exists. Creating backup..."
    sudo cp "$NGINX_CONFIG_FILE" "$NGINX_CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Copy the nginx configuration
if [ -f "$REPO_DIR/nginx-configs/$DOMAIN" ]; then
    sudo cp "$REPO_DIR/nginx-configs/$DOMAIN" "$NGINX_CONFIG_FILE"
    log "✅ Nginx configuration created"
else
    error "Nginx configuration file not found: $REPO_DIR/nginx-configs/$DOMAIN"
fi

# Step 4: Enable the site
log "🔗 Enabling Nginx site..."
if [ -L "$NGINX_ENABLED_FILE" ]; then
    warn "Site already enabled. Removing old symlink..."
    sudo rm "$NGINX_ENABLED_FILE"
fi

sudo ln -s "$NGINX_CONFIG_FILE" "$NGINX_ENABLED_FILE"
log "✅ Site enabled"

# Step 5: Test nginx configuration
log "🧪 Testing Nginx configuration..."
if sudo nginx -t; then
    log "✅ Nginx configuration test passed"
else
    error "❌ Nginx configuration test failed"
fi

# Step 6: Reload nginx (without SSL first)
log "🔄 Reloading Nginx..."
sudo systemctl reload nginx
log "✅ Nginx reloaded"

# Step 7: Install SSL certificate with Certbot (only if DNS is working)
if [ "$DNS_RESOLVED" = true ]; then
    log "🔒 Installing SSL certificate with Certbot..."
    if ! command -v certbot &> /dev/null; then
        log "Installing Certbot..."
        sudo apt update
        sudo apt install -y certbot python3-certbot-nginx
    fi

    # Run certbot for the domain
    info "Running Certbot for $DOMAIN..."
    if sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email amtariksha@gmail.com; then
        log "✅ SSL certificate installed successfully"
    else
        warn "⚠️  SSL certificate installation failed"
        warn "You can try again later with: sudo certbot --nginx -d $DOMAIN"
    fi
else
    warn "⚠️  Skipping SSL certificate installation due to DNS issues"
    info "Once DNS is working, run: sudo certbot --nginx -d $DOMAIN"
fi

# Step 8: Update backend CORS configuration
log "🔧 Updating backend CORS configuration..."
ECOSYSTEM_CONFIG="$BACKEND_DIR/ecosystem.config.cjs"
if [ -f "$ECOSYSTEM_CONFIG" ]; then
    # Create backup
    cp "$ECOSYSTEM_CONFIG" "$ECOSYSTEM_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Update CORS_ORIGIN to include new domain
    if grep -q "CORS_ORIGIN.*$DOMAIN" "$ECOSYSTEM_CONFIG"; then
        info "CORS already includes $DOMAIN"
    else
        sed -i "s|CORS_ORIGIN: 'https://ai.swargfood.com'|CORS_ORIGIN: 'https://ai.swargfood.com,https://$DOMAIN'|g" "$ECOSYSTEM_CONFIG"
        log "✅ Backend CORS configuration updated"
    fi
else
    warn "Backend ecosystem config not found at $ECOSYSTEM_CONFIG"
fi

# Step 9: Restart backend to apply CORS changes
log "🔄 Restarting backend service..."
if pm2 describe task-tool-backend >/dev/null 2>&1; then
    pm2 restart task-tool-backend
    log "✅ Backend restarted"
else
    warn "Backend service not found in PM2"
fi

# Step 10: Final health checks
log "🏥 Running final health checks..."

# Check HTTP (should redirect to HTTPS)
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$DOMAIN/" 2>/dev/null || echo "000")
if [ "$HTTP_STATUS" = "301" ] || [ "$HTTP_STATUS" = "302" ]; then
    log "✅ HTTP to HTTPS redirect: OK"
else
    warn "⚠️  HTTP redirect status: $HTTP_STATUS"
fi

# Check HTTPS (only if SSL was installed)
if [ "$DNS_RESOLVED" = true ]; then
    if curl -f -s -I "https://$DOMAIN/task/health" > /dev/null 2>&1; then
        log "✅ HTTPS Health check: OK"
    else
        warn "⚠️  HTTPS Health check failed - check manually"
    fi

    # Check task tool frontend
    if curl -f -s -I "https://$DOMAIN/task/" > /dev/null 2>&1; then
        log "✅ Task Tool Frontend: OK"
    else
        warn "⚠️  Task Tool Frontend check failed - check manually"
    fi
fi

# Step 11: Display final information
echo
log "🎉 Domain configuration completed!"
echo "=" | tr '\n' '=' | head -c 70; echo
echo
info "Domain: https://$DOMAIN"
info "Task Tool: https://$DOMAIN/task/"
info "API Health: https://$DOMAIN/task/health"
info "API Base: https://$DOMAIN/task/api/"
echo
info "Configuration files:"
info "  - Nginx config: $NGINX_CONFIG_FILE"
if [ "$DNS_RESOLVED" = true ]; then
    info "  - SSL certificate: /etc/letsencrypt/live/$DOMAIN/"
fi
info "  - Backend config: $ECOSYSTEM_CONFIG"
echo
info "Next steps:"
info "  1. Test the domain: https://$DOMAIN/task/"
info "  2. Update frontend API_BASE if needed"
info "  3. Update any hardcoded URLs in the application"
if [ "$DNS_RESOLVED" = false ]; then
    echo
    warn "Remember to install SSL certificate once DNS is working:"
    warn "  sudo certbot --nginx -d $DOMAIN"
fi
echo
log "✅ Setup complete! Your task tool is now available at https://$DOMAIN/task/"
