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
        priority: priority || 'NOT_IMPORTANT_NOT_URGENT',
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
              select: { id: true, name: true, email: true, role: true }
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
    if (error.code === 'P2002') {
      return res.status(400).json({ error: 'Project name already exists' });
    }
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

module.exports = {
  createProject,
  getProjects,
  getProjectById,
  updateProject,
  deleteProject
};
