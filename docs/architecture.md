# Architecture (Gmail SMTP)

The backend uses Express + Socket.io and BullMQ with PostgreSQL and Redis. Email is sent via Gmail SMTP.

- API: `/task/api/*`
- Health: `/task/health`
- Realtime: `/task/socket.io/`
- Email: Nodemailer -> smtp.gmail.com

Mermaid diagram maintained in planning. Key components:
- Express REST, Socket.io under `/task/socket.io/`
- Service layer + RBAC (future files)
- BullMQ for jobs (email, summaries, exports)
- PostgreSQL primary store; Redis for queues/adapters
- Object storage (S3-compatible) for attachments (unchanged)

## Email transport
- Provider: Gmail SMTP via Nodemailer
- Config: host=smtp.gmail.com, port=465, secure=true, auth via app password
- Functions: assignment/status change/mention/daily summary emails
- Throttling: Queue rate limiter to respect Gmail limits

