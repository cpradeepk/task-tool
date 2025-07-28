const express = require('express');
const router = express.Router();
const timelineController = require('../controllers/timelineController');
const { authenticateToken, requireAdminOrProjectManager } = require('../middleware/auth');

// Apply authentication to all routes
router.use(authenticateToken);

// Get project timeline for Gantt chart
router.get('/:projectId/timeline', timelineController.getProjectTimeline);

// Create timeline entry (Admin/Project Manager only)
router.post('/:projectId/timeline', requireAdminOrProjectManager, timelineController.createTimelineEntry);

// Update timeline entry (Admin/Project Manager only)
router.put('/timeline/:timelineId', requireAdminOrProjectManager, timelineController.updateTimelineEntry);

// Get critical path analysis
router.get('/:projectId/critical-path', timelineController.getCriticalPath);

// Get timeline conflicts and issues
router.get('/:projectId/timeline-issues', timelineController.getTimelineIssues);

module.exports = router;
