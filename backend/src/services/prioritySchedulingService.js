const { PrismaClient } = require('@prisma/client');
const logger = require('../config/logger');

const prisma = new PrismaClient();

class PrioritySchedulingService {
  // Validate time dependencies for projects
  async validateProjectTimeDependencies(projectId, startDate, endDate) {
    try {
      const conflicts = [];

      // Check module conflicts
      const modules = await prisma.module.findMany({
        where: { 
          projectId,
          hasTimeDependencies: true,
          startDate: { not: null }
        }
      });

      for (const module of modules) {
        if (startDate && module.startDate < new Date(startDate)) {
          conflicts.push({
            type: 'MODULE',
            id: module.id,
            name: module.name,
            issue: 'Module start date is before project start date'
          });
        }
      }

      return conflicts;
    } catch (error) {
      logger.error('Error validating project time dependencies:', error);
      throw error;
    }
  }

  // Validate task time dependencies
  async validateTaskTimeDependencies(taskId, startDate, moduleId, projectId) {
    try {
      const conflicts = [];

      // Check module constraints
      if (moduleId) {
        const module = await prisma.module.findUnique({
          where: { id: moduleId }
        });

        if (module && module.hasTimeDependencies && module.startDate) {
          if (startDate && new Date(startDate) < module.startDate) {
            conflicts.push({
              type: 'MODULE',
              id: module.id,
              name: module.name,
              issue: 'Task start date is before module start date'
            });
          }
        }
      }

      // Check project constraints
      const project = await prisma.project.findUnique({
        where: { id: projectId }
      });

      if (project && project.hasTimeDependencies && project.startDate) {
        if (startDate && new Date(startDate) < project.startDate) {
          conflicts.push({
            type: 'PROJECT',
            id: project.id,
            name: project.name,
            issue: 'Task start date is before project start date'
          });
        }
      }

      // Check task dependencies
      const dependencies = await prisma.taskDependency.findMany({
        where: { postTaskId: taskId },
        include: {
          preTask: {
            select: { id: true, title: true, endDate: true, status: true }
          }
        }
      });

      for (const dep of dependencies) {
        if (dep.preTask.status !== 'COMPLETED' && dep.preTask.endDate) {
          if (startDate && new Date(startDate) < dep.preTask.endDate) {
            conflicts.push({
              type: 'TASK_DEPENDENCY',
              id: dep.preTask.id,
              name: dep.preTask.title,
              issue: 'Task start date conflicts with dependency end date'
            });
          }
        }
      }

      return conflicts;
    } catch (error) {
      logger.error('Error validating task time dependencies:', error);
      throw error;
    }
  }

  // Get priority-ordered tasks for a project
  async getPriorityOrderedTasks(projectId, filters = {}) {
    try {
      const where = { projectId };

      if (filters.status) {
        where.status = filters.status;
      }

      if (filters.moduleId) {
        where.moduleId = filters.moduleId;
      }

      if (filters.assigneeId) {
        where.OR = [
          { mainAssigneeId: filters.assigneeId },
          { assignments: { some: { userId: filters.assigneeId } } }
        ];
      }

      const tasks = await prisma.task.findMany({
        where,
        include: {
          mainAssignee: {
            select: { id: true, name: true, email: true }
          },
          module: {
            select: { id: true, name: true }
          }
        },
        orderBy: [
          { priority: 'asc' },
          { priorityOrder: 'asc' },
          { dueDate: 'asc' },
          { createdAt: 'asc' }
        ]
      });

      // Group by priority quadrants
      const grouped = {
        IMPORTANT_URGENT: [],
        IMPORTANT_NOT_URGENT: [],
        NOT_IMPORTANT_URGENT: [],
        NOT_IMPORTANT_NOT_URGENT: []
      };

      tasks.forEach(task => {
        grouped[task.priority].push(task);
      });

      return grouped;
    } catch (error) {
      logger.error('Error getting priority-ordered tasks:', error);
      throw error;
    }
  }

  // Auto-assign priority order within quadrant
  async autoAssignPriorityOrder(entityType, entityId, priority) {
    try {
      let maxOrder = 0;

      switch (entityType) {
        case 'PROJECT':
          const projectMax = await prisma.project.findFirst({
            where: { priority },
            orderBy: { priorityOrder: 'desc' },
            select: { priorityOrder: true }
          });
          maxOrder = projectMax?.priorityOrder || 0;
          break;

        case 'MODULE':
          const moduleMax = await prisma.module.findFirst({
            where: { priority },
            orderBy: { priorityOrder: 'desc' },
            select: { priorityOrder: true }
          });
          maxOrder = moduleMax?.priorityOrder || 0;
          break;

        case 'TASK':
          const taskMax = await prisma.task.findFirst({
            where: { priority },
            orderBy: { priorityOrder: 'desc' },
            select: { priorityOrder: true }
          });
          maxOrder = taskMax?.priorityOrder || 0;
          break;
      }

      return maxOrder + 1;
    } catch (error) {
      logger.error('Error auto-assigning priority order:', error);
      return 1;
    }
  }
}

module.exports = new PrioritySchedulingService();