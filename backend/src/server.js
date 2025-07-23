require('dotenv').config();
const http = require('http');
const app = require('./app');
const logger = require('./config/logger');
const { PrismaClient } = require('@prisma/client');
const socketServer = require('./socket/socketServer');

const prisma = new PrismaClient();
const PORT = process.env.PORT || 3000;

// Test database connection
async function initializeServices() {
  try {
    await prisma.$connect();
    logger.info('✅ Database connected successfully');
  } catch (error) {
    logger.error('❌ Database connection failed:', error);
    process.exit(1);
  }
}

// Initialize services
initializeServices();

// Create HTTP server and initialize Socket.io
const server = http.createServer(app);
const io = socketServer.initialize(server);

// Start server
server.listen(PORT, () => {
  logger.info(`🚀 SwargFood Task Management Server running on port ${PORT}`);
  logger.info(`📝 Environment: ${process.env.NODE_ENV || 'development'}`);
  logger.info(`📚 API Documentation: http://localhost:${PORT}/task/api-docs`);
  logger.info(`❤️  Health Check: http://localhost:${PORT}/task/health`);
  logger.info(`🔌 Socket.IO server initialized at /task/socket.io/`);
  logger.info(`🌐 API Base: http://localhost:${PORT}/task/api`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  server.close(() => {
    logger.info('Process terminated');
  });
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  server.close(() => {
    logger.info('Process terminated');
  });
});

module.exports = server;
