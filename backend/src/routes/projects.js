const express = require('express');
const { authenticateToken, requireAdmin } = require('../middleware/auth');
const projectController = require('../controllers/projectController');
const subProjectController = require('../controllers/subProjectController');

const router = express.Router();

// Project routes
router.get('/', authenticateToken, projectController.getProjects);
router.post('/', authenticateToken, requireAdmin, projectController.createProject);
router.get('/:id', authenticateToken, projectController.getProjectById);
router.put('/:id', authenticateToken, requireAdmin, projectController.updateProject);
router.delete('/:id', authenticateToken, requireAdmin, projectController.deleteProject);

// Sub-project routes
router.get('/:projectId/subprojects', authenticateToken, subProjectController.getSubProjects);
router.post('/subprojects', authenticateToken, requireAdmin, subProjectController.createSubProject);
router.get('/subprojects/:id', authenticateToken, subProjectController.getSubProjectById);
router.put('/subprojects/:id', authenticateToken, requireAdmin, subProjectController.updateSubProject);
router.delete('/subprojects/:id', authenticateToken, requireAdmin, subProjectController.deleteSubProject);

module.exports = router;
