const express = require('express');
const multer = require('multer');
const fileController = require('../controllers/fileController');

const router = express.Router();

// Configure multer for memory storage
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB limit
  },
  fileFilter: (req, file, cb) => {
    // Allow common file types
    const allowedTypes = [
      'image/jpeg', 'image/png', 'image/gif', 'image/webp',
      'application/pdf', 'application/msword', 
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.ms-excel',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'text/plain', 'text/csv',
      'audio/mpeg', 'audio/wav', 'audio/ogg',
      'video/mp4', 'video/mpeg', 'video/quicktime'
    ];
    
    if (allowedTypes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('File type not allowed'), false);
    }
  }
});

/**
 * @swagger
 * /api/files/profile-picture:
 *   post:
 *     summary: Upload profile picture
 *     tags: [Files]
 *     security:
 *       - bearerAuth: []
 */
router.post('/profile-picture', upload.single('file'), fileController.uploadProfilePicture);

/**
 * @swagger
 * /api/files/profile-picture/{fileId}:
 *   get:
 *     summary: Get profile picture
 *     tags: [Files]
 */
router.get('/profile-picture/:fileId', fileController.getProfilePicture);

/**
 * @swagger
 * /api/files/task-attachment:
 *   post:
 *     summary: Upload task attachment
 *     tags: [Files]
 *     security:
 *       - bearerAuth: []
 */
router.post('/task-attachment', upload.single('file'), fileController.uploadTaskAttachment);

/**
 * @swagger
 * /api/files/chat-media:
 *   post:
 *     summary: Upload chat media
 *     tags: [Files]
 *     security:
 *       - bearerAuth: []
 */
router.post('/chat-media', upload.single('file'), fileController.uploadChatMedia);

/**
 * @swagger
 * /api/files/{fileId}:
 *   get:
 *     summary: Download file
 *     tags: [Files]
 *     security:
 *       - bearerAuth: []
 */
router.get('/:fileId', fileController.downloadFile);

/**
 * @swagger
 * /api/files/{fileId}:
 *   delete:
 *     summary: Delete file
 *     tags: [Files]
 *     security:
 *       - bearerAuth: []
 */
router.delete('/:fileId', fileController.deleteFile);

module.exports = router;