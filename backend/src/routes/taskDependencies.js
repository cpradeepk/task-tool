const express = require('express');
const { authenticateToken } = require('../middleware/auth');
const taskDependencyController = require('../controllers/taskDependencyController');

const router = express.Router();

// Critical path and dependency chain
router.get('/projects/:projectId/critical-path', authenticateToken, taskDependencyController.getCriticalPath);
router.get('/tasks/:taskId/dependency-chain', authenticateToken, taskDependencyController.getDependencyChain);

// Task availability and blocking
router.get('/projects/:projectId/available-tasks', authenticateToken, taskDependencyController.getAvailableTasks);
router.get('/projects/:projectId/blocked-tasks', authenticateToken, taskDependencyController.getBlockedTasks);

// Dependency statistics and validation
router.get('/projects/:projectId/dependency-stats', authenticateToken, taskDependencyController.getDependencyStats);
router.post('/validate', authenticateToken, taskDependencyController.validateDependency);

// Dependency graph and suggestions
router.get('/projects/:projectId/dependency-graph', authenticateToken, taskDependencyController.getDependencyGraph);
router.get('/tasks/:taskId/suggest', authenticateToken, taskDependencyController.suggestDependencies);

module.exports = router;
