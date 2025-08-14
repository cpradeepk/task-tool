# Task Tool (Monorepo)

- frontend/ — Flutter app (web/android/ios)
- backend/ — Node.js Express API + Socket.io
- docs/ — Architecture, deployment, requirements

## Quick start (backend dev)

```bash
cd backend
cp .env.example .env # and edit values
npm install
npm run dev
# GET http://localhost:3003/task/health
# POST http://localhost:3003/task/api/test-email { "to": "youraddress@gmail.com" }
```

## Email via Gmail SMTP
- Enable 2FA on the Gmail/Workspace account
- Create an App Password for Mail and set SMTP_USER/SMTP_PASS
- Default SMTP host: smtp.gmail.com port 465 secure

## Nginx
Map `/task/*` to backend at 3003 and serve Flutter web from `/var/www/task/frontend/web/`.

