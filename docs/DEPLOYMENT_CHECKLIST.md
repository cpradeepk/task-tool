# ✅ AWS Lightsail Deployment Checklist - SwargFood Task Management Tool

## 📋 Pre-Deployment Preparation

### Prerequisites
- [ ] AWS Account with Lightsail access
- [ ] Domain: `ai.swargfood.com` configured and accessible
- [ ] Google Cloud Console account
- [ ] SSH client installed on local machine
- [ ] Basic Linux command line knowledge

### SwargFood Google OAuth Setup
- [ ] Create Google Cloud project
- [ ] Enable Google+ API and Google Drive API
- [ ] Create OAuth 2.0 credentials
- [ ] Configure authorized origins: `https://ai.swargfood.com`
- [ ] Configure redirect URIs: `https://ai.swargfood.com/task/api/auth/google/callback`
- [ ] Note down Client ID and Client Secret

---

## 🚀 AWS Lightsail Instance Setup

### Instance Creation
- [ ] Log into AWS Lightsail Console
- [ ] Click "Create instance"
- [ ] Select Linux/Unix platform
- [ ] Choose Ubuntu 22.04 LTS blueprint
- [ ] Select instance plan ($20/month recommended for production)
- [ ] Name instance: `task-management-app`
- [ ] Create instance

### Networking Configuration
- [ ] Create and attach static IP address
- [ ] Configure firewall rules:
  - [ ] SSH (22) - Default
  - [ ] HTTP (80) - Add
  - [ ] HTTPS (443) - Add
  - [ ] Custom (3003) - Add temporarily (remove after nginx setup)
- [ ] Note down static IP address

### SwargFood Domain Configuration
- [ ] Update DNS A records for `ai.swargfood.com` to point to static IP
- [ ] Verify DNS propagation with `nslookup ai.swargfood.com`
- [ ] Ensure domain resolves correctly

---

## 🔧 Server Setup

### Initial Connection
- [ ] Download SSH key from Lightsail console
- [ ] Connect via SSH: `ssh -i LightsailDefaultKey-us-east-1.pem ubuntu@YOUR_STATIC_IP`
- [ ] Verify connection successful

### System Updates
- [ ] Run: `sudo apt update && sudo apt upgrade -y`
- [ ] Install basic tools: `sudo apt install -y curl wget git htop unzip`
- [ ] Install build essentials: `sudo apt install -y build-essential`

### Install Node.js 18
- [ ] Add NodeSource repository: `curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -`
- [ ] Install Node.js: `sudo apt-get install -y nodejs`
- [ ] Verify installation: `node --version` (should show v18.x.x)

### Install PostgreSQL
- [ ] Install PostgreSQL: `sudo apt install -y postgresql postgresql-contrib`
- [ ] Start PostgreSQL: `sudo systemctl start postgresql && sudo systemctl enable postgresql`
- [ ] Verify PostgreSQL: `sudo systemctl status postgresql`

### Install Additional Tools
- [ ] Install PM2: `sudo npm install -g pm2`
- [ ] Install Nginx: `sudo apt install -y nginx`
- [ ] Start Nginx: `sudo systemctl start nginx && sudo systemctl enable nginx`

---

## 📦 SwargFood Application Deployment

### SwargFood Repository Setup
- [ ] Create SwargFood app directory: `sudo mkdir -p /var/www/task`
- [ ] Change ownership: `sudo chown -R ubuntu:ubuntu /var/www/task`
- [ ] Clone repository: `cd /var/www/task && git clone https://github.com/cpradeepk/task-tool.git .`
- [ ] Make scripts executable: `chmod +x deploy.sh swargfood-deploy.sh`
- [ ] Verify files present: `ls -la`

### SwargFood Database Setup
- [ ] Switch to postgres user: `sudo -u postgres psql`
- [ ] Create database: `CREATE DATABASE taskmanagement;`
- [ ] Create user: `CREATE USER taskuser WITH PASSWORD 'your-secure-password';`
- [ ] Grant privileges: `GRANT ALL PRIVILEGES ON DATABASE taskmanagement TO taskuser;`
- [ ] Grant createdb: `ALTER USER taskuser CREATEDB;`
- [ ] Exit postgres: `\q`

