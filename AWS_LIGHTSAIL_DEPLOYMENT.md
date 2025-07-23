# 🚀 AWS Lightsail Deployment Guide - SwargFood Task Management Tool

Complete step-by-step guide for deploying the SwargFood Task Management application to AWS Lightsail following the SWARGFOOD deployment patterns and configurations.

## 📍 **SwargFood Deployment Configuration**

- **Domain**: `ai.swargfood.com/task`
- **Installation Path**: `/var/www/task`
- **Backend API**: `ai.swargfood.com/task/api/`
- **Frontend**: `ai.swargfood.com/task/`
- **Process Name**: `swargfood-task-management`

## 📋 Prerequisites

- AWS Account with Lightsail access
- Domain: `ai.swargfood.com` (configured to point to Lightsail instance)
- Google Cloud Console account for OAuth
- Basic knowledge of Linux command line
- SSH access to the server

## 🏗️ Architecture Overview

**SwargFood Application Stack:**
- **Frontend**: Flutter Web (served by Nginx at `/task/`)
- **Backend**: Node.js with Express + Prisma ORM (PM2 managed)
- **Database**: PostgreSQL 15 (local installation)
- **Cache**: Redis (optional, for sessions and real-time features)
- **Reverse Proxy**: Nginx (configured for SwargFood domain)
- **Process Manager**: PM2 with SwargFood-specific configuration
- **File Storage**: Local uploads directory at `/var/www/task/uploads`

**Phase 3 Features Supported:**
- ✅ Task Dependencies with Critical Path Analysis
- ✅ Real-time Time Tracking with Timers
- ✅ Task Templates and Recurring Tasks
- ✅ Interactive Dependency Graphs
- ✅ PERT Estimation vs Actual Tracking
- ✅ Task Comments and Collaboration
- ✅ Real-time Chat and Notifications
- ✅ File Sharing and Upload Management

---

## 🚀 Step 1: Create AWS Lightsail Instance

