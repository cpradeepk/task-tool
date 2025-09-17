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
import { knex } from './db/index.js';
import {
  errorHandler,
  notFoundHandler,
  requestLogger,
  corsErrorHandler,
  healthCheck,
  gracefulShutdown
} from './middleware/errorHandler.js';

const app = express();
app.use(helmet());
const corsOrigins = process.env.CORS_ORIGIN ? process.env.CORS_ORIGIN.split(',') : ['*'];
const corsOptions = corsOrigins.includes('*')
  ? { origin: true, credentials: false }
  : { origin: corsOrigins, credentials: true };
app.use(cors(corsOptions));
app.use(express.json({ limit: '2mb' }));
app.use(morgan('dev'));

// Add request logging and CORS error handling
app.use(requestLogger);
app.use(corsErrorHandler);

// Health route
app.get('/task/health', healthCheck);

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

// Dashboard routes
import dashboardRouter from './api/dashboard.js';
app.use('/task/api/dashboard', dashboardRouter);

// Task comments and history routes
import taskCommentsRouter from './api/task-comments.js';
app.use('/task/api/tasks', taskCommentsRouter);

// Task templates routes
import taskTemplatesRouter from './api/task-templates.js';
app.use('/task/api/task-templates', taskTemplatesRouter);

// Leave management routes
import leaveManagementRouter from './api/leave-management.js';
app.use('/task/api/leaves', leaveManagementRouter);

// WFH management routes
import wfhManagementRouter from './api/wfh-management.js';
app.use('/task/api/wfh', wfhManagementRouter);

// Enhanced user management routes
import enhancedUsersRouter from './api/enhanced-users.js';
app.use('/task/api/enhanced-users', enhancedUsersRouter);

// Calendar routes
import calendarRouter from './api/calendar.js';
app.use('/task/api/calendar', calendarRouter);

// Notes routes
import notesRouter from './api/notes.js';
app.use('/task/api/notes', notesRouter);

// Team Chat routes
import teamChatRouter from './api/team-chat.js';
app.use('/task/api/chat', teamChatRouter);

// Notifications routes
import notificationsRouter from './api/notifications.js';
app.use('/task/api/notifications', notificationsRouter);

// Search routes
import searchRouter from './api/search.js';
app.use('/task/api/search', searchRouter);

// Email routes
import emailRouter from './api/email.js';
app.use('/task/api/email', emailRouter);

// Admin routes
import adminUsersRouter from './api/admin-users.js';
import adminReportsRouter from './api/admin-reports.js';
import adminProjectsRouter from './api/admin-projects.js';

app.use('/task/api/admin/users', adminUsersRouter);
app.use('/task/api/admin/reports', adminReportsRouter);
app.use('/task/api/admin/projects', adminProjectsRouter);

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

// Roles and user roles
import rolesRouter from './api/roles.js';
import userRolesRouter from './api/user-roles.js';
app.use('/task/api/roles', rolesRouter);
app.use('/task/api/user-roles', userRolesRouter);

// Uploads (presigned URLs)
import uploadsRouter from './api/uploads.js';
app.use('/task/api/uploads', uploadsRouter);

// Exports
import exportsRouter from './api/exports.js';
app.use('/task/api/exports', exportsRouter);

// Dependencies & PERT
import depsPertRouter from './api/deps_pert.js';
app.use('/task/api/projects/:projectId/tasks', depsPertRouter);

// Subtasks
import subtasksRouter from './api/subtasks.js';
app.use('/task/api/projects/:projectId/tasks/:taskId/subtasks', subtasksRouter);

// Chat
import chatRouter from './api/chat.js';
app.use('/task/api/chat', chatRouter);

// Calendar routes already imported above

// Users (search for assignment)
import usersRouter from './api/users.js';
app.use('/task/api/users', usersRouter);

// Socket.io configuration will be handled after server creation

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

// Add error handling middleware (must be after all routes)
app.use(notFoundHandler);
app.use(errorHandler);

// Create HTTP server
const server = http.createServer(app);
const io = new SocketIOServer(server, {
  path: '/task/socket.io/',
  cors: { origin: process.env.CORS_ORIGIN?.split(',') || '*', credentials: true }
});

// Initialize Socket.io after creation
import { registerIO } from './events.js';
registerIO(io);

io.on('connection', (socket) => {
  socket.emit('welcome', { message: 'Connected to Task Tool realtime gateway' });
});

const PORT = process.env.PORT || 3003;

// Start server with basic database connection test
async function startServer() {
  try {
    // Test database connection
    await knex.raw('SELECT 1');
    console.log('Database connection successful');
  } catch (error) {
    console.log('Database connection failed, continuing anyway:', error.message);
  }

  server.listen(PORT, () => {
    console.log(`Task Tool backend listening on port ${PORT}`);
    console.log(`Health check: http://localhost:${PORT}/task/health`);
    console.log(`API base: http://localhost:${PORT}/task/api`);

    // Initialize email service
    initEmail();

    // Start queue workers
    startWorkers();

    // Setup graceful shutdown
    gracefulShutdown(server);
  });
}

startServer();

