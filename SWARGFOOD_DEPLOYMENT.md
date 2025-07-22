# 🚀 SwargFood Task Management Tool - Deployment Guide

## 📍 **Deployment Configuration**

- **Domain**: `ai.swargfood.com/task`
- **Installation Path**: `/var/www/task`
- **Backend API**: `ai.swargfood.com/task/api/`
- **Frontend**: `ai.swargfood.com/task/`

---

## 🛠️ **Server Setup Instructions**

### **Step 1: Prepare the Server**

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y nodejs npm postgresql postgresql-contrib nginx git curl

# Install Node.js 18 (if not latest)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PM2 for process management
sudo npm install -g pm2

# Create application directory
sudo mkdir -p /var/www/task
sudo chown -R $USER:$USER /var/www/task
```

### **Step 2: Clone and Setup Application**

```bash
# Navigate to installation directory
cd /var/www/task

# Clone your repository
git clone <your-repository-url> .

# Make deployment script executable
chmod +x deploy.sh

# Copy and configure environment
cp .env.production .env
```

### **Step 3: Configure Environment Variables**

Edit the environment file:
```bash
nano .env
```

**Required Configuration:**
```bash
# Database Configuration
DATABASE_URL="postgresql://taskuser:your-secure-password@localhost:5432/taskmanagement"

# JWT Security
JWT_SECRET="your-super-secure-jwt-secret-32-chars-minimum"
JWT_REFRESH_SECRET="your-super-secure-refresh-secret-32-chars-minimum"

# Google OAuth (Get from Google Cloud Console)
GOOGLE_CLIENT_ID="your-google-client-id.apps.googleusercontent.com"
GOOGLE_CLIENT_SECRET="your-google-client-secret"

# SwargFood Specific Configuration
NODE_ENV="production"
PORT=3000
API_BASE_URL="https://ai.swargfood.com/task"
FRONTEND_URL="https://ai.swargfood.com/task"
CORS_ORIGIN="https://ai.swargfood.com"
SOCKET_CORS_ORIGIN="https://ai.swargfood.com"

# File Storage
UPLOAD_DIR="/var/www/task/uploads"
MAX_FILE_SIZE=10485760

# Email Configuration (Optional)
SMTP_HOST="smtp.gmail.com"
SMTP_PORT=587
SMTP_USER="your-email@swargfood.com"
SMTP_PASS="your-app-password"
FROM_EMAIL="noreply@swargfood.com"
FROM_NAME="SwargFood Task Management"

# Logging
LOG_LEVEL="error"
LOG_FILE="/var/www/task/logs/app.log"
```

### **Step 4: Setup Database**

```bash
# Switch to postgres user
sudo -u postgres psql

# Create database and user
CREATE DATABASE taskmanagement;
CREATE USER taskuser WITH PASSWORD 'your-secure-password';
GRANT ALL PRIVILEGES ON DATABASE taskmanagement TO taskuser;
ALTER USER taskuser CREATEDB;
\q
```

### **Step 5: Deploy Application**

```bash
# Run automated deployment
./deploy.sh -e production -t pm2 -f web -n

