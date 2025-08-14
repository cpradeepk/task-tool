# Local Development

## Prereqs
- Node 18+
- Docker Desktop (for Postgres/Redis via docker-compose)
- Gmail App Password in .env for SMTP tests

## Start services
```bash
docker compose up -d
```

## Backend
```bash
cd backend
cp .env.example .env
# set PG_* to point to docker compose if you want local PG
# PG_HOST=localhost PG_PORT=5432 PG_USER=dbmasteruser PG_PASSWORD=example PG_DATABASE=tasktool
npm install
npm run migrate:latest
npm run seed:run
npm run dev
```

Health: http://localhost:3003/task/health
Test email: POST http://localhost:3003/task/api/test-email { "to": "you@gmail.com" }

