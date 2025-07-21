#!/bin/bash

# Task Management Backend Deployment Script for Ubuntu Server on AWS
# This script deploys the Node.js backend to an Ubuntu server

set -e  # Exit on any error

# Configuration
APP_NAME="task-management-backend"
APP_DIR="/opt/$APP_NAME"
SERVICE_NAME="task-management"
USER="taskmanager"
NODE_VERSION="18"

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

log "Starting Task Management Backend Deployment"

# Update system packages
log "Updating system packages..."
apt update && apt upgrade -y

# Install required packages
log "Installing required packages..."
apt install -y curl wget git nginx postgresql postgresql-contrib certbot python3-certbot-nginx

# Install Node.js
log "Installing Node.js $NODE_VERSION..."
curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
apt install -y nodejs

# Verify Node.js installation
node_version=$(node --version)
npm_version=$(npm --version)
log "Node.js installed: $node_version"
log "npm installed: $npm_version"

# Create application user
log "Creating application user..."
if ! id "$USER" &>/dev/null; then
    useradd -r -s /bin/bash -d $APP_DIR $USER
    log "User $USER created"
else
    log "User $USER already exists"
fi

# Create application directory
log "Creating application directory..."
mkdir -p $APP_DIR
chown $USER:$USER $APP_DIR

# Setup PostgreSQL
log "Setting up PostgreSQL..."
systemctl start postgresql
systemctl enable postgresql

# Create database and user (if not exists)
sudo -u postgres psql -c "CREATE DATABASE taskmanagement;" 2>/dev/null || log "Database already exists"
sudo -u postgres psql -c "CREATE USER taskmanager WITH ENCRYPTED PASSWORD 'your_secure_password_here';" 2>/dev/null || log "User already exists"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE taskmanagement TO taskmanager;" 2>/dev/null || log "Privileges already granted"

# Clone or update application code
log "Deploying application code..."
if [ -d "$APP_DIR/.git" ]; then
    log "Updating existing repository..."
    cd $APP_DIR
    sudo -u $USER git pull origin main
else
    log "Cloning repository..."
    sudo -u $USER git clone https://github.com/cpradeepk/task-tool.git $APP_DIR
    cd $APP_DIR
fi

# Navigate to backend directory
cd $APP_DIR/backend

# Install dependencies
log "Installing Node.js dependencies..."
sudo -u $USER npm ci --production

# Create environment file if it doesn't exist
if [ ! -f .env ]; then
    log "Creating environment file..."
    sudo -u $USER cp .env.example .env
    warn "Please update the .env file with your actual configuration values"
fi

# Run database migrations
log "Running database migrations..."
sudo -u $USER npx prisma migrate deploy
sudo -u $USER npx prisma generate

# Create systemd service file
log "Creating systemd service..."
cat > /etc/systemd/system/$SERVICE_NAME.service << EOF
[Unit]
Description=Task Management Backend
After=network.target postgresql.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$APP_DIR/backend
ExecStart=/usr/bin/node src/server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$APP_DIR

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start service
log "Starting application service..."
systemctl daemon-reload
systemctl enable $SERVICE_NAME
systemctl start $SERVICE_NAME

# Configure Nginx
log "Configuring Nginx..."
cat > /etc/nginx/sites-available/$APP_NAME << EOF
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 86400;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
}
EOF

# Enable Nginx site
ln -sf /etc/nginx/sites-available/$APP_NAME /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
nginx -t

# Start Nginx
systemctl enable nginx
systemctl restart nginx

# Setup firewall
log "Configuring firewall..."
ufw allow ssh
ufw allow 'Nginx Full'
ufw --force enable

# Check service status
log "Checking service status..."
if systemctl is-active --quiet $SERVICE_NAME; then
    log "✅ Service is running successfully"
else
    error "❌ Service failed to start. Check logs with: journalctl -u $SERVICE_NAME"
fi

log "🎉 Deployment completed successfully!"
log ""
log "Next steps:"
log "1. Update the .env file in $APP_DIR/backend with your actual configuration"
log "2. Update the Nginx configuration with your actual domain name"
log "3. Run 'sudo certbot --nginx' to setup SSL certificates"
log "4. Restart the service: sudo systemctl restart $SERVICE_NAME"
log ""
log "Useful commands:"
log "- Check service status: sudo systemctl status $SERVICE_NAME"
log "- View logs: sudo journalctl -u $SERVICE_NAME -f"
log "- Restart service: sudo systemctl restart $SERVICE_NAME"
log "- Update application: cd $APP_DIR && sudo -u $USER git pull && sudo systemctl restart $SERVICE_NAME"
