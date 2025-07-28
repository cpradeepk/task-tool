const express = require('express');
const router = express.Router();
const projectAssignmentController = require('../controllers/projectAssignmentController');
const { authenticateToken, requireAdminOrProjectManager } = require('../middleware/auth');

// Apply authentication to all routes
router.use(authenticateToken);

// Get all users assigned to a project
router.get('/:projectId/assignments', projectAssignmentController.getProjectAssignments);

// Assign users to a project (Admin/Project Manager only)
router.post('/:projectId/assignments', requireAdminOrProjectManager, projectAssignmentController.assignUsersToProject);

// Remove user from project (Admin/Project Manager only)
router.delete('/:projectId/assignments/:userId', requireAdminOrProjectManager, projectAssignmentController.removeUserFromProject);

// Get assignment history for a project
router.get('/:projectId/assignment-history', projectAssignmentController.getAssignmentHistory);

module.exports = router;
