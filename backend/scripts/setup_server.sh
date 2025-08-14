#!/usr/bin/env bash
set -euo pipefail

# Basic packages
sudo apt-get update
sudo apt-get install -y build-essential git curl ufw nginx python3-certbot-nginx rsync

# Node via nvm
if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  nvm install --lts
fi

# pm2
if ! command -v pm2 >/dev/null 2>&1; then
  npm i -g pm2
fi

# Firewall
sudo ufw allow OpenSSH || true
sudo ufw allow 'Nginx Full' || true
sudo ufw --force enable || true

# Create directories for app and uploads
sudo mkdir -p /var/www/task/{backend,frontend/web,uploads}
sudo chown -R $USER:$USER /var/www/task

echo "Server setup complete. Configure Nginx with your provided server block, then deploy backend with scripts/deploy_backend.sh"

