# Deployment Guide (Backend on Ubuntu / AWS)

This guide deploys the Node.js backend behind Nginx with Gmail SMTP for email.

## Prerequisites
- Ubuntu 22.04 on AWS EC2
- Nginx with TLS (Certbot)
- Node.js 18+, pm2
- PostgreSQL (managed RDS endpoint)
- Redis (optional for now)
- Gmail or Google Workspace account with 2FA and App Password

## Environment variables (.env)

```env
PORT=3003
NODE_ENV=production
CORS_ORIGIN=https://ai.swargfood.com

# Database
PG_HOST=ls-f772dda62fea5a74f7a3e8f9139a79078b65a32f.crq8gq4ka0rw.ap-south-1.rds.amazonaws.com
PG_PORT=5432
PG_USER=dbmasteruser
PG_PASSWORD=<replace>
PG_DATABASE=tasktool

# Gmail SMTP
EMAIL_PROVIDER=gmail
SMTP_HOST=smtp.gmail.com
SMTP_PORT=465
SMTP_SECURE=true
SMTP_USER=youraddress@gmail.com
SMTP_PASS=<gmail-app-password>
EMAIL_FROM="Task Tool <youraddress@gmail.com>"
EMAIL_DAILY_SUMMARY_HOUR=08
```

## Steps
1. Run `backend/scripts/setup_server.sh` on the server
2. Configure your Nginx with the provided server block (see below). Ensure locations for:
   - `/task/health`, `/task/api`, `/task/socket.io/`
   - `/task/` (Flutter web assets alias) and uploads alias
3. From your local machine, copy backend to server and run `backend/scripts/deploy_backend.sh`
4. Edit `/var/www/task/backend/.env` with real DB and SMTP credentials
5. `pm2 save` then verify: `curl -fsS https://ai.swargfood.com/task/health`

## Nginx server block
Use the block you provided; ensure proxy to `http://localhost:3003` for API and socket paths.

## Gmail SMTP notes
- Enable 2-Step Verification on the Gmail/Workspace account
- Create an App Password for Mail
- Limits: Free Gmail ~500/day; Workspace up to ~2,000/day
- Configure SPF/DKIM/DMARC if using a custom domain (Workspace recommended)
- Add rate-limiting to queues if you approach limits

