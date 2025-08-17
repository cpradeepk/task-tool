import 'dotenv/config';
import express from 'express';
import http from 'http';
import { Server as SocketIOServer } from 'socket.io';
import helmet from 'helmet';
import cors from 'cors';
import morgan from 'morgan';

import { initEmail } from './services/email.js';
import authRouter from './routes/auth.js';
import { emailQueue, startWorkers } from './queue/index.js';

const app = express();
app.use(helmet());
const corsOrigins = process.env.CORS_ORIGIN ? process.env.CORS_ORIGIN.split(',') : ['*'];
const corsOptions = corsOrigins.includes('*')
  ? { origin: true, credentials: false }
  : { origin: corsOrigins, credentials: true };
app.use(cors(corsOptions));
app.use(express.json({ limit: '2mb' }));
app.use(morgan('dev'));

// Health route
app.get('/task/health', (req, res) => {
  res.json({ ok: true, ts: new Date().toISOString() });
});

// API placeholder
app.get('/task/api/hello', (req, res) => {
  res.json({ message: 'Task Tool API is running' });
});

// Auth routes
app.use('/task/api/auth', authRouter);

// Admin auth routes
import adminAuthRouter from './routes/admin-auth.js';
app.use('/task/api/admin-auth', adminAuthRouter);

// PIN auth routes
import pinAuthRouter from './routes/pin-auth.js';
app.use('/task/api/pin-auth', pinAuthRouter);

// Admin routes
import adminUsersRouter from './api/admin-users.js';
app.use('/task/api/admin/users', adminUsersRouter);

// Projects CRUD
import projectsRouter from './api/projects.js';
app.use('/task/api/projects', projectsRouter);

// Nested routes: modules and tasks under projects
import modulesRouter from './api/modules.js';
import tasksRouter from './api/tasks.js';
app.use('/task/api/projects/:projectId/modules', modulesRouter);
app.use('/task/api/projects/:projectId/tasks', tasksRouter);
import tasksAdvancedRouter from './api/tasks-advanced.js';
app.use('/task/api/projects/:projectId/tasks', tasksAdvancedRouter);

// Me (profile)
import meRouter from './api/me.js';
app.use('/task/api/me', meRouter);

// Master data
import masterRouter from './api/master.js';
app.use('/task/api/master', masterRouter);

// Uploads (presigned URLs)
import uploadsRouter from './api/uploads.js';
app.use('/task/api/uploads', uploadsRouter);

// Exports
import exportsRouter from './api/exports.js';
app.use('/task/api/exports', exportsRouter);

// Dependencies & PERT
import depsPertRouter from './api/deps_pert.js';
app.use('/task/api/projects/:projectId/tasks', depsPertRouter);

// Chat
import chatRouter from './api/chat.js';
app.use('/task/api/chat', chatRouter);

// Calendar
import calendarRouter from './api/calendar.js';
app.use('/task/api/calendar', calendarRouter);

// Users (search for assignment)
import usersRouter from './api/users.js';
app.use('/task/api/users', usersRouter);

const server = http.createServer(app);

// Socket.io under /task/socket.io
const io = new SocketIOServer(server, {
  path: '/task/socket.io/',
  cors: { origin: process.env.CORS_ORIGIN?.split(',') || '*', credentials: true }
});

import { registerIO } from './events.js';
registerIO(io);

io.on('connection', (socket) => {
  socket.emit('welcome', { message: 'Connected to Task Tool realtime gateway' });
});

// Initialize email (Gmail SMTP)
const email = initEmail();
startWorkers({
  emailHandler: async (job) => {
    const { to, subject, html, text } = job.data;
    await email.send({ to, subject, html, text });
  }
});

// Start cron jobs (daily summary)
import { startCron } from './jobs/index.js';
startCron();

app.post('/task/api/test-email', async (req, res) => {
  try {
    const to = req.body?.to || process.env.SMTP_USER;
    await emailQueue.add('send', {
      to,
      subject: 'Task Tool SMTP Test',
      html: '<p>This is a test email from Task Tool via Gmail SMTP.</p>'
    });
    res.json({ ok: true, queued: true });
  } catch (err) {
    console.error('Email test failed', err);
    res.status(500).json({ ok: false, error: 'Email failed' });
  }
});

const PORT = process.env.PORT || 3003;
server.listen(PORT, () => {
  console.log(`Task Tool backend listening on port ${PORT}`);
});

