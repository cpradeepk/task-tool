const express = require('express');
const router = express.Router();
const enhancedModuleController = require('../controllers/enhancedModuleController');
const { authenticateToken, requireAdminOrProjectManager } = require('../middleware/auth');

// Apply authentication to all routes
router.use(authenticateToken);

// Get all modules for a project
router.get('/:projectId/modules', enhancedModuleController.getProjectModules);

// Create a new module (Admin/Project Manager only)
router.post('/:projectId/modules', requireAdminOrProjectManager, enhancedModuleController.createModule);

// Update module (Admin/Project Manager only)
router.put('/modules/:moduleId', requireAdminOrProjectManager, enhancedModuleController.updateModule);

// Delete module (Admin/Project Manager only)
router.delete('/modules/:moduleId', requireAdminOrProjectManager, enhancedModuleController.deleteModule);

// Reorder modules (Admin/Project Manager only)
router.put('/:projectId/modules/reorder', requireAdminOrProjectManager, enhancedModuleController.reorderModules);

module.exports = router;
