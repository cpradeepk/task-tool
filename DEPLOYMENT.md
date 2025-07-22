# Deployment Guide

This guide covers deploying the Task Management Tool to various platforms and environments.

## 📋 Prerequisites

- Docker (optional, for containerized deployment)
- Node.js 18+ (for backend)
- Flutter 3.x (for frontend)
- PostgreSQL database
- Google Cloud Console account
- Domain name (for production)

## 🚀 Backend Deployment

### Option 1: Traditional Server Deployment

#### 1. Server Setup
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PostgreSQL
sudo apt install postgresql postgresql-contrib

# Install PM2 for process management
sudo npm install -g pm2
```

#### 2. Database Setup
```bash
# Switch to postgres user
sudo -u postgres psql

# Create database and user
CREATE DATABASE taskmanagement;
CREATE USER taskuser WITH PASSWORD 'your-secure-password';
GRANT ALL PRIVILEGES ON DATABASE taskmanagement TO taskuser;
\q
```

#### 3. Application Deployment
```bash
# Clone repository
git clone <your-repo-url>
cd task-tool/backend

# Install dependencies
npm install --production

# Set up environment
cp .env.example .env
# Edit .env with production values

# Run migrations
npm run migrate:prod

# Start with PM2
pm2 start ecosystem.config.js
pm2 save
pm2 startup
```

#### 4. Nginx Configuration
```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # WebSocket support for Socket.IO
    location /socket.io/ {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Option 2: Docker Deployment

#### 1. Create Dockerfile
```dockerfile
# backend/Dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npm run generate

EXPOSE 3000

CMD ["npm", "start"]
```

#### 2. Docker Compose
```yaml
# docker-compose.yml
version: '3.8'

services:
  backend:
    build: ./backend
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://taskuser:password@db:5432/taskmanagement
    depends_on:
      - db
    volumes:
      - ./uploads:/app/uploads

  db:
    image: postgres:15
    environment:
      - POSTGRES_DB=taskmanagement
      - POSTGRES_USER=taskuser
      - POSTGRES_PASSWORD=password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - backend

volumes:
  postgres_data:
```

#### 3. Deploy with Docker
```bash
# Build and start services
docker-compose up -d

# Run migrations
docker-compose exec backend npm run migrate:prod

# View logs
docker-compose logs -f backend
```

### Option 3: Cloud Platform Deployment

#### Heroku
```bash
# Install Heroku CLI
# Create Heroku app
heroku create your-app-name

# Add PostgreSQL addon
heroku addons:create heroku-postgresql:hobby-dev

# Set environment variables
heroku config:set NODE_ENV=production
heroku config:set JWT_SECRET=your-jwt-secret
# ... other environment variables

# Deploy
git push heroku main

# Run migrations
heroku run npm run migrate:prod
```

#### Railway
```bash
# Install Railway CLI
npm install -g @railway/cli

# Login and deploy
railway login
railway init
railway up
```

#### DigitalOcean App Platform
1. Connect your GitHub repository
2. Configure build and run commands
3. Set environment variables
4. Deploy

## 🌐 Frontend Deployment

### Option 1: Web Deployment

#### Build for Web
```bash
cd frontend

# Build for web
flutter build web --release

# The build output will be in build/web/
```

#### Deploy to Netlify
```bash
# Install Netlify CLI
npm install -g netlify-cli

# Deploy
cd build/web
netlify deploy --prod
```

#### Deploy to Vercel
```bash
# Install Vercel CLI
npm install -g vercel

# Deploy
cd build/web
vercel --prod
```

#### Deploy to Firebase Hosting
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Initialize Firebase
firebase init hosting

# Deploy
firebase deploy
```

### Option 2: Mobile App Deployment

#### Android (Google Play Store)
```bash
# Build release APK
flutter build apk --release

# Or build App Bundle (recommended)
flutter build appbundle --release

# Sign the app (if not using automatic signing)
# Upload to Google Play Console
```

#### iOS (App Store)
```bash
# Build for iOS
flutter build ios --release

# Open in Xcode for signing and upload
open ios/Runner.xcworkspace
```

## 🔧 Environment Configuration

### Production Environment Variables

#### Backend (.env)
```env
# Production Database
DATABASE_URL="postgresql://user:password@host:5432/database"

# Security
NODE_ENV=production
JWT_SECRET="your-super-secure-jwt-secret-32-chars-min"
JWT_REFRESH_SECRET="your-super-secure-refresh-secret-32-chars-min"

# Google OAuth
GOOGLE_CLIENT_ID="your-production-google-client-id"
GOOGLE_CLIENT_SECRET="your-production-google-client-secret"

# Server
PORT=3000
API_BASE_URL="https://api.yourdomain.com"
FRONTEND_URL="https://yourdomain.com"

# CORS
CORS_ORIGIN="https://yourdomain.com"
SOCKET_CORS_ORIGIN="https://yourdomain.com"

# Email (if using)
SMTP_HOST="smtp.gmail.com"
SMTP_PORT=587
SMTP_USER="your-email@gmail.com"
SMTP_PASS="your-app-password"

# File Upload
UPLOAD_DIR="/app/uploads"
MAX_FILE_SIZE=10485760

# Logging
LOG_LEVEL="error"
DEBUG=false
ENABLE_SWAGGER=false

# Rate Limiting
RATE_LIMIT_MAX_REQUESTS=50
```

#### Frontend (Environment)
```dart
// lib/config/environment.dart
class Environment {
  static const String apiBaseUrl = 'https://api.yourdomain.com/api';
  static const String socketUrl = 'https://api.yourdomain.com';
  static const String googleClientId = 'your-production-google-client-id';
  static const bool isDebugMode = false;
}
```

## 🔒 Security Considerations

### SSL/TLS Certificate
```bash
# Using Let's Encrypt with Certbot
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com
```

### Firewall Configuration
```bash
# UFW (Ubuntu)
sudo ufw allow ssh
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable
```

### Database Security
```sql
-- Create read-only user for monitoring
CREATE USER monitor WITH PASSWORD 'monitor-password';
GRANT CONNECT ON DATABASE taskmanagement TO monitor;
GRANT USAGE ON SCHEMA public TO monitor;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO monitor;
```

## 📊 Monitoring and Logging

### PM2 Monitoring
```bash
# Monitor processes
pm2 monit

# View logs
pm2 logs

# Restart app
pm2 restart all
```

### Log Rotation
```bash
# Install logrotate configuration
sudo nano /etc/logrotate.d/taskmanagement

# Configuration
/app/logs/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 node node
    postrotate
        pm2 reload all
    endscript
}
```

## 🔄 CI/CD Pipeline

### GitHub Actions Example
```yaml
# .github/workflows/deploy.yml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  deploy-backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          
      - name: Install dependencies
        run: |
          cd backend
          npm ci
          
      - name: Run tests
        run: |
          cd backend
          npm test
          
      - name: Deploy to server
        run: |
          # Your deployment script here
          
  deploy-frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
          
      - name: Build web app
        run: |
          cd frontend
          flutter pub get
          flutter build web --release
          
      - name: Deploy to hosting
        run: |
          # Your deployment script here
```

## 🆘 Troubleshooting

### Common Issues

1. **Database Connection Issues**
   - Check DATABASE_URL format
   - Verify database server is running
   - Check firewall rules

2. **CORS Errors**
   - Verify CORS_ORIGIN in backend .env
   - Check frontend API base URL

3. **File Upload Issues**
   - Check UPLOAD_DIR permissions
   - Verify MAX_FILE_SIZE setting

4. **Socket.IO Connection Issues**
   - Check proxy configuration for WebSocket
   - Verify SOCKET_CORS_ORIGIN setting

### Health Checks
```bash
# Backend health check
curl https://api.yourdomain.com/health

# Database connection test
npm run db:test

# Check logs
pm2 logs --lines 100
```

## 📈 Performance Optimization

### Backend Optimization
- Enable gzip compression
- Use Redis for session storage
- Implement database connection pooling
- Add database indexes
- Use CDN for static files

### Frontend Optimization
- Enable web app caching
- Optimize images and assets
- Use lazy loading
- Implement service workers

This deployment guide provides comprehensive instructions for deploying the Task Management Tool to production environments. Choose the deployment method that best fits your infrastructure and requirements.
