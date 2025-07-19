const express = require('express');
const { PrismaClient } = require('@prisma/client');
const { authenticateToken, requireAdmin } = require('../middleware/auth');
const logger = require('../config/logger');

const router = express.Router();
const prisma = new PrismaClient();

// Get current user profile
router.get('/me', authenticateToken, async (req, res) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      select: {
        id: true,
        email: true,
        name: true,
        shortName: true,
        phone: true,
        telegram: true,
        whatsapp: true,
        profilePicture: true,
        isAdmin: true,
        isActive: true,
        preferences: true,
        lastLoginAt: true,
        createdAt: true
      }
    });

    res.json(user);
  } catch (error) {
    logger.error('Error fetching user profile:', error);
    res.status(500).json({ error: 'Failed to fetch user profile' });
  }
});

// Update user profile
router.put('/me', authenticateToken, async (req, res) => {
  try {
    const { name, shortName, phone, telegram, whatsapp, preferences } = req.body;

    const updateData = {};
    if (name !== undefined) updateData.name = name;
    if (shortName !== undefined) updateData.shortName = shortName;
    if (phone !== undefined) updateData.phone = phone;
    if (telegram !== undefined) updateData.telegram = telegram;
    if (whatsapp !== undefined) updateData.whatsapp = whatsapp;
    if (preferences !== undefined) updateData.preferences = preferences;

    const user = await prisma.user.update({
      where: { id: req.user.id },
      data: updateData,
      select: {
        id: true,
        email: true,
        name: true,
        shortName: true,
        phone: true,
        telegram: true,
        whatsapp: true,
        profilePicture: true,
        isAdmin: true,
        preferences: true
      }
    });

    logger.info(`User profile updated: ${req.user.email}`);
    res.json(user);
  } catch (error) {
    logger.error('Error updating user profile:', error);
    res.status(500).json({ error: 'Failed to update user profile' });
  }
});

// Get all users (admin only)
router.get('/', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const { search, isActive } = req.query;
    
    const where = {};
    
    if (search) {
      where.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { email: { contains: search, mode: 'insensitive' } }
      ];
    }
    
    if (isActive !== undefined) {
      where.isActive = isActive === 'true';
    }

    const users = await prisma.user.findMany({
      where,
      select: {
        id: true,
        email: true,
        name: true,
        isAdmin: true,
        isActive: true,
        lastLoginAt: true,
        createdAt: true
      },
      orderBy: { createdAt: 'desc' }
    });

    res.json(users);
  } catch (error) {
    logger.error('Error fetching users:', error);
    res.status(500).json({ error: 'Failed to fetch users' });
  }
});

module.exports = router;