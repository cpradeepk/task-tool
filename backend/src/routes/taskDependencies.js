const express = require('express');
const { authenticateToken } = require('../middleware/auth');
const taskDependencyController = require('../controllers/taskDependencyController');

const router = express.Router();

// Task dependency routes
router.get('/tasks/:taskId/dependencies', authenticateToken, taskDependencyController.getTaskDependencies);
router.post('/tasks/:taskId/dependencies', authenticateToken, taskDependencyController.addTaskDependency);
router.delete('/tasks/:taskId/dependencies/:dependencyId', authenticateToken, taskDependencyController.removeTaskDependency);

// Dependency validation
router.post('/tasks/:taskId/dependencies/validate', authenticateToken, taskDependencyController.validateDependency);

// Project dependency overview
router.get('/projects/:projectId/dependencies', authenticateToken, taskDependencyController.getProjectDependencies);
router.get('/projects/:projectId/dependency-graph', authenticateToken, taskDependencyController.getDependencyGraph);

module.exports = router;
