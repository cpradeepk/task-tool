const express = require('express');
const { body } = require('express-validator');
const authController = require('../controllers/authController');
const { validateRequest } = require('../middleware/validation');

const router = express.Router();

/**
 * @swagger
 * /api/auth/google:
 *   post:
 *     summary: Authenticate user with Google OAuth
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               token:
 *                 type: string
 *                 description: Google ID token
 *     responses:
 *       200:
 *         description: Authentication successful
 *       400:
 *         description: Invalid token
 *       403:
 *         description: Account deactivated
 */
router.post('/google', [
  body('token').notEmpty().withMessage('Google token is required')
], validateRequest, authController.googleLogin);

/**
 * @swagger
 * /api/auth/refresh:
 *   post:
 *     summary: Refresh authentication token
 *     tags: [Authentication]
 */
router.post('/refresh', authController.refreshToken);

module.exports = router;