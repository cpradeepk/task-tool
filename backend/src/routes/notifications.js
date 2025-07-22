const express = require('express');
const { authenticateToken, requireAdmin } = require('../middleware/auth');
const notificationController = require('../controllers/notificationController');

const router = express.Router();

// User notification routes
router.get('/', authenticateToken, notificationController.getNotifications);
router.get('/stats', authenticateToken, notificationController.getNotificationStats);
router.put('/:notificationId/read', authenticateToken, notificationController.markAsRead);
router.post('/mark-all-read', authenticateToken, notificationController.markAllAsRead);
router.delete('/:notificationId', authenticateToken, notificationController.deleteNotification);

// Notification preferences
router.get('/preferences', authenticateToken, notificationController.getNotificationPreferences);
router.put('/preferences', authenticateToken, notificationController.updateNotificationPreferences);

// Admin routes
router.post('/', authenticateToken, requireAdmin, notificationController.createNotification);
router.post('/bulk', authenticateToken, requireAdmin, notificationController.createBulkNotifications);
router.post('/test', authenticateToken, requireAdmin, notificationController.testNotification);

module.exports = router;
