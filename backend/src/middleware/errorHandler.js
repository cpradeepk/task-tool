/**
 * Comprehensive error handling middleware for consistent error responses
 */

// Custom error classes
export class ValidationError extends Error {
  constructor(message, field = null) {
    super(message);
    this.name = 'ValidationError';
    this.field = field;
    this.statusCode = 400;
  }
}

export class AuthenticationError extends Error {
  constructor(message = 'Authentication required') {
    super(message);
    this.name = 'AuthenticationError';
    this.statusCode = 401;
  }
}

export class AuthorizationError extends Error {
  constructor(message = 'Insufficient permissions') {
    super(message);
    this.name = 'AuthorizationError';
    this.statusCode = 403;
  }
}

export class NotFoundError extends Error {
  constructor(resource = 'Resource') {
    super(`${resource} not found`);
    this.name = 'NotFoundError';
    this.statusCode = 404;
  }
}

export class ConflictError extends Error {
  constructor(message = 'Resource conflict') {
    super(message);
    this.name = 'ConflictError';
    this.statusCode = 409;
  }
}

export class DatabaseError extends Error {
  constructor(message = 'Database operation failed') {
    super(message);
    this.name = 'DatabaseError';
    this.statusCode = 500;
  }
}

// Error response formatter
export const formatErrorResponse = (error, req = null) => {
  const response = {
    error: error.message || 'An unexpected error occurred',
    timestamp: new Date().toISOString(),
    path: req?.path || 'unknown',
    method: req?.method || 'unknown',
  };

  // Add additional context in development
  if (process.env.NODE_ENV === 'development') {
    response.stack = error.stack;
    response.details = {
      name: error.name,
      statusCode: error.statusCode,
    };
  }

  // Add field information for validation errors
  if (error.field) {
    response.field = error.field;
  }

  return response;
};

// Main error handling middleware
export const errorHandler = (error, req, res, next) => {
  console.error('Error occurred:', {
    message: error.message,
    stack: error.stack,
    path: req.path,
    method: req.method,
    user: req.user?.id || 'anonymous',
    timestamp: new Date().toISOString(),
  });

  let statusCode = 500;
  let message = 'Internal server error';

  // Handle known error types
  if (error.statusCode) {
    statusCode = error.statusCode;
    message = error.message;
  } else if (error.name === 'ValidationError') {
    statusCode = 400;
    message = error.message;
  } else if (error.name === 'CastError') {
    statusCode = 400;
    message = 'Invalid ID format';
  } else if (error.code === 'ECONNREFUSED') {
    statusCode = 503;
    message = 'Service temporarily unavailable';
  } else if (error.code === 'ETIMEDOUT') {
    statusCode = 408;
    message = 'Request timeout';
  } else if (error.code === '23505') { // PostgreSQL unique violation
    statusCode = 409;
    message = 'Resource already exists';
  } else if (error.code === '23503') { // PostgreSQL foreign key violation
    statusCode = 400;
    message = 'Invalid reference to related resource';
  } else if (error.code === '23502') { // PostgreSQL not null violation
    statusCode = 400;
    message = 'Required field is missing';
  }

  // Send error response
  res.status(statusCode).json(formatErrorResponse(error, req));
};

// Async error wrapper for route handlers
export const asyncHandler = (fn) => {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};

// Validation helper
export const validateRequired = (fields, body) => {
  const missing = [];
  
  for (const field of fields) {
    if (!body[field] || (typeof body[field] === 'string' && body[field].trim() === '')) {
      missing.push(field);
    }
  }
  
  if (missing.length > 0) {
    throw new ValidationError(`Required fields missing: ${missing.join(', ')}`);
  }
};

// Input sanitization helper
export const sanitizeInput = (input) => {
  if (typeof input === 'string') {
    return input.trim().replace(/[<>]/g, '');
  }
  return input;
};

// Database error handler
export const handleDatabaseError = (error, operation = 'database operation') => {
  console.error(`Database error during ${operation}:`, error);
  
  if (error.code === '23505') {
    throw new ConflictError('Resource already exists');
  } else if (error.code === '23503') {
    throw new ValidationError('Invalid reference to related resource');
  } else if (error.code === '23502') {
    throw new ValidationError('Required field is missing');
  } else if (error.code === 'ECONNREFUSED') {
    throw new DatabaseError('Database connection failed');
  } else {
    throw new DatabaseError(`Failed to ${operation}`);
  }
};

// Rate limiting error handler
export const rateLimitHandler = (req, res) => {
  res.status(429).json(formatErrorResponse(
    new Error('Too many requests, please try again later'),
    req
  ));
};

// 404 handler for unmatched routes
export const notFoundHandler = (req, res) => {
  res.status(404).json(formatErrorResponse(
    new NotFoundError('Endpoint'),
    req
  ));
};

// Request validation middleware
export const validateRequest = (schema) => {
  return (req, res, next) => {
    try {
      // Basic validation - can be extended with a validation library like Joi
      if (schema.required) {
        validateRequired(schema.required, req.body);
      }
      
      // Sanitize inputs
      if (req.body) {
        for (const key in req.body) {
          req.body[key] = sanitizeInput(req.body[key]);
        }
      }
      
      next();
    } catch (error) {
      next(error);
    }
  };
};

// Health check endpoint
export const healthCheck = (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    version: process.env.npm_package_version || '1.0.0',
  });
};

// Graceful shutdown handler
export const gracefulShutdown = (server) => {
  const shutdown = (signal) => {
    console.log(`Received ${signal}. Starting graceful shutdown...`);
    
    server.close((err) => {
      if (err) {
        console.error('Error during server shutdown:', err);
        process.exit(1);
      }
      
      console.log('Server closed successfully');
      process.exit(0);
    });
    
    // Force shutdown after 30 seconds
    setTimeout(() => {
      console.error('Forced shutdown after timeout');
      process.exit(1);
    }, 30000);
  };
  
  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
};

// Request logging middleware
export const requestLogger = (req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    const logData = {
      method: req.method,
      path: req.path,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
      userAgent: req.get('User-Agent'),
      ip: req.ip,
      user: req.user?.id || 'anonymous',
      timestamp: new Date().toISOString(),
    };
    
    if (res.statusCode >= 400) {
      console.error('Request error:', logData);
    } else {
      console.log('Request completed:', logData);
    }
  });
  
  next();
};

// CORS error handler
export const corsErrorHandler = (err, req, res, next) => {
  if (err.message && err.message.includes('CORS')) {
    return res.status(403).json(formatErrorResponse(
      new Error('CORS policy violation'),
      req
    ));
  }
  next(err);
};

export default {
  errorHandler,
  asyncHandler,
  validateRequired,
  sanitizeInput,
  handleDatabaseError,
  rateLimitHandler,
  notFoundHandler,
  validateRequest,
  healthCheck,
  gracefulShutdown,
  requestLogger,
  corsErrorHandler,
  ValidationError,
  AuthenticationError,
  AuthorizationError,
  NotFoundError,
  ConflictError,
  DatabaseError,
};
