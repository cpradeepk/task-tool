const express = require('express');
const { param } = require('express-validator');
const fileController = require('../controllers/fileController');
const { authenticateToken } = require('../middleware/auth');
const { validateRequest } = require('../middleware/validation');
const upload = require('../middleware/upload');

const router = express.Router();

// All routes require authentication
router.use(authenticateToken);

/**
 * @swagger
 * /api/files/profile-picture:
 *   post:
 *     summary: Upload profile picture
 *     tags: [Files]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               file:
 *                 type: string
 *                 format: binary
 *     responses:
 *       200:
 *         description: Profile picture uploaded successfully
 *       400:
 *         description: Invalid file or file too large
 */
router.post('/profile-picture', 
  upload.single('file'), 
  fileController.uploadProfilePicture
);

/**
 * @swagger
 * /api/files/task-attachment:
 *   post:
 *     summary: Upload task attachment
 *     tags: [Files]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               file:
 *                 type: string
 *                 format: binary
 *               taskId:
 *                 type: string
 *               description:
 *                 type: string
 *     responses:
 *       200:
 *         description: File uploaded successfully
 */
router.post('/task-attachment', 
  upload.single('file'), 
  fileController.uploadTaskAttachment
);

/**
 * @swagger
 * /api/files/{id}/download:
 *   get:
 *     summary: Download file
 *     tags: [Files]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: File downloaded successfully
 *       404:
 *         description: File not found
 */
router.get('/:id/download', [
  param('id').isString().notEmpty()
], validateRequest, fileController.downloadFile);

/**
 * @swagger
 * /api/files/{id}:
 *   delete:
 *     summary: Delete file
 *     tags: [Files]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: File deleted successfully
 *       404:
 *         description: File not found
 */
router.delete('/:id', [
  param('id').isString().notEmpty()
], validateRequest, fileController.deleteFile);

/**
 * @swagger
 * /api/files/user/{userId}:
 *   get:
 *     summary: Get user files
 *     tags: [Files]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: userId
 *         required: true
 *         schema:
 *           type: string
 *       - in: query
 *         name: folderType
 *         schema:
 *           type: string
 *           enum: [PROFILE_PICTURES, TASK_ATTACHMENTS, CHAT_MEDIA, DOCUMENTS, VOICE_NOTES]
 *     responses:
 *       200:
 *         description: Files retrieved successfully
 */
router.get('/user/:userId', [
  param('userId').isString().notEmpty()
], validateRequest, fileController.getUserFiles);

module.exports = router;