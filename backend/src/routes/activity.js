const express = require('express');
const { authenticateToken, requireAdmin } = require('../middleware/auth');
const activityController = require('../controllers/activityController');

const router = express.Router();

// Project activity routes
router.get('/projects/:projectId', authenticateToken, activityController.getProjectActivities);
router.get('/projects/:projectId/stats', authenticateToken, activityController.getActivityStats);

// Task activity routes
router.get('/tasks/:taskId', authenticateToken, activityController.getTaskActivities);

// User activity routes
router.get('/users/:userId', authenticateToken, activityController.getUserActivities);

// Dashboard routes
router.get('/recent', authenticateToken, activityController.getRecentActivities);
router.get('/feed', authenticateToken, activityController.getActivityFeed);

// Admin routes
router.post('/log', authenticateToken, requireAdmin, activityController.logActivity);

module.exports = router;
