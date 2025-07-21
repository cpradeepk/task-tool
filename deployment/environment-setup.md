# Environment Setup Guide

## AWS Ubuntu Server Setup

### 1. EC2 Instance Requirements

**Minimum Specifications:**
- Instance Type: t3.medium (2 vCPU, 4 GB RAM)
- Storage: 20 GB SSD
- OS: Ubuntu 22.04 LTS
- Security Group: Allow HTTP (80), HTTPS (443), SSH (22)

**Recommended for Production:**
- Instance Type: t3.large (2 vCPU, 8 GB RAM)
- Storage: 50 GB SSD

### 2. Initial Server Setup

```bash
# Connect to your EC2 instance
ssh -i your-key.pem ubuntu@your-server-ip

# Update system
sudo apt update && sudo apt upgrade -y

# Install basic tools
sudo apt install -y curl wget git htop
```

### 3. Environment Variables Setup

Create `/opt/task-management-backend/backend/.env` file:

```env
# Database Configuration
DATABASE_URL="postgresql://taskmanager:your_secure_password_here@localhost:5432/taskmanagement"

# JWT Configuration
JWT_SECRET="your_super_secure_jwt_secret_here_minimum_32_characters"
JWT_REFRESH_SECRET="your_super_secure_refresh_secret_here_minimum_32_characters"
JWT_EXPIRES_IN="15m"
JWT_REFRESH_EXPIRES_IN="7d"

# Google OAuth Configuration
GOOGLE_CLIENT_ID="your_google_client_id.apps.googleusercontent.com"
GOOGLE_CLIENT_SECRET="your_google_client_secret"

# Google Drive Configuration
GOOGLE_DRIVE_FOLDER_ID="your_shared_drive_folder_id"
GOOGLE_SERVICE_ACCOUNT_EMAIL="your-service-account@your-project.iam.gserviceaccount.com"
GOOGLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYour private key here\n-----END PRIVATE KEY-----"

# Server Configuration
PORT=3000
NODE_ENV=production
CORS_ORIGIN="https://your-frontend-domain.com"

# Email Configuration (for notifications)
SMTP_HOST="smtp.gmail.com"
SMTP_PORT=587
SMTP_USER="your-email@gmail.com"
SMTP_PASS="your-app-password"
FROM_EMAIL="noreply@your-domain.com"

# File Upload Configuration
MAX_FILE_SIZE=10485760  # 10MB in bytes
ALLOWED_FILE_TYPES="image/jpeg,image/png,image/gif,application/pdf,text/plain"

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000  # 15 minutes
RATE_LIMIT_MAX_REQUESTS=100

# Logging
LOG_LEVEL="info"
```

### 4. Google Cloud Setup

#### 4.1 Create Google Cloud Project
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable the following APIs:
   - Google Drive API
   - Google+ API (for OAuth)

#### 4.2 Setup OAuth 2.0
1. Go to "Credentials" in Google Cloud Console
2. Create OAuth 2.0 Client ID
3. Add authorized origins:
   - `https://your-domain.com`
   - `http://localhost:3000` (for development)
4. Add authorized redirect URIs:
   - `https://your-domain.com/auth/google/callback`
   - `http://localhost:3000/auth/google/callback`

#### 4.3 Create Service Account
1. Go to "Service Accounts" in Google Cloud Console
2. Create new service account
3. Download JSON key file
4. Extract the private key and email for environment variables

#### 4.4 Setup Google Drive
1. Create a shared drive or folder in Google Drive
2. Share it with the service account email
3. Copy the folder ID from the URL

### 5. Database Setup

The deployment script automatically sets up PostgreSQL, but you may need to:

```bash
# Connect to PostgreSQL
sudo -u postgres psql

# Create database and user manually if needed
CREATE DATABASE taskmanagement;
CREATE USER taskmanager WITH ENCRYPTED PASSWORD 'your_secure_password_here';
GRANT ALL PRIVILEGES ON DATABASE taskmanagement TO taskmanager;
\q
```

### 6. SSL Certificate Setup

After deployment, setup SSL certificates:

```bash
# Install Certbot (already done in deployment script)
sudo apt install certbot python3-certbot-nginx

# Get SSL certificate
sudo certbot --nginx -d your-domain.com -d www.your-domain.com

# Test automatic renewal
sudo certbot renew --dry-run
```

### 7. Domain Configuration

Update your domain's DNS records:
- A record: `your-domain.com` → Your EC2 instance IP
- A record: `www.your-domain.com` → Your EC2 instance IP

### 8. Security Considerations

#### 8.1 Firewall Configuration
```bash
# UFW is configured in deployment script, but verify:
sudo ufw status

# Should show:
# 22/tcp (SSH)
# 80/tcp (HTTP)
# 443/tcp (HTTPS)
```

#### 8.2 Regular Updates
```bash
# Setup automatic security updates
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

#### 8.3 Monitoring
```bash
# Install monitoring tools
sudo apt install htop iotop nethogs

# Check service logs
sudo journalctl -u task-management -f
```

### 9. Backup Strategy

#### 9.1 Database Backup
```bash
# Create backup script
sudo tee /opt/backup-db.sh << EOF
#!/bin/bash
BACKUP_DIR="/opt/backups/db"
mkdir -p \$BACKUP_DIR
pg_dump -h localhost -U taskmanager taskmanagement > \$BACKUP_DIR/backup-\$(date +%Y%m%d_%H%M%S).sql
# Keep only last 7 days of backups
find \$BACKUP_DIR -name "backup-*.sql" -mtime +7 -delete
EOF

sudo chmod +x /opt/backup-db.sh

# Setup daily backup cron job
echo "0 2 * * * /opt/backup-db.sh" | sudo crontab -
```

#### 9.2 Application Backup
The update script automatically creates backups before updates.

### 10. Performance Optimization

#### 10.1 PM2 Process Manager (Alternative to systemd)
```bash
# Install PM2 globally
sudo npm install -g pm2

# Create PM2 ecosystem file
sudo tee /opt/task-management-backend/ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: 'task-management',
    script: './backend/src/server.js',
    instances: 'max',
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    }
  }]
};
EOF
```

#### 10.2 Nginx Optimization
Add to Nginx configuration for better performance:
```nginx
# Add to server block
gzip on;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

# Enable caching for static assets
location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

### 11. Troubleshooting

#### Common Issues:
1. **Service won't start**: Check logs with `sudo journalctl -u task-management -f`
2. **Database connection issues**: Verify DATABASE_URL in .env file
3. **Google OAuth errors**: Check client ID and redirect URIs
4. **File upload issues**: Verify Google Drive permissions and service account

#### Health Check Endpoint:
The backend includes a health check at `GET /health` for monitoring.

This setup provides a production-ready environment for the Task Management application.
