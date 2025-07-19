const multer = require('multer');
const logger = require('../config/logger');

// Configure multer for memory storage
const storage = multer.memoryStorage();

// File filter function
const fileFilter = (req, file, cb) => {
  const allowedTypes = process.env.ALLOWED_FILE_TYPES?.split(',') || [
    'image/jpeg',
    'image/png', 
    'image/gif',
    'image/webp',
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'text/plain',
    'audio/mpeg',
    'audio/wav',
    'video/mp4'
  ];

  if (allowedTypes.includes(file.mimetype)) {
    cb(null, true);
  } else {
    logger.warn(`File upload rejected: ${file.mimetype} not allowed`);
    cb(new Error(`File type ${file.mimetype} not allowed`), false);
  }
};

// Configure multer
const upload = multer({
  storage: storage,
  limits: {
    fileSize: parseInt(process.env.MAX_FILE_SIZE) || 10 * 1024 * 1024, // 10MB default
    files: 1
  },
  fileFilter: fileFilter
});

// Error handling middleware for multer
const handleUploadError = (error, req, res, next) => {
  if (error instanceof multer.MulterError) {
    if (error.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({
        error: 'File too large',
        message: `File size must be less than ${Math.round((parseInt(process.env.MAX_FILE_SIZE) || 10485760) / 1024 / 1024)}MB`
      });
    }
    if (error.code === 'LIMIT_FILE_COUNT') {
      return res.status(400).json({
        error: 'Too many files',
        message: 'Only one file allowed per upload'
      });
    }
    if (error.code === 'LIMIT_UNEXPECTED_FILE') {
      return res.status(400).json({
        error: 'Unexpected field',
        message: 'Unexpected file field'
      });
    }
  }
  
  if (error.message.includes('not allowed')) {
    return res.status(400).json({
      error: 'Invalid file type',
      message: error.message
    });
  }

  logger.error('Upload error:', error);
  return res.status(500).json({
    error: 'Upload failed',
    message: 'An error occurred during file upload'
  });
};

// Wrapper to add error handling
const uploadWithErrorHandling = (uploadFunction) => {
  return (req, res, next) => {
    uploadFunction(req, res, (error) => {
      if (error) {
        return handleUploadError(error, req, res, next);
      }
      next();
    });
  };
};

module.exports = {
  single: (fieldName) => uploadWithErrorHandling(upload.single(fieldName)),
  array: (fieldName, maxCount) => uploadWithErrorHandling(upload.array(fieldName, maxCount)),
  fields: (fields) => uploadWithErrorHandling(upload.fields(fields)),
  none: () => uploadWithErrorHandling(upload.none()),
  any: () => uploadWithErrorHandling(upload.any())
};