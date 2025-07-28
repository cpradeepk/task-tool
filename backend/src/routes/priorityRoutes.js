const express = require('express');
const router = express.Router();
const priorityController = require('../controllers/priorityController');
const { authenticateToken, requireAdminOrProjectManager } = require('../middleware/auth');

// Apply authentication to all routes
router.use(authenticateToken);

// Update priority for a task, project, or module
router.put('/:entityType/:entityId/priority', priorityController.updatePriority);

// Get priority change requests for approval (Admin/Project Manager only)
router.get('/change-requests', requireAdminOrProjectManager, priorityController.getPriorityChangeRequests);

// Approve or reject priority change request (Admin/Project Manager only)
router.put('/change-requests/:requestId/review', requireAdminOrProjectManager, priorityController.reviewPriorityChange);

// Get priority statistics for a project
router.get('/projects/:projectId/statistics', priorityController.getPriorityStatistics);

module.exports = router;
