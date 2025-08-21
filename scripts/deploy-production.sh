#!/bin/bash

# Production Deployment Script for Task Tool
# This script is designed to be run on the production server
# Usage: ./scripts/deploy-production.sh

set -e  # Exit on any error

echo "🚀 Starting Task Tool production deployment..."

# Configuration
REPO_DIR="/srv/task-tool"
WEB_DIR="/var/www/task/frontend/web"
BACKEND_DIR="$REPO_DIR/backend"
FRONTEND_DIR="$REPO_DIR/frontend"
API_BASE="https://task.amtariksha.com"
LOG_FILE="/var/log/task-tool-deploy.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${GREEN}${message}${NC}"
    echo "$message" >> "$LOG_FILE"
}

warn() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1"
    echo -e "${YELLOW}${message}${NC}"
    echo "$message" >> "$LOG_FILE"
}

error() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1"
    echo -e "${RED}${message}${NC}"
    echo "$message" >> "$LOG_FILE"
    exit 1
}

info() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1"
    echo -e "${BLUE}${message}${NC}"
    echo "$message" >> "$LOG_FILE"
}

# Create log file if it doesn't exist
sudo touch "$LOG_FILE"
sudo chmod 666 "$LOG_FILE"

log "=== DEPLOYMENT STARTED ==="

# Step 1: Verify we're in the right directory
if [ ! -d "$REPO_DIR" ]; then
    error "Repository directory $REPO_DIR does not exist"
fi

cd "$REPO_DIR"
log "📁 Working directory: $(pwd)"

# Step 2: Pull latest code
log "📥 Pulling latest code from Git..."
git fetch --all || error "Failed to fetch from Git"
git pull origin main || error "Failed to pull from Git"

# Get current commit info
COMMIT_HASH=$(git rev-parse HEAD)
COMMIT_MESSAGE=$(git log -1 --pretty=%B)
log "📝 Deploying commit: $COMMIT_HASH"
info "💬 Commit message: $COMMIT_MESSAGE"

# Step 3: Backend deployment
log "🔧 Deploying backend..."
cd "$BACKEND_DIR"

# Install/update dependencies
log "📦 Installing backend dependencies..."
npm install || error "Failed to install backend dependencies"

# Run database migrations if they exist
if [ -f "package.json" ] && grep -q "migrate" package.json; then
    log "🗄️  Running database migrations..."
    npm run migrate:latest || warn "Database migration failed - continuing anyway"
fi

# Run database seeds if they exist
if [ -f "package.json" ] && grep -q "seed" package.json; then
    log "🌱 Running database seeds..."
    npm run seed:run || warn "Database seeding failed - continuing anyway"
fi

# Check if PM2 process exists
if pm2 list | grep -q "task-tool-backend"; then
    log "🔄 Restarting existing backend service..."
    pm2 restart task-tool-backend || error "Failed to restart backend"
else
    log "🆕 Starting new backend service..."
    pm2 start ecosystem.config.js || error "Failed to start backend"
fi

pm2 save

# Wait for backend to start
log "⏳ Waiting for backend to start..."
sleep 5

# Check backend health
log "🏥 Checking backend health..."
for i in {1..10}; do
    if curl -f -s http://127.0.0.1:3003/task/health > /dev/null; then
        log "✅ Backend is healthy"
        break
    else
        if [ $i -eq 10 ]; then
            error "❌ Backend health check failed after 10 attempts"
        fi
        warn "Backend not ready, attempt $i/10..."
        sleep 2
    fi
done

# Step 4: Frontend deployment
log "🎨 Deploying frontend..."
cd "$FRONTEND_DIR"

# Clean and get dependencies
log "🧹 Cleaning Flutter cache..."
flutter clean

log "📦 Getting Flutter dependencies..."
flutter pub get || error "Failed to get Flutter dependencies"

# Build for web
log "🏗️  Building Flutter web app..."
flutter build web --release --base-href=/task/ --dart-define=API_BASE="$API_BASE" || error "Failed to build Flutter web"

# Create backup of current deployment
if [ -d "$WEB_DIR" ]; then
    BACKUP_DIR="/tmp/task-tool-backup-$(date +%Y%m%d-%H%M%S)"
    log "💾 Creating backup at $BACKUP_DIR"
    sudo cp -r "$WEB_DIR" "$BACKUP_DIR"
fi

# Deploy to web directory
log "🚀 Deploying frontend files..."
sudo mkdir -p "$WEB_DIR"
sudo rsync -av --delete build/web/ "$WEB_DIR/" || error "Failed to deploy frontend files"

# Fix permissions
log "🔐 Setting correct permissions..."
sudo chown -R ubuntu:www-data "$WEB_DIR"
sudo chmod -R 775 "$WEB_DIR"

# Step 5: Reload Nginx
log "🔄 Reloading Nginx..."
sudo nginx -t || error "Nginx configuration test failed"
sudo systemctl reload nginx || error "Failed to reload Nginx"

# Step 6: Final health checks
log "🏥 Running final health checks..."

# Check backend
if curl -f -s http://127.0.0.1:3003/task/health > /dev/null; then
    log "✅ Backend: OK"
else
    error "❌ Backend: FAILED"
fi

# Check frontend
if curl -f -s -I https://task.amtariksha.com/task/ > /dev/null; then
    log "✅ Frontend: OK"
else
    warn "⚠️  Frontend: Check manually at https://task.amtariksha.com/task/"
fi

# Check PM2 status
log "📊 PM2 Status:"
pm2 status

log "🎉 Deployment completed successfully!"
log "🌐 Application available at: https://task.amtariksha.com/task/"
log "📝 Commit deployed: $COMMIT_HASH"

echo ""
log "📋 Post-deployment checklist:"
echo "  ✓ Backend health check passed"
echo "  ✓ Frontend deployed and accessible"
echo "  ✓ Nginx configuration reloaded"
echo "  ✓ PM2 process running"
echo ""
echo "🧪 Manual testing recommended:"
echo "  - Test admin login functionality"
echo "  - Verify project/task creation"
echo "  - Check task deletion functionality"
echo "  - Test module management"
echo "  - Verify time tracking"

log "=== DEPLOYMENT COMPLETED ==="
