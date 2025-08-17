#!/bin/bash

# Task Tool Deployment Script
# Usage: /scripts/deploy.sh

set -e  # Exit on any error

echo "🚀 Starting Task Tool deployment..."

# Configuration
REPO_DIR="/srv/task-tool"
WEB_DIR="/var/www/task/frontend/web"
BACKEND_DIR="$REPO_DIR/backend"
FRONTEND_DIR="$REPO_DIR/frontend"
API_BASE="https://ai.swargfood.com"

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

# Step 1: Pull latest code
log "📥 Pulling latest code from Git..."
cd $REPO_DIR
git fetch --all || error "Failed to fetch from Git"
git pull origin main || error "Failed to pull from Git"

# Step 2: Backend deployment
log "🔧 Deploying backend..."
cd $BACKEND_DIR

# Install/update dependencies
log "Installing backend dependencies..."
npm install || error "Failed to install backend dependencies"

# Run database migrations
log "Running database migrations..."
npm run migrate:latest || warn "Database migration failed - continuing anyway"

# Restart backend with PM2
log "Restarting backend service..."
pm2 restart task-tool-backend || error "Failed to restart backend"
pm2 save

# Wait for backend to start
sleep 3

# Check backend health
log "Checking backend health..."
if curl -f -s http://127.0.0.1:3003/task/health > /dev/null; then
    log "✅ Backend is healthy"
else
    error "❌ Backend health check failed"
fi

# Step 3: Frontend deployment
log "🎨 Deploying frontend..."
cd $FRONTEND_DIR

# Clean and get dependencies
log "Cleaning Flutter cache..."
flutter clean

log "Getting Flutter dependencies..."
flutter pub get || error "Failed to get Flutter dependencies"

# Build for web
log "Building Flutter web app..."
flutter build web --release --base-href=/task/ --dart-define=API_BASE=$API_BASE || error "Failed to build Flutter web"

# Deploy to web directory
log "Deploying frontend files..."
sudo rsync -av --delete build/web/ $WEB_DIR/ || error "Failed to deploy frontend files"

# Fix permissions
sudo chown -R ubuntu:www-data $WEB_DIR
sudo chmod -R 775 $WEB_DIR

# Step 4: Reload Nginx
log "🔄 Reloading Nginx..."
sudo nginx -t || error "Nginx configuration test failed"
sudo systemctl reload nginx || error "Failed to reload Nginx"

# Step 5: Final health checks
log "🏥 Running final health checks..."

# Check backend
if curl -f -s http://127.0.0.1:3003/task/health > /dev/null; then
    log "✅ Backend: OK"
else
    error "❌ Backend: FAILED"
fi

# Check frontend
if curl -f -s -I https://ai.swargfood.com/task/ > /dev/null; then
    log "✅ Frontend: OK"
else
    warn "⚠️  Frontend: Check manually"
fi

# Check PM2 status
log "📊 PM2 Status:"
pm2 status

log "🎉 Deployment completed successfully!"
log "🌐 Application available at: https://ai.swargfood.com/task/"

echo ""
log "📝 Post-deployment checklist:"
echo "  - Test login functionality"
echo "  - Verify project/task creation"
echo "  - Check time tracking"
echo "  - Test file attachments"
echo "  - Verify critical path view"
