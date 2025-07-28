const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

class EnhancedModuleController {
  // Get all modules for a project with enhanced features
  async getProjectModules(req, res) {
    try {
      const { projectId } = req.params;
      
      // Check if user has access to this project
      const hasAccess = await this.checkProjectAccess(req.user.id, projectId);
      if (!hasAccess) {
        return res.status(403).json({ error: 'No access to this project' });
      }

      const modules = await prisma.enhancedModule.findMany({
        where: { projectId },
        include: {
          creator: {
            select: {
              id: true,
              name: true,
              email: true
            }
          },
          parentModule: {
            select: {
              id: true,
              name: true
            }
          },
          childModules: {
            select: {
              id: true,
              name: true,
              status: true,
              completionPercentage: true
            }
          },
          tasks: {
            select: {
              id: true,
              title: true,
              status: true,
              priority: true,
              estimatedHours: true,
              actualHours: true
            }
          },
          _count: {
            select: {
              tasks: true,
              childModules: true
            }
          }
        },
        orderBy: [
          { orderIndex: 'asc' },
          { createdAt: 'asc' }
        ]
      });

      // Calculate completion percentages and statistics
      const modulesWithStats = modules.map(module => {
        const totalTasks = module.tasks.length;
        const completedTasks = module.tasks.filter(task => task.status === 'COMPLETED').length;
        const taskCompletionPercentage = totalTasks > 0 ? Math.round((completedTasks / totalTasks) * 100) : 0;
        
        const totalEstimatedHours = module.tasks.reduce((sum, task) => sum + (task.estimatedHours || 0), 0);
        const totalActualHours = module.tasks.reduce((sum, task) => sum + (task.actualHours || 0), 0);

        return {
          ...module,
          statistics: {
            totalTasks,
            completedTasks,
            taskCompletionPercentage,
            totalEstimatedHours,
            totalActualHours,
            hoursVariance: totalActualHours - totalEstimatedHours
          }
        };
      });

      res.json(modulesWithStats);
    } catch (error) {
      console.error('Get project modules error:', error);
      res.status(500).json({ error: 'Failed to fetch project modules' });
    }
  }

  // Create a new module
  async createModule(req, res) {
    try {
      const { projectId } = req.params;
      const {
        name,
        description,
        parentModuleId,
        orderIndex,
        priority = 'NOT_IMPORTANT_NOT_URGENT',
        priorityNumber = 1,
        startDate,
        endDate,
        estimatedHours
      } = req.body;

      // Check if user can manage this project
      const canManage = await this.checkProjectManageAccess(req.user.id, projectId);
      if (!canManage) {
        return res.status(403).json({ error: 'Insufficient permissions to create modules' });
      }

      // Validate parent module if provided
      if (parentModuleId) {
        const parentModule = await prisma.enhancedModule.findFirst({
          where: {
            id: parentModuleId,
            projectId
          }
        });

        if (!parentModule) {
          return res.status(400).json({ error: 'Invalid parent module' });
        }
      }

      // Get next order index if not provided
      let finalOrderIndex = orderIndex;
      if (finalOrderIndex === undefined) {
        const lastModule = await prisma.enhancedModule.findFirst({
          where: {
            projectId,
            parentModuleId: parentModuleId || null
          },
          orderBy: { orderIndex: 'desc' }
        });
        finalOrderIndex = (lastModule?.orderIndex || 0) + 1;
      }

      const module = await prisma.enhancedModule.create({
        data: {
          name,
          description,
          projectId,
          parentModuleId,
          orderIndex: finalOrderIndex,
          priority,
          priorityNumber,
          startDate: startDate ? new Date(startDate) : null,
          endDate: endDate ? new Date(endDate) : null,
          estimatedHours: estimatedHours ? parseFloat(estimatedHours) : null,
          createdBy: req.user.id
        },
        include: {
          creator: {
            select: {
              id: true,
              name: true,
              email: true
            }
          },
          parentModule: {
            select: {
              id: true,
              name: true
            }
          }
        }
      });

      // Create timeline entry if dates are provided
      if (startDate && endDate) {
        await prisma.projectTimeline.create({
          data: {
            projectId,
            entityType: 'MODULE',
            entityId: module.id,
            startDate: new Date(startDate),
            endDate: new Date(endDate),
            baselineStart: new Date(startDate),
            baselineEnd: new Date(endDate)
          }
        });
      }

      res.status(201).json(module);
    } catch (error) {
      console.error('Create module error:', error);
      res.status(500).json({ error: 'Failed to create module' });
    }
  }

