#!/usr/bin/env bash
set -euo pipefail

APP_DIR=/var/www/task/backend
NODE_BIN=$(which node || true)
PM2_BIN=$(which pm2 || true)

if [ -z "$NODE_BIN" ]; then
  echo "Node.js not found. Install Node 18+ before running." >&2
  exit 1
fi
if [ -z "$PM2_BIN" ]; then
  echo "pm2 not found. Install globally: npm i -g pm2" >&2
  exit 1
fi

# Create directories
sudo mkdir -p $APP_DIR
sudo chown -R $USER:$USER $APP_DIR

# Sync repo contents (assumes repo is cloned on server and this script is run from backend directory)
rsync -av --delete ./ $APP_DIR/
cd $APP_DIR

# Install dependencies
npm ci --omit=dev || npm install --omit=dev

# Create .env if missing
if [ ! -f .env ]; then
  cp .env.example .env
  echo "Remember to edit .env with real credentials (DB, SMTP, etc.)."
fi

# Start or restart via PM2
if pm2 describe task-tool-backend >/dev/null; then
  pm2 restart task-tool-backend --update-env
else
  pm2 start ecosystem.config.js
fi
pm2 save

# Health check
curl -fsS http://localhost:3003/task/health && echo "\nDeploy OK" || (echo "Health check failed" >&2; exit 1)

