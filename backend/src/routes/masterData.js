const express = require('express');
const router = express.Router();
const { authenticateToken, requireAdmin } = require('../middleware/auth');
const masterDataController = require('../controllers/masterDataController');

// Get master data by type
router.get('/type/:type', authenticateToken, masterDataController.getMasterDataByType);

// Get all master data
router.get('/', authenticateToken, masterDataController.getAllMasterData);

// Create master data (admin only)
router.post('/', authenticateToken, requireAdmin, masterDataController.createMasterData);

// Update master data (admin only)
router.put('/:id', authenticateToken, requireAdmin, masterDataController.updateMasterData);

// Delete master data (admin only)
router.delete('/:id', authenticateToken, requireAdmin, masterDataController.deleteMasterData);

// Reorder master data (admin only)
router.put('/type/:type/reorder', authenticateToken, requireAdmin, masterDataController.reorderMasterData);

module.exports = router;