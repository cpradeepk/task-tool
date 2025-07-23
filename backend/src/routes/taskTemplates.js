const express = require('express');
const { authenticateToken, requireAdmin } = require('../middleware/auth');
const taskTemplateController = require('../controllers/taskTemplateController');

const router = express.Router();

// Task template routes
router.get('/', authenticateToken, taskTemplateController.getTemplates);
router.post('/', authenticateToken, taskTemplateController.createTemplate);
router.get('/:id', authenticateToken, taskTemplateController.getTemplate);
router.put('/:id', authenticateToken, taskTemplateController.updateTemplate);
router.delete('/:id', authenticateToken, taskTemplateController.deleteTemplate);

// Template usage
router.post('/:templateId/use', authenticateToken, taskTemplateController.createTaskFromTemplate);

// Popular and suggested templates
router.get('/popular', authenticateToken, taskTemplateController.getPopularTemplates);
router.post('/suggest', authenticateToken, taskTemplateController.suggestTemplates);

// Recurring tasks
router.post('/recurring', authenticateToken, taskTemplateController.createRecurringTask);
router.get('/recurring', authenticateToken, taskTemplateController.getRecurringTasks);
router.post('/recurring/generate', authenticateToken, requireAdmin, taskTemplateController.generateRecurringTasks);

module.exports = router;
