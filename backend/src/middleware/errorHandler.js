const logger = require('../config/logger');

const errorHandler = (err, req, res, next) => {
  logger.error('Error occurred:', {
    message: err.message,
    stack: err.stack,
    url: req.url,
    method: req.method,
    ip: req.ip,
    userAgent: req.get('User-Agent')
  });

  // Prisma errors
  if (err.code && err.code.startsWith('P')) {
    switch (err.code) {
      case 'P2002':
        return res.status(400).json({
          error: 'Duplicate entry',
          message: 'A record with this information already exists'
        });
      case 'P2025':
        return res.status(404).json({
          error: 'Record not found',
          message: 'The requested record was not found'
        });
      case 'P2003':
        return res.status(400).json({
          error: 'Foreign key constraint',
          message: 'Referenced record does not exist'
        });
      default:
        return res.status(500).json({
          error: 'Database error',
          message: 'A database error occurred'
        });
    }
  }

  // JWT errors
  if (err.name === 'JsonWebTokenError') {
    return res.status(401).json({
      error: 'Invalid token',
      message: 'The provided token is invalid'
    });
  }

  if (err.name === 'TokenExpiredError') {
    return res.status(401).json({
      error: 'Token expired',
      message: 'The provided token has expired'
    });
  }

  // Validation errors
  if (err.name === 'ValidationError') {
    return res.status(400).json({
      error: 'Validation error',
      message: err.message,
      details: err.details || []
    });
  }

  // Google API errors
  if (err.code && (err.code >= 400 && err.code < 500)) {
    return res.status(err.code).json({
      error: 'External service error',
      message: err.message || 'An error occurred with external service'
    });
  }

  // Default error
  const statusCode = err.statusCode || err.status || 500;
  const message = err.message || 'Internal server error';

  res.status(statusCode).json({
    error: statusCode >= 500 ? 'Internal server error' : 'Bad request',
    message: process.env.NODE_ENV === 'production' && statusCode >= 500 
      ? 'Something went wrong' 
      : message
  });
};

module.exports = errorHandler;
