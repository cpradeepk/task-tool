#!/bin/bash

# Task Management Backend Update Script
# This script updates the deployed backend application

set -e  # Exit on any error

# Configuration
APP_NAME="task-management-backend"
APP_DIR="/opt/$APP_NAME"
SERVICE_NAME="task-management"
USER="taskmanager"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
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

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "Please run this script as root (use sudo)"
fi

log "Starting Task Management Backend Update"

# Check if application directory exists
if [ ! -d "$APP_DIR" ]; then
    error "Application directory $APP_DIR does not exist. Run deploy-backend.sh first."
fi

# Navigate to application directory
cd $APP_DIR

# Create backup
log "Creating backup..."
BACKUP_DIR="/opt/backups/task-management-$(date +%Y%m%d_%H%M%S)"
mkdir -p /opt/backups
cp -r $APP_DIR $BACKUP_DIR
log "Backup created at $BACKUP_DIR"

# Stop the service
log "Stopping application service..."
systemctl stop $SERVICE_NAME

# Update code from repository
log "Updating code from repository..."
sudo -u $USER git fetch origin
sudo -u $USER git reset --hard origin/main

# Navigate to backend directory
cd $APP_DIR/backend

# Update dependencies
log "Updating Node.js dependencies..."
sudo -u $USER npm ci --production

# Run database migrations
log "Running database migrations..."
sudo -u $USER npx prisma migrate deploy
sudo -u $USER npx prisma generate

# Start the service
log "Starting application service..."
systemctl start $SERVICE_NAME

# Wait a moment for service to start
sleep 5

# Check service status
log "Checking service status..."
if systemctl is-active --quiet $SERVICE_NAME; then
    log "✅ Service is running successfully"
    log "✅ Update completed successfully!"
else
    error "❌ Service failed to start after update. Check logs with: journalctl -u $SERVICE_NAME"
fi

log ""
log "Update completed. Backup available at: $BACKUP_DIR"
log "To rollback if needed: sudo systemctl stop $SERVICE_NAME && sudo rm -rf $APP_DIR && sudo mv $BACKUP_DIR $APP_DIR && sudo systemctl start $SERVICE_NAME"
