const { PrismaClient } = require('@prisma/client');
const logger = require('../config/logger');
const activityService = require('../services/activityService');
const notificationService = require('../services/notificationService');

const prisma = new PrismaClient();

// Create project (admin only)
const createProject = async (req, res) => {
  try {
    const { 
      name, 
      description, 
      projectType = 'SOFTWARE_DEVELOPMENT',
      priority = 'NOT_IMPORTANT_NOT_URGENT', 
      priorityOrder,
      startDate, 
      endDate,
      hasTimeDependencies = false,
      managerId
    } = req.body;

    // Only admins can create projects
    if (!req.user.isAdmin) {
      return res.status(403).json({ error: 'Only administrators can create projects' });
    }

    // Validate manager if provided
    if (managerId) {
      const manager = await prisma.user.findUnique({
        where: { id: managerId },
        select: { role: true }
      });

      if (!manager || !['ADMIN', 'PROJECT_MANAGER'].includes(manager.role)) {
        return res.status(400).json({ error: 'Invalid project manager specified' });
      }
    }

    // Validate time dependencies
    if (hasTimeDependencies && !startDate) {
      return res.status(400).json({ error: 'Start date is required for time-dependent projects' });
    }

    const project = await prisma.project.create({
      data: {
        name,
        description,
        projectType,
        priority,
        priorityOrder,
        startDate: startDate ? new Date(startDate) : null,
        endDate: endDate ? new Date(endDate) : null,
        hasTimeDependencies,
        status: 'ACTIVE',
        createdById: req.user.id,
        managerId
      },
      include: {
        createdBy: {
          select: { id: true, name: true, email: true }
        },
        manager: {
          select: { id: true, name: true, email: true, role: true }
        },
        members: {
          include: {
            user: {
              select: { id: true, name: true, email: true, role: true }
            }
          }
        }
      }
    });

    // Auto-add manager as project member if specified
    if (managerId && managerId !== req.user.id) {
      await prisma.projectMember.create({
        data: {
          projectId: project.id,
          userId: managerId,
          role: 'ADMIN'
        }
      });
    }

    logger.info(`Project created: ${name} by ${req.user.email}`);
    res.status(201).json(project);
  } catch (error) {
    if (error.code === 'P2002') {
      return res.status(400).json({ error: 'Project name already exists' });
    }
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

// Get project by ID
const getProjectById = async (req, res) => {
  try {
    const { id } = req.params;

    const project = await prisma.project.findUnique({
      where: { id },
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
        subProjects: {
          include: {
            _count: {
              select: { tasks: true }
            }
          }
        },
        tasks: {
          include: {
            mainAssignee: {
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
      }
    });

    if (!project) {
      return res.status(404).json({ error: 'Project not found' });
    }

    // Check if user has access to this project
    if (!req.user.isAdmin) {
      const membership = await prisma.projectMember.findFirst({
        where: {
          projectId: id,
          userId: req.user.id
        }
      });

      if (!membership) {
        return res.status(403).json({ error: 'Access denied to this project' });
      }
    }

    res.json(project);
  } catch (error) {
    logger.error('Error fetching project:', error);
    res.status(500).json({ error: 'Failed to fetch project' });
  }
};

// Update project (admin only)
const updateProject = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, description, priority, startDate, endDate, status } = req.body;

    // Only admins can update projects
    if (!req.user.isAdmin) {
      return res.status(403).json({ error: 'Only administrators can update projects' });
    }

    const updateData = {};
    if (name !== undefined) updateData.name = name;
    if (description !== undefined) updateData.description = description;
    if (priority !== undefined) updateData.priority = priority;
    if (startDate !== undefined) updateData.startDate = startDate ? new Date(startDate) : null;
    if (endDate !== undefined) updateData.endDate = endDate ? new Date(endDate) : null;
    if (status !== undefined) updateData.status = status;

    const project = await prisma.project.update({
      where: { id },
      data: updateData,
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

    logger.info(`Project updated: ${project.name} by ${req.user.email}`);
    res.json(project);
  } catch (error) {
    logger.error('Error updating project:', error);
    if (error.code === 'P2002') {
      return res.status(400).json({ error: 'Project name already exists' });
    }
    if (error.code === 'P2025') {
      return res.status(404).json({ error: 'Project not found' });
    }
    res.status(500).json({ error: 'Failed to update project' });
  }
};

// Delete project (admin only)
const deleteProject = async (req, res) => {
  try {
    const { id } = req.params;

    // Only admins can delete projects
    if (!req.user.isAdmin) {
      return res.status(403).json({ error: 'Only administrators can delete projects' });
    }

    await prisma.project.delete({
      where: { id }
    });

    logger.info(`Project deleted: ${id} by ${req.user.email}`);
    res.status(204).send();
  } catch (error) {
    logger.error('Error deleting project:', error);
    if (error.code === 'P2025') {
      return res.status(404).json({ error: 'Project not found' });
    }
    res.status(500).json({ error: 'Failed to delete project' });
  }
};

// Add new method for project manager assignment
const assignProjectManager = async (req, res) => {
  try {
    const { id } = req.params;
    const { managerId } = req.body;

    // Only admins can assign project managers
    if (!req.user.isAdmin) {
      return res.status(403).json({ error: 'Only administrators can assign project managers' });
    }

    // Validate manager
    if (managerId) {
      const manager = await prisma.user.findUnique({
        where: { id: managerId },
        select: { role: true, name: true, email: true }
      });

      if (!manager || !['ADMIN', 'PROJECT_MANAGER'].includes(manager.role)) {
        return res.status(400).json({ error: 'User must have PROJECT_MANAGER or ADMIN role' });
      }
    }

    const project = await prisma.project.update({
      where: { id },
      data: { managerId },
      include: {
        manager: {
          select: { id: true, name: true, email: true, role: true }
        }
      }
    });

    // Ensure manager is project member
    if (managerId) {
      await prisma.projectMember.upsert({
        where: {
          projectId_userId: {
            projectId: id,
            userId: managerId
          }
        },
        update: { role: 'ADMIN' },
        create: {
          projectId: id,
          userId: managerId,
          role: 'ADMIN'
        }
      });
    }

    logger.info(`Project manager assigned: ${id} -> ${managerId} by ${req.user.email}`);
    res.json(project);
  } catch (error) {
    logger.error('Error assigning project manager:', error);
    res.status(500).json({ error: 'Failed to assign project manager' });
  }
};

module.exports = {
  createProject,
  getProjects,
  getProjectById,
  updateProject,
  deleteProject,
  assignProjectManager
};
