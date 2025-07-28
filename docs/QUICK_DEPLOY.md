# 🚀 SwargFood Task Management - Quick Deployment Guide

This guide will help you deploy the SwargFood Task Management Tool to **ai.swargfood.com/task**.

## 📋 Prerequisites

- **Server**: Ubuntu 20.04+ or similar Linux distribution
- **Domain**: ai.swargfood.com pointing to your server
- **Path**: Application will be installed in /var/www/task
- **Google OAuth**: Google Cloud Console project with OAuth credentials

## 🚀 Option 1: Automated SwargFood Deployment (Recommended)

### Step 1: Clone and Setup
```bash
# Clone the repository to the correct location
sudo mkdir -p /var/www/task
sudo chown -R $USER:$USER /var/www/task
cd /var/www/task
git clone <your-repo-url> .

# Make deployment script executable
chmod +x swargfood-deploy.sh

# Run the automated deployment
./swargfood-deploy.sh
```

### Step 2: Configure Environment
The script will create a `.env` file. Update it with your settings:
```bash
nano /var/www/task/.env
```

**Required settings to update:**
- `GOOGLE_CLIENT_ID`: Your Google OAuth client ID
- `GOOGLE_CLIENT_SECRET`: Your Google OAuth client secret
- `JWT_SECRET`: Change from default (32+ character random string)
- `JWT_REFRESH_SECRET`: Change from default (32+ character random string)

### Step 3: Access Your Application
After deployment completes:
- **Frontend**: https://ai.swargfood.com/task/
- **API**: https://ai.swargfood.com/task/api/
- **Health Check**: https://ai.swargfood.com/task/health

---

## 🖥️ Option 2: Traditional Server Deployment

### Step 1: Install Dependencies
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PostgreSQL
sudo apt install postgresql postgresql-contrib

# Install Nginx
sudo apt install nginx

# Install PM2
sudo npm install -g pm2
```

### Step 2: Setup Database
```bash
# Switch to postgres user
sudo -u postgres psql

# Create database and user
CREATE DATABASE taskmanagement;
CREATE USER taskuser WITH PASSWORD 'your-secure-password';
GRANT ALL PRIVILEGES ON DATABASE taskmanagement TO taskuser;
\q
```

### Step 3: Deploy Application
```bash
# Clone repository
git clone <your-repo-url>
cd task-tool

# Deploy with PM2
./deploy.sh -e production -t pm2 -f web -n
```

### Step 4: Setup SSL (Optional but Recommended)
```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Get SSL certificate
sudo certbot --nginx -d your-domain.com

# Auto-renewal
sudo crontab -e
# Add: 0 12 * * * /usr/bin/certbot renew --quiet
```

---

## ☁️ Option 3: Cloud Platform Deployment

### Heroku
```bash
# Install Heroku CLI
# Create Heroku app
heroku create your-app-name

# Add PostgreSQL addon
heroku addons:create heroku-postgresql:hobby-dev

# Set environment variables
heroku config:set NODE_ENV=production
heroku config:set JWT_SECRET=your-jwt-secret
heroku config:set GOOGLE_CLIENT_ID=your-google-client-id
# ... other variables

# Deploy
git push heroku main

# Run migrations
heroku run npm run migrate:prod
```

### Railway
```bash
# Install Railway CLI
npm install -g @railway/cli

# Login and deploy
railway login
railway init
railway up
```

### DigitalOcean App Platform
1. Connect your GitHub repository
2. Configure build and run commands:
   - **Build**: `cd backend && npm install && npm run generate`
   - **Run**: `cd backend && npm start`
3. Set environment variables
4. Deploy

---

## 🔧 Configuration

### Google OAuth Setup
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable Google+ API
4. Create OAuth 2.0 credentials
5. Add authorized redirect URIs:
   - `http://your-domain.com/auth/google/callback`
   - `https://your-domain.com/auth/google/callback`

### Environment Variables
```bash
# Required
DATABASE_URL="postgresql://user:pass@host:5432/db"
JWT_SECRET="your-32-char-secret"
JWT_REFRESH_SECRET="your-32-char-refresh-secret"
GOOGLE_CLIENT_ID="your-google-client-id"
GOOGLE_CLIENT_SECRET="your-google-client-secret"

# Optional
FRONTEND_URL="https://your-domain.com"
CORS_ORIGIN="https://your-domain.com"
SMTP_HOST="smtp.gmail.com"
SMTP_USER="your-email@gmail.com"
SMTP_PASS="your-app-password"
```

---

## 🔍 Verification

### Health Checks
```bash
# Check backend health
curl http://your-domain.com/health

# Check API
curl http://your-domain.com/api/health

# Check database connection
docker-compose exec backend npm run db:test
```

### Logs
```bash
# Docker logs
docker-compose logs -f backend

# PM2 logs
pm2 logs

# Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

---

## 🛠️ Troubleshooting

### Common Issues

1. **Database Connection Error**
   - Check DATABASE_URL format
   - Verify database server is running
   - Check firewall rules

2. **CORS Errors**
   - Verify CORS_ORIGIN in .env
   - Check frontend API base URL

3. **File Upload Issues**
   - Check UPLOAD_DIR permissions
   - Verify MAX_FILE_SIZE setting

4. **Socket.IO Connection Issues**
   - Check proxy configuration for WebSocket
   - Verify SOCKET_CORS_ORIGIN setting

### Getting Help
```bash
# Check application status
./deploy.sh --help

# View detailed logs
docker-compose logs --tail=100 backend

# Test database connection
docker-compose exec backend npx prisma db pull
```

---

## 📊 Monitoring

### Setup Monitoring (Optional)
```bash
# Install monitoring tools
docker-compose -f docker-compose.monitoring.yml up -d

# Access dashboards
# Grafana: http://your-domain.com:3001
# Prometheus: http://your-domain.com:9090
```

### Backup Setup
```bash
# Setup automated backups
chmod +x scripts/backup.sh

# Add to crontab for daily backups
crontab -e
# Add: 0 2 * * * /path/to/scripts/backup.sh
```

---

## 🎉 Success!

Your Task Management Tool is now deployed and ready to use!

**Next Steps:**
1. Create your first admin user
2. Set up your first project
3. Invite team members
4. Configure notification preferences
5. Start collaborating!

**Support:**
- Check the logs for any issues
- Review the main README.md for detailed documentation
- Ensure all environment variables are properly configured
