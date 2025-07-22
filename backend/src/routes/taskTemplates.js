const express = require('express');
const { authenticateToken, requireAdmin } = require('../middleware/auth');
const taskTemplateController = require('../controllers/taskTemplateController');

const router = express.Router();

// Task template routes
router.get('/', authenticateToken, taskTemplateController.getTaskTemplates);
router.post('/', authenticateToken, taskTemplateController.createTaskTemplate);
router.get('/:id', authenticateToken, taskTemplateController.getTaskTemplate);
router.put('/:id', authenticateToken, taskTemplateController.updateTaskTemplate);
router.delete('/:id', authenticateToken, taskTemplateController.deleteTaskTemplate);

// Template usage
router.post('/:id/use', authenticateToken, taskTemplateController.createTaskFromTemplate);

// Project templates
router.get('/projects/:projectId', authenticateToken, taskTemplateController.getProjectTaskTemplates);

// Admin routes
router.get('/admin/global', authenticateToken, requireAdmin, taskTemplateController.getGlobalTaskTemplates);
router.post('/admin/global', authenticateToken, requireAdmin, taskTemplateController.createGlobalTaskTemplate);

module.exports = router;
