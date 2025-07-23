# 🚀 AWS Lightsail Quick Reference - SwargFood Task Management Tool

## 📋 Essential Commands

### Instance Management
```bash
# Connect to instance
ssh -i LightsailDefaultKey-us-east-1.pem ubuntu@YOUR_STATIC_IP

# Check system status
sudo systemctl status nginx postgresql
pm2 status
```

### SwargFood Application Management
```bash
# Navigate to SwargFood app directory
cd /var/www/task

# View logs
pm2 logs swargfood-task-management
tail -f /var/www/task/logs/app.log
tail -f /var/www/task/logs/error.log
sudo tail -f /var/log/nginx/error.log

# Restart services
pm2 restart swargfood-task-management
sudo systemctl restart nginx
sudo systemctl restart postgresql

# Update SwargFood application
cd /var/www/task
git pull origin main
cd backend
npm install --production
npm run generate
npm run migrate:prod
pm2 restart swargfood-task-management
```

### SwargFood Health Checks
```bash
# Quick SwargFood health check
/usr/local/bin/swargfood-health-check.sh

# Manual health checks
curl https://ai.swargfood.com/task/api/health
psql -h localhost -U taskuser -d taskmanagement -c "SELECT 1;"
pm2 status

# Check SSL certificate
sudo certbot certificates
openssl s_client -connect ai.swargfood.com:443 -servername ai.swargfood.com
```

### SwargFood Database Management
```bash
# Database backup
pg_dump -h localhost -U taskuser taskmanagement > backup.sql

# Database restore
psql -h localhost -U taskuser taskmanagement < backup.sql

# Run migrations
cd /var/www/task/backend
npm run migrate:prod

# Access database
psql -h localhost -U taskuser taskmanagement
```

### SwargFood Monitoring
```bash
# System resources
htop
df -h
free -h

# PM2 monitoring
pm2 monit
pm2 status

# Application metrics
curl -s https://ai.swargfood.com/task/api/health | jq

# Log analysis
grep ERROR /var/log/nginx/error.log
grep ERROR /var/www/task/logs/error.log
pm2 logs swargfood-task-management | grep ERROR
```

## 🔧 SwargFood Configuration Files

### SwargFood Environment Variables (.env)
```env
DATABASE_URL="postgresql://taskuser:PASSWORD@localhost:5432/taskmanagement"
JWT_SECRET="your-32-char-secret"
GOOGLE_CLIENT_ID="your-google-client-id"
GOOGLE_CLIENT_SECRET="your-google-client-secret"
API_BASE_URL="https://ai.swargfood.com/task"
FRONTEND_URL="https://ai.swargfood.com/task"
CORS_ORIGIN="https://ai.swargfood.com"
UPLOAD_DIR="/var/www/task/uploads"
FROM_EMAIL="noreply@swargfood.com"
FROM_NAME="SwargFood Task Management"
```

### PM2 Commands
```bash
# Start SwargFood application
pm2 start /var/www/task/backend/ecosystem.config.js --env production

# Stop application
pm2 stop swargfood-task-management

# Restart application
pm2 restart swargfood-task-management

# View process status
pm2 status

# View logs
pm2 logs swargfood-task-management

# Monitor processes
pm2 monit

# Save PM2 configuration
pm2 save
```

### Nginx Commands
```bash
# Test configuration
sudo nginx -t

# Reload configuration
sudo systemctl reload nginx

# View access logs
sudo tail -f /var/log/nginx/access.log

# View error logs
sudo tail -f /var/log/nginx/error.log
```

## 🆘 Troubleshooting

### Common Issues

#### 1. Application Won't Start
```bash
# Check Docker services
docker-compose ps
docker-compose logs backend

# Check system resources
free -h
df -h

# Restart services
docker-compose restart
```

#### 2. Database Connection Error
```bash
# Check database status
docker-compose exec database pg_isready -U taskuser

# Check environment variables
docker-compose exec backend env | grep DATABASE

# Restart database
docker-compose restart database
```

#### 3. SSL Certificate Issues
```bash
# Check certificate status
sudo certbot certificates

# Renew certificate
sudo certbot renew

# Test SSL
openssl s_client -connect your-domain.com:443
```

#### 4. High Memory Usage
```bash
# Check memory usage
free -h
docker stats

# Restart services to free memory
docker-compose restart

# Clean up Docker
docker system prune -f
```