### SwargFood Environment Configuration
- [ ] Copy SwargFood environment template: `cp .env.production .env`
- [ ] Edit environment file: `nano .env`
- [ ] Update SwargFood-specific variables:
  - [ ] `DATABASE_URL` - Set to local PostgreSQL
  - [ ] `JWT_SECRET` - Generate 32+ character secret
  - [ ] `JWT_REFRESH_SECRET` - Generate 32+ character secret
  - [ ] `GOOGLE_CLIENT_ID` - From Google Cloud Console
  - [ ] `GOOGLE_CLIENT_SECRET` - From Google Cloud Console
  - [ ] `API_BASE_URL` - `https://ai.swargfood.com/task`
  - [ ] `FRONTEND_URL` - `https://ai.swargfood.com/task`
  - [ ] `CORS_ORIGIN` - `https://ai.swargfood.com`
  - [ ] `FROM_EMAIL` - `noreply@swargfood.com`
  - [ ] `FROM_NAME` - `SwargFood Task Management`

### SwargFood Application Deployment
- [ ] Option 1: Run automated script: `./swargfood-deploy.sh`
- [ ] Option 2: Manual deployment:
  - [ ] Install dependencies: `cd backend && npm install --production`
  - [ ] Generate Prisma client: `npm run generate`
  - [ ] Run migrations: `npm run migrate:prod`
  - [ ] Start with PM2: `pm2 start ecosystem.config.js --env production`
  - [ ] Save PM2 config: `pm2 save`
- [ ] Verify backend health: `curl http://localhost:3003/health`

---

## 🌐 SwargFood Nginx Configuration

### SwargFood Nginx Setup
- [ ] Backup default config: `sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup`
- [ ] Create SwargFood config: `sudo nano /etc/nginx/sites-available/swargfood-task-management`
- [ ] Copy SwargFood nginx configuration from deployment guide
- [ ] Update server_name to `ai.swargfood.com`
- [ ] Disable default site: `sudo unlink /etc/nginx/sites-enabled/default`
- [ ] Enable SwargFood site: `sudo ln -s /etc/nginx/sites-available/swargfood-task-management /etc/nginx/sites-enabled/`
- [ ] Test config: `sudo nginx -t`
- [ ] Reload Nginx: `sudo systemctl reload nginx`

### Verify SwargFood HTTP Access
- [ ] Test frontend: `curl http://ai.swargfood.com/task/`
- [ ] Test API: `curl http://ai.swargfood.com/task/api/health`
- [ ] Test in browser: `http://ai.swargfood.com/task/`

---

## 🔒 SSL Certificate Setup

### Install Certbot
- [ ] Install Certbot: `sudo apt install -y certbot python3-certbot-nginx`

### Get SSL Certificate (if using domain)
- [ ] Get certificate: `sudo certbot --nginx -d your-domain.com -d www.your-domain.com`
- [ ] Test auto-renewal: `sudo certbot renew --dry-run`
- [ ] Setup auto-renewal cron: `echo "0 12 * * * /usr/bin/certbot renew --quiet" | sudo crontab -`

### Verify HTTPS Access
- [ ] Test HTTPS: `https://your-domain.com/task/`
- [ ] Test API over HTTPS: `https://your-domain.com/task/api/health`
- [ ] Verify SSL certificate in browser

---

## 📊 Monitoring and Maintenance Setup

### Health Check Script
- [ ] Create health check script: `sudo nano /usr/local/bin/health-check.sh`
- [ ] Copy content from deployment guide
- [ ] Make executable: `sudo chmod +x /usr/local/bin/health-check.sh`
- [ ] Test script: `/usr/local/bin/health-check.sh`

### Backup Setup
- [ ] Create backup script: `sudo nano /usr/local/bin/backup-task-management.sh`
- [ ] Copy content from deployment guide
- [ ] Make executable: `sudo chmod +x /usr/local/bin/backup-task-management.sh`
- [ ] Test backup: `/usr/local/bin/backup-task-management.sh`
- [ ] Setup daily backup cron: `echo "0 2 * * * /usr/local/bin/backup-task-management.sh" | sudo crontab -`

### Log Rotation
- [ ] Create logrotate config: `sudo nano /etc/logrotate.d/task-management`
- [ ] Copy content from deployment guide
- [ ] Test logrotate: `sudo logrotate -d /etc/logrotate.d/task-management`

---

## 🧪 Testing and Verification

