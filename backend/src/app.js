const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const swaggerUi = require('swagger-ui-express');
const swaggerDocument = require('../swagger.json');
const logger = require('./config/logger');

// Import routes
const authRoutes = require('./routes/auth');
const projectRoutes = require('./routes/projects');
const taskRoutes = require('./routes/tasks');
const userRoutes = require('./routes/users');
const fileRoutes = require('./routes/files');
const chatRoutes = require('./routes/chat');
const notificationRoutes = require('./routes/notifications');
const activityRoutes = require('./routes/activity');
const timeTrackingRoutes = require('./routes/timeTracking');
const taskDependencyRoutes = require('./routes/taskDependencies');
const taskTemplateRoutes = require('./routes/taskTemplates');
const userRoleRoutes = require('./routes/userRoles');
const masterDataRoutes = require('./routes/masterData');

const app = express();

// Security middleware
app.use(helmet());

// Enhanced CORS for Flutter web
app.use(cors({
  origin: function (origin, callback) {
    // Allow requests with no origin (like mobile apps or curl requests)
    if (!origin) return callback(null, true);
    
    const allowedOrigins = [
      'http://localhost:3001',  // React frontend
      'http://localhost:3000',  // Flutter web dev server
      'http://127.0.0.1:3000',  // Alternative localhost
      /^http:\/\/localhost:\d+$/, // Any localhost port
      /^http:\/\/127\.0\.0\.1:\d+$/, // Any 127.0.0.1 port
    ];
    
    const isAllowed = allowedOrigins.some(allowed => {
      if (typeof allowed === 'string') {
        return origin === allowed;
      }
      return allowed.test(origin);
    });
    
    if (isAllowed) {
      callback(null, true);
    } else {
      console.log('CORS blocked origin:', origin);
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Accept', 'Origin', 'X-Requested-With'],
  exposedHeaders: ['Content-Length', 'X-Foo', 'X-Bar'],
  preflightContinue: false,
  optionsSuccessStatus: 204
}));

app.use(compression());

// Handle preflight requests
app.options('*', (req, res) => {
  res.header('Access-Control-Allow-Origin', req.headers.origin || '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization, Accept, Origin, X-Requested-With');
  res.header('Access-Control-Allow-Credentials', 'true');
  res.sendStatus(204);
});

// Logging middleware
app.use(morgan('combined', { stream: { write: message => logger.info(message.trim()) } }));

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// API Documentation (under /task prefix)
app.use('/task/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocument));

// Health check endpoint (under /task prefix)
app.get('/task/health', (req, res) => {
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development'
  });
});

// API routes (under /task prefix)
app.get('/task/api', (req, res) => {
  res.json({
    message: 'SwargFood Task Management API',
    version: '1.0.0',
    documentation: '/task/api-docs',
    endpoints: {
      auth: '/task/api/auth',
      users: '/task/api/users',
      projects: '/task/api/projects',
      tasks: '/task/api/tasks',
      files: '/task/api/files',
      chat: '/task/api/chat',
      notifications: '/task/api/notifications',
      activity: '/task/api/activity',
      timeTracking: '/task/api/time-tracking',
      taskDependencies: '/task/api/task-dependencies',
      taskTemplates: '/task/api/task-templates',
      userRoles: '/task/api/user-roles',
      masterData: '/task/api/master-data'
    }
  });
});

// Mount routes (under /task prefix)
app.use('/task/api/auth', authRoutes);
app.use('/task/api/users', userRoutes);
app.use('/task/api/projects', projectRoutes);
app.use('/task/api/tasks', taskRoutes);
app.use('/task/api/files', fileRoutes);
app.use('/task/api/chat', chatRoutes);
app.use('/task/api/notifications', notificationRoutes);
app.use('/task/api/activity', activityRoutes);
app.use('/task/api/time-tracking', timeTrackingRoutes);
app.use('/task/api/task-dependencies', taskDependencyRoutes);
app.use('/task/api/task-templates', taskTemplateRoutes);
app.use('/task/api/user-roles', userRoleRoutes);
app.use('/task/api/master-data', masterDataRoutes);

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Route not found',
    path: req.originalUrl
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', err);
  res.status(500).json({
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong'
  });
});

module.exports = app;
