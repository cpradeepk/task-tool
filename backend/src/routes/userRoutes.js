const express = require('express');
const { body } = require('express-validator');
const userController = require('../controllers/userController');
const { requireAdmin } = require('../middleware/auth');
const { validateRequest } = require('../middleware/validation');

const router = express.Router();

/**
 * @swagger
 * /api/users/profile:
 *   get:
 *     summary: Get current user profile
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 */
router.get('/profile', userController.getProfile);

/**
 * @swagger
 * /api/users/profile:
 *   put:
 *     summary: Update current user profile
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 */
router.put('/profile', [
  body('name').optional().isLength({ min: 1 }).withMessage('Name cannot be empty'),
  body('shortName').optional().isLength({ max: 10 }).withMessage('Short name must be 10 characters or less'),
  body('phone').optional().isMobilePhone().withMessage('Invalid phone number'),
  body('primaryColor').optional().isHexColor().withMessage('Invalid color format'),
  body('fontFamily').optional().isLength({ min: 1 }).withMessage('Font family cannot be empty')
], validateRequest, userController.updateProfile);

/**
 * @swagger
 * /api/users:
 *   get:
 *     summary: Get all users (Admin only)
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 */
router.get('/', requireAdmin, userController.getAllUsers);

/**
 * @swagger
 * /api/users/{id}/toggle-status:
 *   patch:
 *     summary: Toggle user active status (Admin only)
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 */
router.patch('/:id/toggle-status', requireAdmin, userController.toggleUserStatus);

module.exports = router;