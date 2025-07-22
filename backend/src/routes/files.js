const express = require('express');
const { authenticateToken, requireAdmin } = require('../middleware/auth');
const fileController = require('../controllers/fileController');
const fileService = require('../services/fileService');

const router = express.Router();

// Configure multer for different upload types
const taskUpload = fileService.getMulterConfig('tasks');
const chatUpload = fileService.getMulterConfig('chat');
const projectUpload = fileService.getMulterConfig('projects');
const generalUpload = fileService.getMulterConfig('general');

// File upload routes
router.post('/upload', authenticateToken, generalUpload.single('file'), fileController.uploadFile);
router.post('/upload/multiple', authenticateToken, generalUpload.array('files', 10), fileController.uploadMultipleFiles);
router.post('/upload/task', authenticateToken, taskUpload.single('file'), fileController.uploadFile);
router.post('/upload/chat', authenticateToken, chatUpload.single('file'), fileController.uploadFile);
router.post('/upload/project', authenticateToken, projectUpload.single('file'), fileController.uploadFile);

// File access routes
router.get('/:fileId', authenticateToken, fileController.getFile);
router.get('/:fileId/download', authenticateToken, fileController.downloadFile);
router.get('/:fileId/preview', authenticateToken, fileController.previewFile);

// File management routes
router.put('/:fileId', authenticateToken, fileController.updateFile);
router.delete('/:fileId', authenticateToken, fileController.deleteFile);

// File listing routes
router.get('/user/files', authenticateToken, fileController.getUserFiles);
router.get('/user/recent', authenticateToken, fileController.getRecentFiles);
router.get('/user/stats', authenticateToken, fileController.getFileStats);

// Task and message file routes
router.get('/tasks/:taskId/files', authenticateToken, fileController.getTaskFiles);
router.get('/messages/:messageId/files', authenticateToken, fileController.getMessageFiles);

// Project file routes
router.get('/projects/:projectId/files', authenticateToken, fileController.getProjectFiles);

module.exports = router;