const express = require('express');
const { authenticateToken, requireAdmin } = require('../middleware/auth');
const taskController = require('../controllers/taskController');
const taskDependencyController = require('../controllers/taskDependencyController');
const timeTrackingController = require('../controllers/timeTrackingController');
const taskTemplateController = require('../controllers/taskTemplateController');

const router = express.Router();

// Task CRUD routes
router.get('/', authenticateToken, taskController.getTasks);
router.post('/', authenticateToken, taskController.createTask);
router.get('/:id', authenticateToken, taskController.getTask);
router.put('/:id', authenticateToken, taskController.updateTask);
router.delete('/:id', authenticateToken, taskController.deleteTask);

// Task dependency routes
router.post('/:id/dependencies', authenticateToken, taskController.addTaskDependency);
router.delete('/:id/dependencies/:dependencyId', authenticateToken, taskController.removeTaskDependency);

// Advanced dependency routes
router.get('/projects/:projectId/critical-path', authenticateToken, taskDependencyController.getCriticalPath);
router.get('/:taskId/dependency-chain', authenticateToken, taskDependencyController.getDependencyChain);
router.get('/projects/:projectId/available-tasks', authenticateToken, taskDependencyController.getAvailableTasks);
router.get('/projects/:projectId/blocked-tasks', authenticateToken, taskDependencyController.getBlockedTasks);
router.get('/projects/:projectId/dependency-stats', authenticateToken, taskDependencyController.getDependencyStats);
router.get('/projects/:projectId/dependency-graph', authenticateToken, taskDependencyController.getDependencyGraph);
router.post('/validate-dependency', authenticateToken, taskDependencyController.validateDependency);
router.get('/:taskId/suggest-dependencies', authenticateToken, taskDependencyController.suggestDependencies);

// Task comment routes
router.post('/:id/comments', authenticateToken, taskController.addComment);

// Task time tracking routes
router.post('/:id/time-entries', authenticateToken, taskController.addTimeEntry);
router.get('/:taskId/time-entries', authenticateToken, timeTrackingController.getTaskTimeEntries);

// Advanced time tracking routes
router.post('/timer/start', authenticateToken, timeTrackingController.startTimer);
router.post('/timer/stop', authenticateToken, timeTrackingController.stopTimer);
router.get('/timer/active', authenticateToken, timeTrackingController.getActiveTimer);
router.get('/time-report/user', authenticateToken, timeTrackingController.getUserTimeReport);
router.get('/time-report/recent', authenticateToken, timeTrackingController.getRecentTimeEntries);
router.get('/projects/:projectId/time-report', authenticateToken, timeTrackingController.getProjectTimeReport);
router.get('/projects/:projectId/pert-comparison', authenticateToken, timeTrackingController.getPERTComparison);
router.get('/projects/:projectId/time-analytics', authenticateToken, timeTrackingController.getTimeAnalytics);
router.put('/time-entries/:id', authenticateToken, timeTrackingController.updateTimeEntry);
router.delete('/time-entries/:id', authenticateToken, timeTrackingController.deleteTimeEntry);

// Task template routes
router.get('/templates', authenticateToken, taskTemplateController.getTemplates);
router.post('/templates', authenticateToken, taskTemplateController.createTemplate);
router.get('/templates/popular', authenticateToken, taskTemplateController.getPopularTemplates);
router.post('/templates/suggest', authenticateToken, taskTemplateController.suggestTemplates);
router.get('/templates/:id', authenticateToken, taskTemplateController.getTemplate);
router.put('/templates/:id', authenticateToken, taskTemplateController.updateTemplate);
router.delete('/templates/:id', authenticateToken, taskTemplateController.deleteTemplate);
router.post('/templates/:templateId/create-task', authenticateToken, taskTemplateController.createTaskFromTemplate);

// Recurring task routes
router.get('/recurring', authenticateToken, taskTemplateController.getRecurringTasks);
router.post('/recurring', authenticateToken, taskTemplateController.createRecurringTask);
router.post('/recurring/generate', authenticateToken, requireAdmin, taskTemplateController.generateRecurringTasks);

module.exports = router;