### 1.1 Launch Instance
1. Go to [AWS Lightsail Console](https://lightsail.aws.amazon.com/)
2. Click **"Create instance"**
3. **Platform**: Linux/Unix
4. **Blueprint**: Ubuntu 22.04 LTS
5. **Instance plan**: 
   - **Development**: $10/month (2 GB RAM, 1 vCPU, 60 GB SSD)
   - **Production**: $20/month (4 GB RAM, 2 vCPU, 80 GB SSD) - **Recommended**
6. **Instance name**: `task-management-app`
7. Click **"Create instance"**

### 1.2 Configure Networking
1. Go to **Networking** tab of your instance
2. Create **Static IP** and attach to instance
3. **Configure DNS**: Point `ai.swargfood.com` A record to your static IP
4. **Firewall rules** - Add these ports:
   ```
SSH (22) - Already enabled
   HTTP (80) - Add this
   HTTPS (443) - Add this
   Custom (3003) - Add for backend API (temporary, remove after nginx setup)
```

### 1.3 Connect to Instance
```bash
# Download SSH key from Lightsail console
# Connect via SSH
ssh -i LightsailDefaultKey-us-east-1.pem ubuntu@YOUR_STATIC_IP

# Verify domain resolution (optional)
nslookup ai.swargfood.com
```

---

## 🔧 Step 2: Server Setup and Dependencies

### 2.1 System Update and Basic Tools
```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install essential tools
sudo apt install -y curl wget git htop unzip software-properties-common

# Install build essentials
sudo apt install -y build-essential
```

### 2.2 Install Node.js 18
```bash
# Add NodeSource repository
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -

# Install Node.js
sudo apt-get install -y nodejs

# Verify installation
node --version  # Should show v18.x.x
npm --version
```

### 2.3 Install Docker and Docker Compose
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker ubuntu

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Logout and login again for group changes
exit
# Reconnect via SSH

# Verify Docker installation
docker --version
docker-compose --version
```

### 2.4 Install PostgreSQL
```bash
# Install PostgreSQL
sudo apt install -y postgresql postgresql-contrib

# Start and enable PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Verify PostgreSQL is running
sudo systemctl status postgresql
```

### 2.5 Install PM2 (Process Manager)
```bash
# Install PM2 globally
sudo npm install -g pm2

# Setup PM2 startup script
pm2 startup
# Follow the instructions shown
```

### 2.6 Install Nginx
```bash
# Install Nginx
sudo apt install -y nginx

# Start and enable Nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Verify Nginx is running
sudo systemctl status nginx
```

---

## 📦 Step 3: Application Deployment

### 3.1 Clone Repository (SwargFood Configuration)
```bash
# Create SwargFood application directory
sudo mkdir -p /var/www/task
sudo chown -R ubuntu:ubuntu /var/www/task

# Clone the repository
cd /var/www/task
git clone https://github.com/cpradeepk/task-tool.git .

# Make deployment scripts executable
chmod +x deploy.sh
chmod +x swargfood-deploy.sh

# Verify files
ls -la
```

### 3.2 Environment Configuration (SwargFood Specific)
```bash
# Create production environment file from SwargFood template
cp .env.production .env

# Edit environment variables for SwargFood deployment
nano .env
```

**SwargFood Required Environment Variables:**
```env
# Database Configuration (Local PostgreSQL)
DATABASE_URL="postgresql://taskuser:CHANGE_THIS_PASSWORD@localhost:5432/taskmanagement"

# JWT Secrets (Generate strong 32+ character strings)
JWT_SECRET="your-super-secure-jwt-secret-32-chars-minimum-length"
JWT_REFRESH_SECRET="your-super-secure-refresh-secret-32-chars-minimum-length"
JWT_EXPIRES_IN="15m"
JWT_REFRESH_EXPIRES_IN="7d"

# Google OAuth (Get from Google Cloud Console)
GOOGLE_CLIENT_ID="your-production-google-client-id.apps.googleusercontent.com"
GOOGLE_CLIENT_SECRET="your-production-google-client-secret"

# SwargFood Server Configuration
NODE_ENV="production"
PORT=3003
API_BASE_URL="https://ai.swargfood.com/task"
FRONTEND_URL="https://ai.swargfood.com/task"

# SwargFood CORS Configuration
CORS_ORIGIN="https://ai.swargfood.com"
SOCKET_CORS_ORIGIN="https://ai.swargfood.com"

# SwargFood File Upload Configuration
UPLOAD_DIR="/var/www/task/uploads"
MAX_FILE_SIZE=10485760

# SwargFood Email Configuration
SMTP_HOST="smtp.gmail.com"
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER="your-email@gmail.com"
SMTP_PASS="your-app-password"
FROM_EMAIL="noreply@swargfood.com"
FROM_NAME="SwargFood Task Management"

# Redis Configuration (Optional)
REDIS_URL="redis://localhost:6379"

# SwargFood Logging Configuration
LOG_LEVEL="error"
LOG_FILE="/var/www/task/logs/app.log"

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=50

# SwargFood Feature Flags
ENABLE_CHAT=true
ENABLE_FILE_SHARING=true
ENABLE_TIME_TRACKING=true
ENABLE_NOTIFICATIONS=true
ENABLE_ACTIVITY_LOGS=true

# Production Settings
DEBUG=false
ENABLE_SWAGGER=false
ENABLE_MORGAN_LOGGING=false
```

### 3.3 Database Setup (SwargFood Configuration)
```bash
# Switch to postgres user and create database
sudo -u postgres psql

# Create database and user for SwargFood
CREATE DATABASE taskmanagement;
CREATE USER taskuser WITH PASSWORD 'your-secure-password';
GRANT ALL PRIVILEGES ON DATABASE taskmanagement TO taskuser;
ALTER USER taskuser CREATEDB;
\q
```

### 3.4 Create Required Directories
```bash
# Create logs and uploads directories
mkdir -p /var/www/task/logs
mkdir -p /var/www/task/uploads

# Set proper permissions
sudo chown -R ubuntu:ubuntu /var/www/task/logs
sudo chown -R ubuntu:ubuntu /var/www/task/uploads
chmod -R 755 /var/www/task/uploads
```

---

## 🚀 Step 4: SwargFood Application Deployment

### 4.1 Option 1: Automated SwargFood Deployment (Recommended)
```bash
# Run the SwargFood automated deployment script
cd /var/www/task
./swargfood-deploy.sh

# The script will:
# - Install all dependencies
# - Setup the database
# - Configure the environment
# - Deploy the application
# - Setup Nginx configuration
# - Configure PM2 process management
```

### 4.2 Option 2: Manual SwargFood Deployment
```bash
# Navigate to backend directory
cd /var/www/task/backend

# Install production dependencies
npm install --production

# Generate Prisma client
npm run generate

# Run database migrations
npm run migrate:prod

# Start application with PM2 using SwargFood configuration
pm2 start ecosystem.config.js --env production

# Save PM2 configuration
pm2 save

# Setup PM2 to start on boot
pm2 startup
```

### 4.3 Verify SwargFood Application
```bash
# Check PM2 status
pm2 status

# Check application health
curl http://localhost:3000/health

# Check database connection
cd /var/www/task/backend
npx prisma db pull

# Test API endpoints
curl http://localhost:3000/api/health
```

---

## 🌐 Step 5: SwargFood Nginx Configuration

### 5.1 Create SwargFood Nginx Configuration
```bash
# Create SwargFood-specific Nginx configuration
sudo nano /etc/nginx/sites-available/swargfood-task-management
```

**SwargFood Nginx Configuration:**
```nginx
server {
    listen 80;
    server_name ai.swargfood.com;

    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";

    # SwargFood Task Management Backend API
    location /task/api/ {
        proxy_pass http://localhost:3003/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # SwargFood Task Management Socket.IO WebSocket connections
    location /task/socket.io/ {
        proxy_pass http://localhost:3003/socket.io/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket specific timeouts
        proxy_read_timeout 86400;
    }

    # SwargFood Task Management Frontend
    location /task/ {
        alias /var/www/task/frontend/build/web/;
        index index.html;
        try_files $uri $uri/ /task/index.html;

        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }

        # Cache HTML files for shorter time
        location ~* \.html$ {
            expires 1h;
            add_header Cache-Control "public";
        }
    }

    # SwargFood File uploads and static assets
    location /task/uploads/ {
        alias /var/www/task/uploads/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Deny access to sensitive files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
```

### 5.2 Enable SwargFood Site
```bash
# Backup default config
sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup

# Disable default site (if enabled)
sudo unlink /etc/nginx/sites-enabled/default 2>/dev/null || true

# Enable SwargFood site
sudo ln -s /etc/nginx/sites-available/swargfood-task-management /etc/nginx/sites-enabled/

# Test nginx configuration
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx
```

### 5.3 Verify HTTP Access
```bash
# Test SwargFood frontend
curl http://ai.swargfood.com/task/

# Test SwargFood API
curl http://ai.swargfood.com/task/api/health

# Test in browser
# http://ai.swargfood.com/task/
```

---

## 🔒 Step 6: SSL Certificate Setup

### 6.1 Install Certbot
```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx
```

### 6.2 Get SSL Certificate for SwargFood Domain
```bash
# Get SSL certificate for ai.swargfood.com
sudo certbot --nginx -d ai.swargfood.com

# Test automatic renewal
sudo certbot renew --dry-run
```

### 6.3 Configure Auto-renewal
```bash
# Add cron job for auto-renewal
echo "0 12 * * * /usr/bin/certbot renew --quiet" | sudo crontab -
```

### 6.4 Verify HTTPS Access
```bash
# Test HTTPS access
curl https://ai.swargfood.com/task/
curl https://ai.swargfood.com/task/api/health

# Verify SSL certificate
openssl s_client -connect ai.swargfood.com:443 -servername ai.swargfood.com
```

---

## 📊 Step 7: Monitoring and Health Checks

### 7.1 Setup SwargFood Health Check Script
```bash
# Create SwargFood health check script
sudo tee /usr/local/bin/swargfood-health-check.sh << 'EOF'
#!/bin/bash
# SwargFood Task Management Health Check Script

echo "=== SwargFood Task Management Health Check ==="
echo "Date: $(date)"

# Check PM2 processes
echo "PM2 Processes:"
pm2 status

# Check backend health
echo "Backend Health:"
curl -s http://localhost:3000/health || echo "Backend health check failed"

# Check SwargFood API
echo "SwargFood API Health:"
curl -s https://ai.swargfood.com/task/api/health || echo "SwargFood API health check failed"

# Check database connection
echo "Database Connection:"
sudo -u postgres psql -d taskmanagement -c "SELECT 1;" || echo "Database check failed"

# Check Nginx status
echo "Nginx Status:"
sudo systemctl is-active nginx || echo "Nginx is not running"

# Check disk space
echo "Disk Usage:"
df -h /var/www/task

# Check log files
echo "Recent Errors in Logs:"
tail -5 /var/www/task/logs/error.log 2>/dev/null || echo "No error log found"

echo "=== SwargFood Health Check Complete ==="
EOF

sudo chmod +x /usr/local/bin/swargfood-health-check.sh
```

### 7.2 Setup Log Rotation
```bash
# Create logrotate configuration
sudo tee /etc/logrotate.d/task-management << 'EOF'
/var/www/task-management/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 ubuntu ubuntu
    postrotate
        docker-compose -f /var/www/task-management/docker-compose.yml restart nginx
    endscript
}
EOF
```

---

## 🔧 Step 8: Google OAuth Setup

### 8.1 Google Cloud Console Configuration
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create new project or select existing
3. **Enable APIs**:
   - Google+ API
   - Google Drive API (for file uploads)

### 8.2 SwargFood OAuth 2.0 Setup
1. Go to **Credentials** → **Create Credentials** → **OAuth 2.0 Client ID**
2. **Application type**: Web application
3. **Name**: SwargFood Task Management
4. **Authorized JavaScript origins**:
   ```
https://ai.swargfood.com
```
5. **Authorized redirect URIs**:
   ```
https://ai.swargfood.com/task/api/auth/google/callback
```

### 8.3 Update SwargFood Environment Variables
```bash
# Update .env with Google credentials
nano /var/www/task/.env

# Update the following variables:
# GOOGLE_CLIENT_ID="your-production-google-client-id.apps.googleusercontent.com"
# GOOGLE_CLIENT_SECRET="your-production-google-client-secret"

# Restart PM2 process to apply changes
pm2 restart swargfood-task-management
```

---

## 🚀 Step 9: Final Verification

### 9.1 Access SwargFood Application
- **Frontend**: `https://ai.swargfood.com/task/`
- **API Health**: `https://ai.swargfood.com/task/health`
- **API Base**: `https://ai.swargfood.com/task/api`
- **API Documentation**: `https://ai.swargfood.com/task/api-docs/` (if enabled)

### 9.2 Test SwargFood Phase 3 Features
1. **Task Dependencies**: Create tasks and set dependencies
2. **Time Tracking**: Start/stop timers on tasks
3. **Task Templates**: Create and use templates
4. **Real-time Updates**: Test WebSocket connections
5. **File Uploads**: Test file attachment functionality
6. **Team Chat**: Test real-time chat functionality
7. **Notifications**: Test notification system

### 9.3 SwargFood Performance Testing
```bash
# Test SwargFood API response time
curl -w "@curl-format.txt" -o /dev/null -s https://ai.swargfood.com/task/api/health

# Monitor resource usage
htop

# Check PM2 process stats
pm2 monit

# Run SwargFood health check
/usr/local/bin/swargfood-health-check.sh
```

---

## 🔄 Step 10: Backup and Maintenance

### 10.1 SwargFood Automated Backup Setup
```bash
# Use the existing SwargFood backup script
chmod +x /var/www/task/scripts/backup.sh

# Test the backup script
cd /var/www/task
./scripts/backup.sh

# Setup automated daily backups using SwargFood script
crontab -e
# Add: 0 2 * * * /var/www/task/scripts/backup.sh

# Create additional system backup script
sudo tee /usr/local/bin/swargfood-backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/var/backups/swargfood-task"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Database backup
pg_dump -h localhost -U taskuser taskmanagement > $BACKUP_DIR/swargfood_db_$DATE.sql

# Application files backup (excluding node_modules and logs)
tar -czf $BACKUP_DIR/swargfood_app_$DATE.tar.gz -C /var/www/task \
    --exclude=node_modules \
    --exclude=.git \
    --exclude=logs \
    --exclude=uploads \
    .

# Backup uploads separately
tar -czf $BACKUP_DIR/swargfood_uploads_$DATE.tar.gz -C /var/www/task uploads

# Keep only last 7 days of backups
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "SwargFood backup completed: $DATE"
EOF

sudo chmod +x /usr/local/bin/swargfood-backup.sh
```

### 10.2 SwargFood Update Procedure
```bash
# Create SwargFood update script
sudo tee /usr/local/bin/swargfood-update.sh << 'EOF'
#!/bin/bash
cd /var/www/task

echo "Starting SwargFood Task Management update..."

# Backup before update
/usr/local/bin/swargfood-backup.sh

# Pull latest changes
git pull origin main

# Update backend dependencies
cd backend
npm install --production

# Generate Prisma client
npm run generate

# Run database migrations
npm run migrate:prod

# Restart PM2 process
pm2 restart swargfood-task-management

# Reload Nginx (in case of config changes)
sudo systemctl reload nginx

echo "SwargFood update completed successfully"

# Run health check
/usr/local/bin/swargfood-health-check.sh
EOF

sudo chmod +x /usr/local/bin/swargfood-update.sh
```

---

## 🆘 Troubleshooting

### Common Issues and Solutions

#### 1. **SwargFood Services Won't Start**
```bash
# Check PM2 status
pm2 status

# Check PM2 logs
pm2 logs swargfood-task-management

# Check system resources
free -h
df -h

# Restart PM2 process
pm2 restart swargfood-task-management
```

#### 2. **SwargFood Database Connection Issues**
```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Test database connection
psql -h localhost -U taskuser -d taskmanagement

# Check environment variables
grep DATABASE_URL /var/www/task/.env

# Restart PostgreSQL if needed
sudo systemctl restart postgresql
```

#### 3. **SwargFood Frontend Not Loading**
```bash
# Check nginx status
sudo systemctl status nginx

# Check nginx logs
sudo tail -f /var/log/nginx/error.log

# Check nginx configuration
sudo nginx -t

# Check if frontend files exist
ls -la /var/www/task/frontend/build/web/

# Restart nginx
sudo systemctl restart nginx
```

#### 4. **SSL Certificate Issues**
```bash
# Check certificate status
sudo certbot certificates

# Renew certificate manually
sudo certbot renew

# Check nginx SSL configuration
sudo nginx -t
```

#### 5. **SwargFood Performance Issues**
```bash
# Monitor resource usage
htop

# Check PM2 process monitoring
pm2 monit

# Check application logs
pm2 logs swargfood-task-management --lines 100

# Check SwargFood log files
tail -f /var/www/task/logs/app.log
tail -f /var/www/task/logs/error.log

# Optimize database
psql -h localhost -U taskuser -d taskmanagement -c "VACUUM ANALYZE;"
```

#### 6. **SwargFood File Upload Issues**
```bash
# Check upload directory permissions
ls -la /var/www/task/uploads/

# Fix permissions if needed
sudo chown -R ubuntu:ubuntu /var/www/task/uploads
chmod -R 755 /var/www/task/uploads

# Check nginx file upload configuration
grep client_max_body_size /etc/nginx/sites-available/swargfood-task-management
```

### SwargFood Health Check Commands
```bash
# Quick SwargFood health check
/usr/local/bin/swargfood-health-check.sh

# Detailed service status
pm2 status
sudo systemctl status nginx
sudo systemctl status postgresql

# Check SwargFood application endpoints
curl https://ai.swargfood.com/task/api/health
curl https://ai.swargfood.com/task/

# Test SwargFood API functionality
curl -X GET https://ai.swargfood.com/task/api/projects
```

---

## 📈 Performance Optimization

### 1. **Database Optimization**
```bash
# Add database indexes (run inside backend container)
docker-compose exec backend npx prisma db push

# Optimize PostgreSQL settings
docker-compose exec database psql -U taskuser -d taskmanagement -c "
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET maintenance_work_mem = '64MB';
SELECT pg_reload_conf();
"
```

### 2. **Nginx Optimization**
Add to nginx configuration:
```nginx
# Enable HTTP/2
listen 443 ssl http2;

# Optimize worker processes
worker_processes auto;
worker_connections 2048;

# Enable caching
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=app_cache:10m max_size=1g inactive=60m;
```

### 3. **Application Optimization**
```bash
# Enable PM2 cluster mode (if not using Docker)
pm2 start ecosystem.config.js

# Monitor PM2 processes
pm2 monit
```

---

## 🎉 Deployment Complete!

Your Task Management application is now successfully deployed on AWS Lightsail with:

✅ **Full Phase 3 Feature Support**
✅ **SSL/HTTPS Security**
✅ **Automated Backups**
✅ **Health Monitoring**
✅ **Performance Optimization**
✅ **Docker Containerization**

### Next Steps:
1. **Create Admin User**: Access the application and create your first admin account
2. **Configure Teams**: Set up your organization structure
3. **Import Data**: Migrate existing projects and tasks
4. **Train Users**: Provide training on new Phase 3 features
5. **Monitor Performance**: Use the health check scripts regularly

### Support Resources:
- **Application Logs**: `docker-compose logs -f backend`
- **Health Check**: `/usr/local/bin/health-check.sh`
- **Backup**: `/usr/local/bin/backup-task-management.sh`
- **Update**: `/usr/local/bin/update-task-management.sh`

**Your application is accessible at**: `https://your-domain.com/task/`

---

## 💰 Cost Optimization

### AWS Lightsail Pricing (as of 2024)
- **$10/month**: 2 GB RAM, 1 vCPU, 60 GB SSD - Good for development/testing
- **$20/month**: 4 GB RAM, 2 vCPU, 80 GB SSD - **Recommended for production**
- **$40/month**: 8 GB RAM, 2 vCPU, 160 GB SSD - For high-traffic applications

### Additional Costs to Consider
- **Static IP**: Free with Lightsail instance
- **Load Balancer**: $18/month (if needed for high availability)
- **Managed Database**: $15/month for 1 GB (alternative to self-hosted PostgreSQL)
- **CDN**: $2.50/month for 50 GB transfer (for global content delivery)
- **Backup Storage**: $0.05/GB/month for additional backup storage

### Cost Optimization Tips
1. **Use Lightsail Snapshots**: $0.05/GB/month for instance backups
2. **Monitor Data Transfer**: First 1-5 TB included, then $0.09/GB
3. **Optimize Images**: Use WebP format and compression for frontend assets
4. **Database Optimization**: Regular cleanup and indexing to reduce storage needs

---

## 🔐 Security Best Practices

### 1. **Server Security**
```bash
# Setup automatic security updates
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades

# Configure fail2ban for SSH protection
sudo apt install fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Setup UFW firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable
```

### 2. **Application Security**
```bash
# Secure environment variables
sudo chmod 600 /var/www/task-management/.env
sudo chown root:root /var/www/task-management/.env

# Setup log monitoring
sudo apt install logwatch
echo "logwatch --output mail --mailto your-email@domain.com --detail high" | sudo crontab -
```

### 3. **Database Security**
```bash
# Create read-only monitoring user
docker-compose exec database psql -U taskuser -d taskmanagement -c "
CREATE USER monitor WITH PASSWORD 'monitor-secure-password';
GRANT CONNECT ON DATABASE taskmanagement TO monitor;
GRANT USAGE ON SCHEMA public TO monitor;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO monitor;
"
```

### 4. **Nginx Security Headers**
Add to nginx configuration:
```nginx
# Security headers
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline';" always;
add_header X-Frame-Options DENY always;
add_header X-Content-Type-Options nosniff always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
```

---

## 📱 Mobile App Deployment (Optional)

If you want to deploy mobile apps alongside the web version:

### Android Deployment
```bash
# Build Android APK (requires Flutter SDK on development machine)
cd frontend
flutter build apk --release

# Upload to Google Play Store
# Follow Google Play Console guidelines
```

### iOS Deployment
```bash
# Build iOS app (requires macOS and Xcode)
cd frontend
flutter build ios --release

# Upload to App Store Connect
# Follow Apple App Store guidelines
```

---

## 🌍 Multi-Region Deployment (Advanced)

For global applications, consider multi-region deployment:

### 1. **Setup Multiple Lightsail Instances**
- **Primary Region**: US East (N. Virginia) - Main application
- **Secondary Region**: EU (Ireland) - European users
- **Tertiary Region**: Asia Pacific (Singapore) - Asian users

### 2. **Database Replication**
```bash
# Setup PostgreSQL read replicas
# Configure master-slave replication
# Use connection pooling for read/write splitting
```

### 3. **Load Balancing**
```bash
# Use Lightsail Load Balancer
# Configure health checks
# Setup SSL termination at load balancer
```

---

## 📊 Monitoring and Analytics

### 1. **Application Monitoring**
```bash
# Install monitoring tools
docker-compose -f docker-compose.monitoring.yml up -d

# Access monitoring dashboards
# Grafana: https://your-domain.com:3001
# Prometheus: https://your-domain.com:9090
```

### 2. **Log Aggregation**
```bash
# Setup centralized logging
# Use ELK stack (Elasticsearch, Logstash, Kibana)
# Or use AWS CloudWatch Logs
```

### 3. **Performance Monitoring**
```bash
# Setup APM (Application Performance Monitoring)
# Use tools like New Relic, DataDog, or open-source alternatives
# Monitor response times, error rates, and throughput
```

---

## 🔄 CI/CD Pipeline Setup

### GitHub Actions Workflow
Create `.github/workflows/deploy-lightsail.yml`:

```yaml
name: Deploy to AWS Lightsail

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Deploy to Lightsail
        uses: appleboy/ssh-action@v0.1.5
        with:
          host: ${{ secrets.LIGHTSAIL_HOST }}
          username: ubuntu
          key: ${{ secrets.LIGHTSAIL_SSH_KEY }}
          script: |
            cd /var/www/task-management
            git pull origin main
            docker-compose down
            docker-compose build --no-cache
            docker-compose up -d
            docker-compose exec backend npm run migrate:prod
```

### Setup Secrets in GitHub
1. Go to repository **Settings** → **Secrets and variables** → **Actions**
2. Add secrets:
   - `LIGHTSAIL_HOST`: Your static IP address
   - `LIGHTSAIL_SSH_KEY`: Your private SSH key content

---

## 📞 Support and Maintenance

### Regular Maintenance Tasks

#### Weekly Tasks
```bash
# Check system updates
sudo apt update && sudo apt list --upgradable

# Review application logs
docker-compose logs --tail=100 backend | grep ERROR

# Check disk usage
df -h
du -sh /var/www/task-management/*
```

#### Monthly Tasks
```bash
# Update Docker images
docker-compose pull
docker-compose up -d

# Clean up old Docker images
docker system prune -f

# Review and rotate logs
sudo logrotate -f /etc/logrotate.d/task-management
```

#### Quarterly Tasks
```bash
# Security audit
sudo apt update && sudo apt upgrade
docker-compose exec backend npm audit

# Performance review
# Analyze application metrics
# Review database performance
# Check SSL certificate expiry
```

### Emergency Procedures

#### Application Down
```bash
# Quick restart
docker-compose restart

# Full rebuild if needed
docker-compose down
docker-compose up -d --build

# Check logs for errors
docker-compose logs --tail=50 backend
```

#### Database Issues
```bash
# Check database status
docker-compose exec database pg_isready

# Restore from backup
docker-compose down
# Restore database from backup file
docker-compose up -d
```

#### SSL Certificate Expired
```bash
# Renew certificate
sudo certbot renew --force-renewal
sudo systemctl reload nginx
```

---

## 📚 Additional Resources

### Documentation References
- **Main Deployment Guide**: `DEPLOYMENT.md`
- **Quick Deploy Guide**: `QUICK_DEPLOY.md`
- **Environment Setup**: `deployment/environment-setup.md`
- **Docker Compose**: `docker-compose.yml`
- **Nginx Configuration**: `nginx/conf.d/default.conf`

### External Resources
- [AWS Lightsail Documentation](https://docs.aws.amazon.com/lightsail/)
- [Docker Documentation](https://docs.docker.com/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)

### Community Support
- **GitHub Issues**: Report bugs and feature requests
- **Documentation**: Contribute to documentation improvements
- **Stack Overflow**: Tag questions with `task-management-tool`

---

## 🎯 Success Checklist

Before going live, ensure all items are completed:

### Pre-Launch Checklist
- [ ] AWS Lightsail instance created and configured
- [ ] Domain name configured (if using)
- [ ] SSL certificate installed and working
- [ ] All environment variables properly set
- [ ] Database migrations completed successfully
- [ ] Google OAuth configured and tested
- [ ] File upload functionality tested
- [ ] All Phase 3 features tested (dependencies, time tracking, templates)
- [ ] Backup system configured and tested
- [ ] Monitoring and health checks working
- [ ] Performance testing completed
- [ ] Security hardening applied

### Post-Launch Checklist
- [ ] Admin user created
- [ ] Initial projects and teams set up
- [ ] User training completed
- [ ] Documentation updated
- [ ] Support procedures established
- [ ] Monitoring alerts configured
- [ ] Backup verification completed

---

**🎉 Congratulations! Your Task Management application is now successfully deployed on AWS Lightsail with full Phase 3 feature support!**

For additional support, refer to the existing documentation in `DEPLOYMENT.md` and `QUICK_DEPLOY.md`.
