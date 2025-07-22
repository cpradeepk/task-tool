const express = require('express');
const { authenticateToken } = require('../middleware/auth');
const timeTrackingController = require('../controllers/timeTrackingController');

const router = express.Router();

// Time entry routes
router.get('/', authenticateToken, timeTrackingController.getTimeEntries);
router.post('/', authenticateToken, timeTrackingController.createTimeEntry);
router.get('/:id', authenticateToken, timeTrackingController.getTimeEntry);
router.put('/:id', authenticateToken, timeTrackingController.updateTimeEntry);
router.delete('/:id', authenticateToken, timeTrackingController.deleteTimeEntry);

// Task time tracking routes
router.get('/tasks/:taskId', authenticateToken, timeTrackingController.getTaskTimeEntries);
router.post('/tasks/:taskId/start', authenticateToken, timeTrackingController.startTimer);
router.post('/tasks/:taskId/stop', authenticateToken, timeTrackingController.stopTimer);

// Project time tracking routes
router.get('/projects/:projectId', authenticateToken, timeTrackingController.getProjectTimeEntries);
router.get('/projects/:projectId/summary', authenticateToken, timeTrackingController.getProjectTimeSummary);

// User time tracking routes
router.get('/users/:userId', authenticateToken, timeTrackingController.getUserTimeEntries);
router.get('/users/:userId/summary', authenticateToken, timeTrackingController.getUserTimeSummary);

// Reports
router.get('/reports/daily', authenticateToken, timeTrackingController.getDailyTimeReport);
router.get('/reports/weekly', authenticateToken, timeTrackingController.getWeeklyTimeReport);
router.get('/reports/monthly', authenticateToken, timeTrackingController.getMonthlyTimeReport);

module.exports = router;
