const express = require('express');
const { authenticateToken } = require('../middleware/auth');
const timeTrackingController = require('../controllers/timeTrackingController');

const router = express.Router();

// Timer control routes
router.post('/start', authenticateToken, timeTrackingController.startTimer);
router.post('/stop', authenticateToken, timeTrackingController.stopTimer);
router.get('/active', authenticateToken, timeTrackingController.getActiveTimer);

// Time entry management routes
router.put('/:id', authenticateToken, timeTrackingController.updateTimeEntry);
router.delete('/:id', authenticateToken, timeTrackingController.deleteTimeEntry);

// Task time tracking routes
router.get('/tasks/:taskId', authenticateToken, timeTrackingController.getTaskTimeEntries);

// Recent entries
router.get('/recent', authenticateToken, timeTrackingController.getRecentTimeEntries);

// Reports and analytics
router.get('/reports/user', authenticateToken, timeTrackingController.getUserTimeReport);
router.get('/reports/project', authenticateToken, timeTrackingController.getProjectTimeReport);
router.get('/analytics', authenticateToken, timeTrackingController.getTimeAnalytics);
router.get('/pert-comparison', authenticateToken, timeTrackingController.getPERTComparison);

module.exports = router;
