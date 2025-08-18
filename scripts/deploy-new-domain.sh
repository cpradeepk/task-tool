#!/bin/bash

# Task Tool Deployment Script for New Domain (task.amtariksha.com)
# This script deploys the updated frontend and backend with the new domain configuration

set -e  # Exit on any error

echo "🚀 Starting Task Tool deployment for task.amtariksha.com..."

# Configuration
REPO_DIR="/srv/task-tool"
WEB_DIR="/var/www/task/frontend/web"
BACKEND_DIR="$REPO_DIR/backend"
FRONTEND_DIR="$REPO_DIR/frontend"
API_BASE="https://task.amtariksha.com"
DOMAIN="task.amtariksha.com"

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

# Check if running as correct user
if [[ $EUID -eq 0 ]]; then
    error "This script should not be run as root. Run as ubuntu user."
fi

log "🔄 Updating codebase..."
cd $REPO_DIR

# Step 1: Pull latest changes
log "📥 Pulling latest changes from git..."
git pull origin main || error "Failed to pull latest changes"

# Step 2: Backend deployment
log "🔧 Deploying backend..."
cd $BACKEND_DIR

# Install/update dependencies
log "Installing backend dependencies..."
npm install || error "Failed to install backend dependencies"

# Update PM2 configuration and restart
log "Restarting backend with new configuration..."
pm2 delete task-tool-backend 2>/dev/null || true
pm2 start ecosystem.config.cjs || error "Failed to start backend"
pm2 save || error "Failed to save PM2 configuration"

log "✅ Backend deployed successfully"

# Step 3: Frontend deployment
log "🎨 Deploying frontend..."
cd $FRONTEND_DIR

# Clean and get dependencies
log "Cleaning Flutter cache..."
flutter clean

log "Getting Flutter dependencies..."
flutter pub get || error "Failed to get Flutter dependencies"

# Build for web with new API base
log "Building Flutter web app for $API_BASE..."
flutter build web --release --base-href=/task/ --dart-define=API_BASE=$API_BASE || error "Failed to build Flutter web"

# Deploy to web directory
log "Deploying frontend files..."
sudo rsync -av --delete build/web/ $WEB_DIR/ || error "Failed to deploy frontend files"

# Fix permissions
sudo chown -R ubuntu:www-data $WEB_DIR
sudo chmod -R 775 $WEB_DIR

log "✅ Frontend deployed successfully"

# Step 4: Verify deployment
log "🏥 Running deployment verification..."

# Check backend health
if curl -f -s "$API_BASE/task/health" > /dev/null; then
    log "✅ Backend health check: OK"
else
    warn "⚠️  Backend health check failed"
fi

# Check frontend
if curl -f -s -I "$API_BASE/task/" > /dev/null; then
    log "✅ Frontend check: OK"
else
    warn "⚠️  Frontend check failed"
fi

# Check API endpoints
if curl -f -s -I "$API_BASE/task/api/master/statuses" > /dev/null; then
    log "✅ API endpoints: OK"
else
    warn "⚠️  API endpoints check failed"
fi

# Step 5: Display final information
echo
log "🎉 Deployment completed successfully!"
echo "=" | tr '\n' '=' | head -c 70; echo
echo
info "Application URLs:"
info "  - Main App: $API_BASE/task/"
info "  - API Health: $API_BASE/task/health"
info "  - API Base: $API_BASE/task/api/"
echo
info "Backend Status:"
pm2 status task-tool-backend || true
echo
info "Frontend Location: $WEB_DIR"
info "Backend Location: $BACKEND_DIR"
echo
log "✅ Task Tool is now running on the new domain: $DOMAIN"

# Optional: Show recent logs
info "Recent backend logs:"
pm2 logs task-tool-backend --lines 5 --nostream || true
