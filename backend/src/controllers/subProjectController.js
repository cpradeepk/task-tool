const { PrismaClient } = require('@prisma/client');
const logger = require('../config/logger');

const prisma = new PrismaClient();

// Create sub-project (admin only)
const createSubProject = async (req, res) => {
  try {
    const { name, description, priority, startDate, endDate, projectId } = req.body;
    
    // Only admins can create sub-projects
    if (!req.user.isAdmin) {
      return res.status(403).json({ error: 'Only administrators can create sub-projects' });
    }

    // Verify project exists and user has access
    const project = await prisma.project.findUnique({
      where: { id: projectId }
    });

    if (!project) {
      return res.status(404).json({ error: 'Project not found' });
    }

    const subProject = await prisma.subProject.create({
      data: {
        name,
        description,
        priority: priority || 'NOT_IMPORTANT_NOT_URGENT',
        startDate: startDate ? new Date(startDate) : null,
        endDate: endDate ? new Date(endDate) : null,
        status: 'ACTIVE',
        projectId
      },
      include: {
        project: {
          select: { id: true, name: true }
        },
        _count: {
          select: { tasks: true }
        }
      }
    });

    logger.info(`Sub-project created: ${subProject.name} in project ${project.name} by ${req.user.email}`);
    res.status(201).json(subProject);
  } catch (error) {
    logger.error('Error creating sub-project:', error);
    if (error.code === 'P2002') {
      return res.status(400).json({ error: 'Sub-project name already exists in this project' });
    }
    res.status(500).json({ error: 'Failed to create sub-project' });
  }
};

// Get sub-projects for a project
const getSubProjects = async (req, res) => {
  try {
    const { projectId } = req.params;
    const { status, priority, search } = req.query;
    
    // Check if user has access to the project
    if (!req.user.isAdmin) {
      const membership = await prisma.projectMember.findFirst({
        where: {
          projectId,
          userId: req.user.id
        }
      });

      if (!membership) {
        return res.status(403).json({ error: 'Access denied to this project' });
      }
    }

    const where = { projectId };
    
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

    const subProjects = await prisma.subProject.findMany({
      where,
      include: {
        project: {
          select: { id: true, name: true }
        },
        tasks: {
          include: {
            mainAssignee: {
              select: { id: true, name: true, email: true }
            }
          }
        },
        _count: {
          select: { tasks: true }
        }
      },
      orderBy: {
        createdAt: 'desc'
      }
    });

    res.json(subProjects);
  } catch (error) {
    logger.error('Error fetching sub-projects:', error);
    res.status(500).json({ error: 'Failed to fetch sub-projects' });
  }
};

// Get sub-project by ID
const getSubProjectById = async (req, res) => {
  try {
    const { id } = req.params;
    
    const subProject = await prisma.subProject.findUnique({
      where: { id },
      include: {
        project: {
          select: { id: true, name: true }
        },
        tasks: {
          include: {
            mainAssignee: {
              select: { id: true, name: true, email: true }
            },
            assignments: {
              include: {
                user: {
                  select: { id: true, name: true, email: true }
                }
              }
            }
          }
        },
        _count: {
          select: { tasks: true }
        }
      }
    });

    if (!subProject) {
      return res.status(404).json({ error: 'Sub-project not found' });
    }

    // Check if user has access to this project
    if (!req.user.isAdmin) {
      const membership = await prisma.projectMember.findFirst({
        where: {
          projectId: subProject.projectId,
          userId: req.user.id
        }
      });

      if (!membership) {
        return res.status(403).json({ error: 'Access denied to this sub-project' });
      }
    }

    res.json(subProject);
  } catch (error) {
    logger.error('Error fetching sub-project:', error);
    res.status(500).json({ error: 'Failed to fetch sub-project' });
  }
};

// Update sub-project (admin only)
const updateSubProject = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, description, priority, startDate, endDate, status } = req.body;
    
    // Only admins can update sub-projects
    if (!req.user.isAdmin) {
      return res.status(403).json({ error: 'Only administrators can update sub-projects' });
    }

    const updateData = {};
    if (name !== undefined) updateData.name = name;
    if (description !== undefined) updateData.description = description;
    if (priority !== undefined) updateData.priority = priority;
    if (startDate !== undefined) updateData.startDate = startDate ? new Date(startDate) : null;
    if (endDate !== undefined) updateData.endDate = endDate ? new Date(endDate) : null;
    if (status !== undefined) updateData.status = status;

    const subProject = await prisma.subProject.update({
      where: { id },
      data: updateData,
      include: {
        project: {
          select: { id: true, name: true }
        },
        _count: {
          select: { tasks: true }
        }
      }
    });

    logger.info(`Sub-project updated: ${subProject.name} by ${req.user.email}`);
    res.json(subProject);
  } catch (error) {
    logger.error('Error updating sub-project:', error);
    if (error.code === 'P2002') {
      return res.status(400).json({ error: 'Sub-project name already exists in this project' });
    }
    if (error.code === 'P2025') {
      return res.status(404).json({ error: 'Sub-project not found' });
    }
    res.status(500).json({ error: 'Failed to update sub-project' });
  }
};

// Delete sub-project (admin only)
const deleteSubProject = async (req, res) => {
  try {
    const { id } = req.params;
    
    // Only admins can delete sub-projects
    if (!req.user.isAdmin) {
      return res.status(403).json({ error: 'Only administrators can delete sub-projects' });
    }

    await prisma.subProject.delete({
      where: { id }
    });

    logger.info(`Sub-project deleted: ${id} by ${req.user.email}`);
    res.status(204).send();
  } catch (error) {
    logger.error('Error deleting sub-project:', error);
    if (error.code === 'P2025') {
      return res.status(404).json({ error: 'Sub-project not found' });
    }
    res.status(500).json({ error: 'Failed to delete sub-project' });
  }
};

module.exports = {
  createSubProject,
  getSubProjects,
  getSubProjectById,
  updateSubProject,
  deleteSubProject
};
