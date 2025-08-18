# Domain Configuration Setup: task.amtariksha.com

This document provides instructions for setting up the new subdomain `task.amtariksha.com` to serve only the task management tool routes.

## Overview

- **Current Setup**: `ai.swargfood.com` serves the task tool at `/task/*`
- **New Setup**: `task.amtariksha.com` will serve only task tool routes
- **DNS**: User has already configured DNS records for `task.amtariksha.com`
- **SSL**: Automatic SSL certificate setup using Certbot

## Prerequisites

1. **DNS Configuration**: Ensure `task.amtariksha.com` points to your server IP
2. **Server Access**: SSH access to the server with sudo privileges
3. **Existing Setup**: Task tool should already be running on the server
4. **Nginx**: Nginx should be installed and running

## Quick Setup

### 1. Run the Setup Script

```bash
# Navigate to the project directory
cd /srv/task-tool

# Make the setup script executable
chmod +x scripts/setup-domain.sh

# Run the setup script
./scripts/setup-domain.sh
```

The script will:
- ✅ Verify DNS configuration
- ✅ Create Nginx configuration for the new domain
- ✅ Enable the site in Nginx
- ✅ Install SSL certificate with Certbot
- ✅ Update backend CORS configuration
- ✅ Restart services
- ✅ Run health checks

### 2. Verify the Setup

```bash
# Make the verification script executable
chmod +x scripts/verify-domain.sh

# Run verification tests
./scripts/verify-domain.sh
```

## Manual Setup (Alternative)

If you prefer to set up manually:

### 1. Create Nginx Configuration

```bash
# Copy the nginx configuration
sudo cp nginx-configs/task.amtariksha.com /etc/nginx/sites-available/task.amtariksha.com

# Enable the site
sudo ln -s /etc/nginx/sites-available/task.amtariksha.com /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx
```

### 2. Install SSL Certificate

```bash
# Install certbot if not already installed
sudo apt update
sudo apt install -y certbot python3-certbot-nginx

# Get SSL certificate
sudo certbot --nginx -d task.amtariksha.com --non-interactive --agree-tos --email amtariksha@gmail.com
```

### 3. Update Backend CORS

Edit `/srv/task-tool/backend/ecosystem.config.cjs`:

```javascript
// Change this line:
CORS_ORIGIN: 'https://ai.swargfood.com',

// To this:
CORS_ORIGIN: 'https://ai.swargfood.com,https://task.amtariksha.com',
```

Then restart the backend:

```bash
pm2 restart task-tool-backend
```

## Configuration Details

### Nginx Configuration Features

- **HTTPS Redirect**: All HTTP traffic redirected to HTTPS
- **Root Redirect**: Root domain redirects to `/task/`
- **API Proxying**: All `/task/api/*` requests proxied to backend
- **Socket.IO Support**: Real-time features via `/task/socket.io/`
- **Static Assets**: Optimized caching for CSS, JS, images
- **Security Headers**: Comprehensive security header configuration
- **Gzip Compression**: Enabled for better performance
- **File Uploads**: Support for file uploads up to 50MB

### Backend Updates

- **CORS Configuration**: Updated to allow requests from new domain
- **No Code Changes**: Backend code remains unchanged
- **Same Database**: Uses existing database and configuration

### SSL Certificate

- **Auto-Renewal**: Certbot automatically renews certificates
- **Strong Security**: Modern SSL configuration with security headers
- **HSTS**: HTTP Strict Transport Security enabled

## Testing the Setup

### 1. Basic Connectivity

```bash
# Test DNS resolution
nslookup task.amtariksha.com

# Test HTTPS
curl -I https://task.amtariksha.com/task/

# Test API health
curl https://task.amtariksha.com/task/health
```

### 2. Frontend Application

Visit: https://task.amtariksha.com/task/

You should see the task management application loading correctly.

### 3. API Endpoints

Test API endpoints:
- https://task.amtariksha.com/task/api/master/statuses
- https://task.amtariksha.com/task/api/projects

## Troubleshooting

### Common Issues

1. **DNS Not Resolving**
   - Verify DNS records are properly configured
   - Wait for DNS propagation (up to 24 hours)

2. **SSL Certificate Issues**
   - Ensure domain resolves before running Certbot
   - Check firewall allows ports 80 and 443

3. **Backend Not Accessible**
   - Verify backend is running: `pm2 status`
   - Check backend logs: `pm2 logs task-tool-backend`

4. **CORS Errors**
   - Ensure CORS_ORIGIN includes new domain
   - Restart backend after CORS changes

### Log Files

- **Nginx Access**: `/var/log/nginx/task.amtariksha.com.access.log`
- **Nginx Error**: `/var/log/nginx/task.amtariksha.com.error.log`
- **Backend Logs**: `pm2 logs task-tool-backend`
- **SSL Logs**: `/var/log/letsencrypt/letsencrypt.log`

## Maintenance

### SSL Certificate Renewal

Certificates auto-renew, but you can test renewal:

```bash
# Test renewal
sudo certbot renew --dry-run

# Force renewal if needed
sudo certbot renew --force-renewal
```

### Nginx Configuration Updates

After making changes to nginx config:

```bash
# Test configuration
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx
```

## Security Considerations

- **Firewall**: Ensure only necessary ports (22, 80, 443) are open
- **SSL**: Strong SSL configuration with modern ciphers
- **Headers**: Security headers prevent common attacks
- **Access**: Restrict SSH access to specific IPs if possible

## Final Notes

- The new domain serves **only** the task tool (`/task/*` routes)
- The original domain (`ai.swargfood.com`) continues to work
- Both domains share the same backend and database
- No data migration or application changes required
- Users can access the tool from either domain