  // Update module
  async updateModule(req, res) {
    try {
      const { moduleId } = req.params;
      const {
        name,
        description,
        status,
        priority,
        priorityNumber,
        startDate,
        endDate,
        estimatedHours,
        actualHours,
        completionPercentage,
        orderIndex
      } = req.body;

      // Get current module to check permissions
      const currentModule = await prisma.enhancedModule.findUnique({
        where: { id: moduleId },
        include: { project: true }
      });

      if (!currentModule) {
        return res.status(404).json({ error: 'Module not found' });
      }

      // Check if user can manage this project
      const canManage = await this.checkProjectManageAccess(req.user.id, currentModule.projectId);
      if (!canManage) {
        return res.status(403).json({ error: 'Insufficient permissions to update module' });
      }

      // Log priority change if priority is being updated
      if (priority && priority !== currentModule.priority) {
        await prisma.priorityChangeLog.create({
          data: {
            entityType: 'MODULE',
            entityId: moduleId,
            oldPriority: currentModule.priority,
            newPriority: priority,
            oldPriorityNumber: currentModule.priorityNumber,
            newPriorityNumber: priorityNumber,
            changedBy: req.user.id,
            status: 'APPROVED' // Auto-approve for managers
          }
        });
      }

      const updatedModule = await prisma.enhancedModule.update({
        where: { id: moduleId },
        data: {
          ...(name && { name }),
          ...(description !== undefined && { description }),
          ...(status && { status }),
          ...(priority && { priority }),
          ...(priorityNumber !== undefined && { priorityNumber }),
          ...(startDate && { startDate: new Date(startDate) }),
          ...(endDate && { endDate: new Date(endDate) }),
          ...(estimatedHours !== undefined && { estimatedHours: parseFloat(estimatedHours) }),
          ...(actualHours !== undefined && { actualHours: parseFloat(actualHours) }),
          ...(completionPercentage !== undefined && { completionPercentage }),
          ...(orderIndex !== undefined && { orderIndex })
        },
        include: {
          creator: {
            select: {
              id: true,
              name: true,
              email: true
            }
          },
          parentModule: {
            select: {
              id: true,
              name: true
            }
          },
          tasks: {
            select: {
              id: true,
              title: true,
              status: true
            }
          }
        }
      });

      res.json(updatedModule);
    } catch (error) {
      console.error('Update module error:', error);
      res.status(500).json({ error: 'Failed to update module' });
    }
  }

  // Delete module
  async deleteModule(req, res) {
    try {
      const { moduleId } = req.params;

      // Get current module to check permissions
      const currentModule = await prisma.enhancedModule.findUnique({
        where: { id: moduleId },
        include: {
          project: true,
          tasks: true,
          childModules: true
        }
      });

      if (!currentModule) {
        return res.status(404).json({ error: 'Module not found' });
      }

      // Check if user can manage this project
      const canManage = await this.checkProjectManageAccess(req.user.id, currentModule.projectId);
      if (!canManage) {
        return res.status(403).json({ error: 'Insufficient permissions to delete module' });
      }

      // Check if module has tasks or child modules
      if (currentModule.tasks.length > 0 || currentModule.childModules.length > 0) {
        return res.status(400).json({ 
          error: 'Cannot delete module with existing tasks or child modules',
          details: {
            taskCount: currentModule.tasks.length,
            childModuleCount: currentModule.childModules.length
          }
        });
      }

      // Delete timeline entries
      await prisma.projectTimeline.deleteMany({
        where: {
          entityType: 'MODULE',
          entityId: moduleId
        }
      });

      // Delete the module
      await prisma.enhancedModule.delete({
        where: { id: moduleId }
      });

      res.json({ message: 'Module successfully deleted' });
    } catch (error) {
      console.error('Delete module error:', error);
      res.status(500).json({ error: 'Failed to delete module' });
    }
  }

  // Helper methods
  async checkProjectAccess(userId, projectId) {
    const assignment = await prisma.userProjectAssignment.findFirst({
      where: {
        userId,
        projectId,
        assignmentStatus: 'ASSIGNED'
      }
    });

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { role: true }
    });

    return assignment || ['ADMIN'].includes(user?.role);
  }

  async checkProjectManageAccess(userId, projectId) {
    const assignment = await prisma.userProjectAssignment.findFirst({
      where: {
        userId,
        projectId,
        assignmentStatus: 'ASSIGNED',
        role: { in: ['OWNER', 'ADMIN'] }
      }
    });

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { role: true }
    });

    return assignment || ['ADMIN', 'PROJECT_MANAGER'].includes(user?.role);
  }
}

module.exports = new EnhancedModuleController();