# Or deploy manually:
cd backend
npm install --production
npm run generate
npm run migrate:prod
pm2 start ecosystem.config.js --env production
pm2 save
pm2 startup
```

### **Step 6: Configure Nginx**

The deployment script creates the Nginx configuration, but you can also set it up manually:

```bash
# Create Nginx configuration
sudo nano /etc/nginx/sites-available/task-management
```

**Nginx Configuration:**
```nginx
server {
    listen 80;
    server_name ai.swargfood.com;

    # Task Management Backend API
    location /task/api/ {
        proxy_pass http://localhost:3000/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # Task Management Socket.IO
    location /task/socket.io/ {
        proxy_pass http://localhost:3000/socket.io/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Task Management Frontend
    location /task/ {
        alias /var/www/task/frontend/build/web/;
        index index.html;
        try_files $uri $uri/ /task/index.html;
    }

    # File uploads and static assets
    location /task/uploads/ {
        alias /var/www/task/uploads/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

**Enable the site:**
```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/task-management /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

### **Step 7: Setup SSL Certificate**

```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Get SSL certificate for ai.swargfood.com
sudo certbot --nginx -d ai.swargfood.com

# Verify auto-renewal
sudo certbot renew --dry-run
```

---

## 🔧 **Google OAuth Setup**

### **Step 1: Google Cloud Console**
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable Google+ API
4. Go to "Credentials" → "Create Credentials" → "OAuth 2.0 Client IDs"

### **Step 2: Configure OAuth**
- **Application type**: Web application
- **Name**: SwargFood Task Management
- **Authorized JavaScript origins**: 
  - `https://ai.swargfood.com`
- **Authorized redirect URIs**: 
  - `https://ai.swargfood.com/task/api/auth/google/callback`

### **Step 3: Update Environment**
Copy the Client ID and Client Secret to your `.env` file.

---

## 📊 **Monitoring & Maintenance**

### **Health Check**
```bash
# Check application health
cd /var/www/task
node scripts/health-check.js

# Check specific services
curl https://ai.swargfood.com/task/api/health
pm2 status
sudo systemctl status nginx
```

### **View Logs**
```bash
# Application logs
pm2 logs

# Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# Application log file
tail -f /var/www/task/logs/app.log
```

### **Backup Setup**
```bash
# Make backup script executable
chmod +x scripts/backup.sh

# Test backup
./scripts/backup.sh

# Setup automated daily backups
crontab -e
# Add: 0 2 * * * /var/www/task/scripts/backup.sh
```

### **Updates and Maintenance**
```bash
# Update application
cd /var/www/task
git pull origin main
npm install --production
npm run generate
npm run migrate:prod
pm2 restart all

# Update system packages
sudo apt update && sudo apt upgrade -y
```

---

## 🎯 **Access URLs**

After successful deployment:

- **Frontend Application**: `https://ai.swargfood.com/task/`
- **API Endpoints**: `https://ai.swargfood.com/task/api/`
- **API Documentation**: `https://ai.swargfood.com/task/api-docs/`
- **Health Check**: `https://ai.swargfood.com/task/api/health`

---

## 🚨 **Troubleshooting**

### **Common Issues:**

1. **502 Bad Gateway**
   ```bash
   # Check if backend is running
   pm2 status
   # Restart if needed
   pm2 restart all
   ```

2. **Database Connection Error**
   ```bash
   # Check PostgreSQL status
   sudo systemctl status postgresql
   # Test connection
   psql -h localhost -U taskuser -d taskmanagement
   ```

3. **File Upload Issues**
   ```bash
   # Check permissions
   sudo chown -R www-data:www-data /var/www/task/uploads
   sudo chmod -R 755 /var/www/task/uploads
   ```

4. **CORS Errors**
   ```bash
   # Verify CORS_ORIGIN in .env
   grep CORS_ORIGIN /var/www/task/.env
   ```

### **Emergency Recovery**
```bash
# Restart all services
sudo systemctl restart nginx
pm2 restart all
sudo systemctl restart postgresql

# Check all logs
pm2 logs --lines 50
sudo tail -50 /var/log/nginx/error.log
```

---

## ✅ **Verification Checklist**

- [ ] Server packages installed
- [ ] Application cloned to `/var/www/task`
- [ ] Environment variables configured
- [ ] Database created and migrated
- [ ] Backend running on PM2
- [ ] Nginx configured and running
- [ ] SSL certificate installed
- [ ] Google OAuth configured
- [ ] Health check passes
- [ ] Frontend accessible at `ai.swargfood.com/task`
- [ ] API accessible at `ai.swargfood.com/task/api`
- [ ] Backups configured

---

## 🎉 **Success!**

Your SwargFood Task Management Tool is now deployed and accessible at:
**https://ai.swargfood.com/task/**

The application includes:
- ✅ Real-time collaboration features
- ✅ Task and project management
- ✅ Team chat and notifications
- ✅ Time tracking
- ✅ File sharing
- ✅ Mobile-responsive design
- ✅ Production-ready security