### Application Testing
- [ ] Access frontend: `https://your-domain.com/task/`
- [ ] Test user registration/login
- [ ] Test Google OAuth login
- [ ] Create test project
- [ ] Create test tasks
- [ ] Test Phase 3 features:
  - [ ] Task dependencies
  - [ ] Time tracking with timers
  - [ ] Task templates
  - [ ] Task comments
  - [ ] File uploads

### Performance Testing
- [ ] Test API response time: `curl -w "@curl-format.txt" -o /dev/null -s https://your-domain.com/task/api/health`
- [ ] Monitor resource usage: `htop`
- [ ] Check Docker stats: `docker stats`
- [ ] Test WebSocket connections (real-time features)

### Security Testing
- [ ] Verify HTTPS redirect
- [ ] Test security headers
- [ ] Check firewall status: `sudo ufw status`
- [ ] Verify SSL certificate: `openssl s_client -connect your-domain.com:443`

---

## 🔐 Security Hardening

### System Security
- [ ] Setup automatic security updates: `sudo apt install unattended-upgrades`
- [ ] Configure unattended upgrades: `sudo dpkg-reconfigure -plow unattended-upgrades`
- [ ] Install fail2ban: `sudo apt install fail2ban`
- [ ] Configure UFW firewall:
  - [ ] `sudo ufw default deny incoming`
  - [ ] `sudo ufw default allow outgoing`
  - [ ] `sudo ufw allow ssh`
  - [ ] `sudo ufw allow 80`
  - [ ] `sudo ufw allow 443`
  - [ ] `sudo ufw enable`

### Application Security
- [ ] Secure environment file: `sudo chmod 600 /var/www/task-management/.env`
- [ ] Change file ownership: `sudo chown root:root /var/www/task-management/.env`
- [ ] Remove temporary firewall rule for port 3003
- [ ] Verify no sensitive data in logs

---

## 📈 Performance Optimization

### Database Optimization
- [ ] Run database optimization: `docker-compose exec database psql -U taskuser -d taskmanagement -c "VACUUM ANALYZE;"`
- [ ] Verify database indexes are in place

### Application Optimization
- [ ] Enable gzip compression in Nginx (already configured)
- [ ] Verify caching headers for static assets
- [ ] Monitor application performance

### Resource Monitoring
- [ ] Setup resource monitoring alerts (optional)
- [ ] Configure log monitoring (optional)
- [ ] Setup uptime monitoring (optional)

---

## 🎯 Go-Live Checklist

### Final Verification
- [ ] All services running: `docker-compose ps`
- [ ] Health check passing: `/usr/local/bin/health-check.sh`
- [ ] SSL certificate valid and auto-renewing
- [ ] Backups working and tested
- [ ] Monitoring and alerts configured
- [ ] Documentation updated with production URLs

### User Setup
- [ ] Create admin user account
- [ ] Setup initial organization/teams
- [ ] Configure notification preferences
- [ ] Import any existing data
- [ ] Train initial users

### Post-Launch
- [ ] Monitor application for first 24 hours
- [ ] Verify backup system working
- [ ] Check performance metrics
- [ ] Gather user feedback
- [ ] Document any issues and resolutions

---

## 📞 Emergency Information

### Important Commands
```bash
# Emergency restart
sudo reboot

# Service restart
docker-compose restart

# View logs
docker-compose logs -f backend
sudo tail -f /var/log/nginx/error.log

# Health check
/usr/local/bin/health-check.sh
```

### Important File Locations
- **Application**: `/var/www/task-management/`
- **Environment**: `/var/www/task-management/.env`
- **Nginx Config**: `/etc/nginx/sites-available/task-management`
- **Backups**: `/var/backups/task-management/`
- **Logs**: `/var/log/nginx/` and `docker-compose logs`

### Support Resources
- **Full Deployment Guide**: `AWS_LIGHTSAIL_DEPLOYMENT.md`
- **Quick Reference**: `LIGHTSAIL_QUICK_REFERENCE.md`
- **Original Deployment Docs**: `DEPLOYMENT.md`, `QUICK_DEPLOY.md`

---

## ✅ Deployment Complete!

**Congratulations!** Your Task Management application is now successfully deployed on AWS Lightsail.

**Application URL**: `https://your-domain.com/task/`

**Next Steps**:
1. Create your admin account
2. Set up your first project
3. Invite team members
4. Start using the advanced Phase 3 features!

---

**📋 Print this checklist and check off items as you complete them for a successful deployment!**
