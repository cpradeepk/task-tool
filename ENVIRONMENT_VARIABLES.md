# Task Tool Environment Variables

This document lists all required environment variables for the Task Tool application.

## Backend Environment Variables (.env file location: `/srv/task-tool/backend/.env`)

### Database Configuration
```bash
# PostgreSQL Database
PG_HOST=your-database-host
PG_PORT=5432
PG_USER=your-database-user
PG_PASSWORD=your-database-password
PG_DATABASE=tasktool
PG_SSL=true
```

### Authentication & Security
```bash
# JWT Secret for token signing
JWT_SECRET=your-jwt-secret-key

# Google OAuth (for future implementation)
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret
```

### **NEW: Admin Login Credentials**
```bash
# Admin Authentication System
ADMIN_USERNAME=admin
ADMIN_PASSWORD=your-secure-admin-password
```

### Redis Configuration
```bash
# Redis for BullMQ queues
REDIS_URL=redis://127.0.0.1:6379
```

### Email Configuration
```bash
# SMTP Settings for notifications
SMTP_HOST=smtp.gmail.com
SMTP_PORT=465
SMTP_SECURE=true
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
EMAIL_FROM=Task Tool <your-email@gmail.com>
```

### Application Settings
```bash
# Server Configuration
PORT=3003
NODE_ENV=production
BASE_URL=https://ai.swargfood.com
CORS_ORIGIN=https://ai.swargfood.com

# File Uploads
UPLOAD_DIR=/var/www/task/uploads
```

## PM2 Ecosystem Configuration

The environment variables are also configured in `/srv/task-tool/backend/ecosystem.config.cjs`:

```javascript
module.exports = {
  apps: [{
    name: 'task-tool-backend',
    cwd: '/srv/task-tool/backend',
    script: 'src/server.js',
    interpreter: 'node',
    env: {
      NODE_ENV: 'production',
      PORT: 3003,
      BASE_URL: 'https://ai.swargfood.com',
      
      // Database
      PG_HOST: 'your-database-host',
      PG_PORT: 5432,
      PG_USER: 'your-database-user',
      PG_PASSWORD: 'your-database-password',
      PG_DATABASE: 'tasktool',
      PG_SSL: 'true',
      
      // Redis
      REDIS_URL: 'redis://127.0.0.1:6379',
      
      // Auth
      JWT_SECRET: 'your-jwt-secret',
      
      // NEW: Admin Credentials
      ADMIN_USERNAME: 'admin',
      ADMIN_PASSWORD: 'your-secure-admin-password',
      
      // CORS
      CORS_ORIGIN: 'https://ai.swargfood.com',
      
      // SMTP
      SMTP_HOST: 'smtp.gmail.com',
      SMTP_PORT: 465,
      SMTP_SECURE: true,
      SMTP_USER: 'your-email@gmail.com',
      SMTP_PASS: 'your-app-password',
      EMAIL_FROM: 'Task Tool <your-email@gmail.com>',
      
      // Uploads
      UPLOAD_DIR: '/var/www/task/uploads'
    }
  }]
};
```

## Security Recommendations

### Admin Password
- Use a strong password with at least 12 characters
- Include uppercase, lowercase, numbers, and special characters
- Example: `AdminPass123!@#`

### JWT Secret
- Use a long, random string (at least 32 characters)
- Can be generated with: `openssl rand -base64 32`

### Database Password
- Use the existing RDS password provided in your current configuration
- Ensure it's properly quoted if it contains special characters

## New Features Added

### 1. Admin Login System
- **Environment Variables**: `ADMIN_USERNAME`, `ADMIN_PASSWORD`
- **Access**: Admin login button in top-right corner of navigation
- **Permissions**: Admin users bypass all RBAC restrictions

### 2. PIN Authentication
- **Database**: New columns added to `users` table for PIN storage
- **Features**: 4-6 digit PIN, account lockout after failed attempts
- **Security**: BCrypt hashing, 15-minute lockout after 5 failed attempts

### 3. Enhanced Projects UI
- **Features**: Expandable/collapsible project cards
- **Hierarchy**: Projects → Modules → Tasks in nested display
- **Visual**: Icons and colors for different task statuses

## Database Migrations

Run these commands to apply new database changes:

```bash
cd /srv/task-tool/backend
npm run migrate:latest
npm run seed:run
```

## Deployment

After updating environment variables, restart the application:

```bash
/scripts/deploy.sh
```

This will:
1. Pull latest code
2. Install dependencies
3. Run migrations and seeds
4. Restart backend with new environment variables
5. Build and deploy frontend
6. Reload Nginx
