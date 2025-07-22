const { PrismaClient } = require('@prisma/client');
const logger = require('../config/logger');

const prisma = new PrismaClient();

class ModuleController {
  // Get modules for a project
  async getProjectModules(req, res) {
    try {
      const { projectId } = req.params;
      const { status, includeTaskCount } = req.query;

      // Verify project access
      const hasAccess = await this.verifyProjectAccess(projectId, req.user.id);
      if (!hasAccess) {
        return res.status(403).json({ error: 'Access denied to this project' });
      }

      const where = { projectId };
      if (status) {
        where.status = status;
      }

      const modules = await prisma.module.findMany({
        where,
        include: {
          createdBy: {
            select: { id: true, name: true, email: true }
          },
          ...(includeTaskCount === 'true' && {
            _count: {
              select: { tasks: true }
            }
          })
        },
        orderBy: [
          { priority: 'asc' },
          { priorityOrder: 'asc' },
          { createdAt: 'asc' }
        ]
      });

      res.json(modules);
    } catch (error) {
      logger.error('Error fetching project modules:', error);
      res.status(500).json({ error: 'Failed to fetch modules' });
    }
  }

  // Create module
  async createModule(req, res) {
    try {
      const {
        name,
        description,
        projectId,
        priority = 'NOT_IMPORTANT_NOT_URGENT',
        priorityOrder,
        startDate,
        endDate,
        hasTimeDependencies = false
      } = req.body;

      // Verify project access and permissions
      const hasAccess = await this.verifyProjectManageAccess(projectId, req.user.id);
      if (!hasAccess) {
        return res.status(403).json({ error: 'Insufficient permissions to create modules in this project' });
      }

      // Validate time dependencies
      if (hasTimeDependencies && !startDate) {
        return res.status(400).json({ error: 'Start date is required for time-dependent modules' });
      }

      const module = await prisma.module.create({
        data: {
          name,
          description,
          projectId,
          priority,
          priorityOrder,
          startDate: startDate ? new Date(startDate) : null,
          endDate: endDate ? new Date(endDate) : null,
          hasTimeDependencies,
          createdById: req.user.id
        },
        include: {
          createdBy: {
            select: { id: true, name: true, email: true }
          },
          project: {
            select: { id: true, name: true }
          }
        }
      });

      logger.info(`Module created: ${name} in project ${projectId} by ${req.user.email}`);
      res.status(201).json(module);
    } catch (error) {
      if (error.code === 'P2002') {
        return res.status(400).json({ error: 'Module name already exists in this project' });
      }
      logger.error('Error creating module:', error);
      res.status(500).json({ error: 'Failed to create module' });
    }
  }

  // Update module
  async updateModule(req, res) {
    try {
      const { id } = req.params;
      const {
        name,
        description,
        status,
        priority,
        priorityOrder,
        startDate,
        endDate,
        hasTimeDependencies
      } = req.body;

      // Get module and verify access
      const module = await prisma.module.findUnique({
        where: { id },
        include: { project: true }
      });

      if (!module) {
        return res.status(404).json({ error: 'Module not found' });
      }

      const hasAccess = await this.verifyProjectManageAccess(module.projectId, req.user.id);
      if (!hasAccess) {
        return res.status(403).json({ error: 'Insufficient permissions to update this module' });
      }

      // Validate time dependencies
      if (hasTimeDependencies && !startDate && !module.startDate) {
        return res.status(400).json({ error: 'Start date is required for time-dependent modules' });
      }

      const updatedModule = await prisma.module.update({
        where: { id },
        data: {
          name,
          description,
          status,
          priority,
          priorityOrder,
          startDate: startDate ? new Date(startDate) : undefined,
          endDate: endDate ? new Date(endDate) : undefined,
          hasTimeDependencies
        },
        include: {
          createdBy: {
            select: { id: true, name: true, email: true }
          },
          project: {
            select: { id: true, name: true }
          }
        }
      });

      logger.info(`Module updated: ${id} by ${req.user.email}`);
      res.json(updatedModule);
    } catch (error) {
      logger.error('Error updating module:', error);
      res.status(500).json({ error: 'Failed to update module' });
    }
  }

  // Delete module
  async deleteModule(req, res) {
    try {
      const { id } = req.params;

      // Get module and verify access
      const module = await prisma.module.findUnique({
        where: { id },
        include: {
          _count: { select: { tasks: true } }
        }
      });

      if (!module) {
        return res.status(404).json({ error: 'Module not found' });
      }

      const hasAccess = await this.verifyProjectManageAccess(module.projectId, req.user.id);
      if (!hasAccess) {
        return res.status(403).json({ error: 'Insufficient permissions to delete this module' });
      }

      // Check if module has tasks
      if (module._count.tasks > 0) {
        return res.status(400).json({ 
          error: 'Cannot delete module with existing tasks',
          suggestion: 'Move or delete all tasks before deleting the module'
        });
      }

      await prisma.module.delete({
        where: { id }
      });

      logger.info(`Module deleted: ${id} by ${req.user.email}`);
      res.json({ message: 'Module deleted successfully' });
    } catch (error) {
      logger.error('Error deleting module:', error);
      res.status(500).json({ error: 'Failed to delete module' });
    }
  }

  // Get module details with tasks
  async getModuleDetails(req, res) {
    try {
      const { id } = req.params;

      const module = await prisma.module.findUnique({
        where: { id },
        include: {
          createdBy: {
            select: { id: true, name: true, email: true }
          },
          project: {
            select: { id: true, name: true }
          },
          tasks: {
            include: {
              mainAssignee: {
                select: { id: true, name: true, email: true }
              },
              _count: {
                select: { assignments: true, comments: true }
              }
            },
            orderBy: [
              { priority: 'asc' },
              { priorityOrder: 'asc' },
              { createdAt: 'asc' }
            ]
          }
        }
      });

      if (!module) {
        return res.status(404).json({ error: 'Module not found' });
      }

      // Verify project access
      const hasAccess = await this.verifyProjectAccess(module.projectId, req.user.id);
      if (!hasAccess) {
        return res.status(403).json({ error: 'Access denied to this module' });
      }

      res.json(module);
    } catch (error) {
      logger.error('Error fetching module details:', error);
      res.status(500).json({ error: 'Failed to fetch module details' });
    }
  }

  // Helper methods
  async verifyProjectAccess(projectId, userId) {
    const membership = await prisma.projectMember.findFirst({
      where: { projectId, userId }
    });
    return !!membership;
  }

  async verifyProjectManageAccess(projectId, userId) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { role: true }
    });

    if (user.role === 'ADMIN') return true;

    const project = await prisma.project.findUnique({
      where: { id: projectId },
      select: { managerId: true, createdById: true }
    });

    if (project.managerId === userId || project.createdById === userId) return true;

    if (user.role === 'PROJECT_MANAGER') {
      const membership = await prisma.projectMember.findFirst({
        where: { 
          projectId, 
          userId,
          role: { in: ['OWNER', 'ADMIN'] }
        }
      });
      return !!membership;
    }

    return false;
  }
}

module.exports = new ModuleController();