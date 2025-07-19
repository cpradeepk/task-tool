const express = require('express');
const { PrismaClient } = require('@prisma/client');
const { authenticateToken, requireAdmin } = require('../middleware/auth');
const logger = require('../config/logger');

const router = express.Router();
const prisma = new PrismaClient();

// Get all projects
router.get('/', authenticateToken, async (req, res) => {
  try {
    const { status, priority, search } = req.query;
    
    const where = {};
    
    if (status) where.status = status;
    if (priority) where.priority = priority;
    
    if (search) {
      where.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { description: { contains: search, mode: 'insensitive' } }
      ];
    }

    // Non-admin users can only see projects they're members of
    if (!req.user.isAdmin) {
      where.members = {
        some: { userId: req.user.id }
      };
    }

    const projects = await prisma.project.findMany({
      where,
      include: {
        createdBy: {
          select: { id: true, name: true, email: true }
        },
        members: {
          include: {
            user: {
              select: { id: true, name: true, email: true }
            }
          }
        },
        _count: {
          select: { tasks: true, subProjects: true }
        }
      },
      orderBy: { createdAt: 'desc' }
    });

    res.json(projects);
  } catch (error) {
    logger.error('Error fetching projects:', error);
    res.status(500).json({ error: 'Failed to fetch projects' });
  }
});

// Create project (admin only)
router.post('/', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const { name, description, priority, startDate, endDate } = req.body;

    const project = await prisma.project.create({
      data: {
        name,
        description,
        priority: priority || 'MEDIUM',
        startDate: startDate ? new Date(startDate) : null,
        endDate: endDate ? new Date(endDate) : null,
        status: 'ACTIVE',
        createdById: req.user.id
      },
      include: {
        createdBy: {
          select: { id: true, name: true, email: true }
        }
      }
    });

    // Add creator as project owner
    await prisma.projectMember.create({
      data: {
        projectId: project.id,
        userId: req.user.id,
        role: 'OWNER'
      }
    });

    logger.info(`Project created: ${project.name} by ${req.user.email}`);
    res.status(201).json(project);
  } catch (error) {
    logger.error('Error creating project:', error);
    res.status(500).json({ error: 'Failed to create project' });
  }
});

module.exports = router;
