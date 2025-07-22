const express = require('express');
const router = express.Router();
const { authenticateToken, requireAdmin } = require('../middleware/auth');
const userRoleController = require('../controllers/userRoleController');

// Get all users with roles (admin only)
router.get('/', authenticateToken, requireAdmin, userRoleController.getAllUsersWithRoles);

// Update user role (admin only)
router.put('/:userId/role', authenticateToken, requireAdmin, userRoleController.updateUserRole);

// Bulk update roles (admin only)
router.put('/bulk-update', authenticateToken, requireAdmin, userRoleController.bulkUpdateRoles);

module.exports = router;