#### 5. Disk Space Full
```bash
# Check disk usage
df -h
du -sh /var/www/task-management/*

# Clean up logs
sudo journalctl --vacuum-time=7d
docker system prune -f

# Clean up old backups
find /var/backups -name "*.sql" -mtime +7 -delete
```

## 🔄 Maintenance Scripts

### Daily Health Check
```bash
#!/bin/bash
# Save as /usr/local/bin/daily-check.sh

echo "=== Daily Health Check $(date) ==="

# Check services
docker-compose -f /var/www/task-management/docker-compose.yml ps

# Check disk space
df -h | grep -E "(/$|/var)"

# Check memory
free -h

# Check application health
curl -s https://your-domain.com/task/api/health || echo "Health check failed"

# Check SSL expiry
openssl s_client -connect your-domain.com:443 -servername your-domain.com 2>/dev/null | openssl x509 -noout -dates
```

### Backup Script
```bash
#!/bin/bash
# Save as /usr/local/bin/backup.sh

BACKUP_DIR="/var/backups/task-management"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Database backup
docker-compose -f /var/www/task-management/docker-compose.yml exec -T database pg_dump -U taskuser taskmanagement > $BACKUP_DIR/db_$DATE.sql

# Application backup
tar -czf $BACKUP_DIR/app_$DATE.tar.gz -C /var/www/task-management --exclude=node_modules .

# Cleanup old backups (keep 7 days)
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: $DATE"
```

### Update Script
```bash
#!/bin/bash
# Save as /usr/local/bin/update.sh

cd /var/www/task-management

echo "Starting update process..."

# Backup before update
/usr/local/bin/backup.sh

# Pull latest changes
git pull origin main

# Update services
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# Run migrations
sleep 30  # Wait for services to start
docker-compose exec backend npm run migrate:prod

echo "Update completed successfully"
```

## 📊 Performance Monitoring

### Key Metrics to Monitor
```bash
# CPU Usage
top -bn1 | grep "Cpu(s)"

# Memory Usage
free -h

# Disk I/O
iostat -x 1 1

# Network
netstat -i

# Application Response Time
curl -w "@curl-format.txt" -o /dev/null -s https://your-domain.com/task/api/health
```

### Performance Optimization
```bash
# Optimize PostgreSQL
docker-compose exec database psql -U taskuser -d taskmanagement -c "VACUUM ANALYZE;"

# Clear Redis cache
docker-compose exec redis redis-cli FLUSHALL

# Restart services for memory cleanup
docker-compose restart
```

## 🔐 Security Checklist

### Regular Security Tasks
```bash
# Update system packages
sudo apt update && sudo apt upgrade

# Check for security updates
sudo unattended-upgrades --dry-run

# Review firewall rules
sudo ufw status

# Check failed login attempts
sudo grep "Failed password" /var/log/auth.log

# Scan for malware (optional)
sudo apt install clamav
sudo freshclam
sudo clamscan -r /var/www/task-management
```

### SSL Certificate Management
```bash
# Check certificate expiry
sudo certbot certificates

# Test auto-renewal
sudo certbot renew --dry-run

# Manual renewal
sudo certbot renew --force-renewal
```

## 📱 Application URLs

### Production URLs
- **Frontend**: `https://your-domain.com/task/`
- **API Health**: `https://your-domain.com/task/api/health`
- **API Docs**: `https://your-domain.com/task/api/docs` (if enabled)

### Development/Testing URLs
- **Backend Direct**: `http://YOUR_IP:3003/health`
- **Database**: `postgresql://taskuser:PASSWORD@YOUR_IP:5432/taskmanagement`

## 📞 Emergency Contacts

### Support Information
- **Documentation**: `/var/www/task-management/AWS_LIGHTSAIL_DEPLOYMENT.md`
- **Logs Location**: `/var/log/nginx/` and `docker-compose logs`
- **Backup Location**: `/var/backups/task-management/`
- **Application Directory**: `/var/www/task-management/`

### Quick Recovery Commands
```bash
# Emergency restart
sudo reboot

# Service recovery
docker-compose -f /var/www/task-management/docker-compose.yml down
docker-compose -f /var/www/task-management/docker-compose.yml up -d

# Database recovery from backup
# (Replace BACKUP_FILE with actual backup filename)
docker-compose exec -T database psql -U taskuser taskmanagement < /var/backups/task-management/BACKUP_FILE.sql
```

---

**📋 Keep this reference handy for quick troubleshooting and maintenance tasks!**

For detailed instructions, refer to the complete `AWS_LIGHTSAIL_DEPLOYMENT.md` guide.
