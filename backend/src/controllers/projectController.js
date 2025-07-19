const { PrismaClient } = require('@prisma/client');
const logger = require('../config/logger');

const prisma = new PrismaClient();

// Create project (admin only)
const createProject = async (req, res) => {
  try {
    const { name, description, priority, startDate, endDate } = req.body;
    
    // Only admins can create projects
    if (!req.user.isAdmin) {
      return res.status(403).json({ error: 'Only administrators can create projects' });
    }

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
        },
        members: {
          include: {
            user: {
              select: { id: true, name: true, email: true }
            }
          }
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
};

// Get all projects
const getProjects = async (req, res) => {
  try {
    const { status, priority, search } = req.query;
    
    const where = {};
    
    // Filter by status
    if (status) {
      where.status = status;
    }
    
    // Filter by priority
    if (priority) {
      where.priority = priority;
    }
    
    // Search by name or description
    if (search) {
      where.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { description: { contains: search, mode: 'insensitive' } }
      ];
    }

    // Non-admin users can only see projects they're members of
    if (!req.user.isAdmin) {
      where.members = {
        some: {
          userId: req.user.id
        }
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
          select: {
            tasks: true,
            subProjects: true
          }
        }
      },
      orderBy: {
        createdAt: 'desc'
      }
    });

    res.json(projects);
  } catch (error) {
    logger.error('Error fetching projects:', error);
    res.status(500).json({ error: 'Failed to fetch projects' });
  }
};

module.exports = {
  createProject,
  getProjects
};
