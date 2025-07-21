const { PrismaClient } = require('@prisma/client');
const logger = require('../config/logger');

const prisma = new PrismaClient();

class TaskTemplateService {
  // Create task from template
  async createTaskFromTemplate(templateId, userId, overrides = {}) {
    try {
      const template = await prisma.taskTemplate.findUnique({
        where: { id: templateId },
        include: {
          project: true
        }
      });

      if (!template) {
        throw new Error('Template not found');
      }

      // Check if user has access to the template
      if (!template.isPublic && template.createdById !== userId) {
        // Check if user is member of the project
        if (template.projectId) {
          const membership = await prisma.projectMember.findFirst({
            where: {
              projectId: template.projectId,
              userId
            }
          });

          if (!membership) {
            throw new Error('Access denied to this template');
          }
        } else {
          throw new Error('Access denied to this template');
        }
      }

      // Calculate PERT estimate
      const estimatedHours = template.optimisticHours && template.pessimisticHours && template.mostLikelyHours
        ? (template.optimisticHours + 4 * template.mostLikelyHours + template.pessimisticHours) / 6
        : null;

      // Create task from template
      const taskData = {
        title: overrides.title || template.name,
        description: overrides.description || template.description,
        taskType: overrides.taskType || template.taskType,
        priority: overrides.priority || template.priority,
        optimisticHours: template.optimisticHours,
        pessimisticHours: template.pessimisticHours,
        mostLikelyHours: template.mostLikelyHours,
        estimatedHours,
        tags: [...template.tags, ...(overrides.tags || [])],
        milestones: [...template.milestones, ...(overrides.milestones || [])],
        customLabels: [...template.customLabels, ...(overrides.customLabels || [])],
        createdById: userId,
        projectId: overrides.projectId || template.projectId,
        subProjectId: overrides.subProjectId,
        mainAssigneeId: overrides.mainAssigneeId,
        dueDate: overrides.dueDate ? new Date(overrides.dueDate) : null,
        plannedEndDate: overrides.plannedEndDate ? new Date(overrides.plannedEndDate) : null
      };

      const task = await prisma.task.create({
        data: taskData,
        include: {
          project: { select: { id: true, name: true } },
          subProject: { select: { id: true, name: true } },
          mainAssignee: { select: { id: true, name: true, email: true } },
          createdBy: { select: { id: true, name: true, email: true } }
        }
      });

      // Update template usage count
      await prisma.taskTemplate.update({
        where: { id: templateId },
        data: { usageCount: { increment: 1 } }
      });

      logger.info(`Task created from template ${templateId} by user ${userId}`);
      return task;
    } catch (error) {
      logger.error('Error creating task from template:', error);
      throw error;
    }
  }

  // Get popular templates
  async getPopularTemplates(projectId = null, limit = 10) {
    try {
      const where = {
        OR: [
          { isPublic: true },
          ...(projectId ? [{ projectId }] : [])
        ]
      };

      const templates = await prisma.taskTemplate.findMany({
        where,
        include: {
          createdBy: { select: { id: true, name: true } },
          project: { select: { id: true, name: true } }
        },
        orderBy: { usageCount: 'desc' },
        take: limit
      });

      return templates;
    } catch (error) {
      logger.error('Error getting popular templates:', error);
      throw error;
    }
  }

  // Suggest templates based on task data
  async suggestTemplates(taskData, userId) {
    try {
      const suggestions = await prisma.taskTemplate.findMany({
        where: {
          OR: [
            { isPublic: true },
            { createdById: userId },
            ...(taskData.projectId ? [{ projectId: taskData.projectId }] : [])
          ],
          AND: [
            ...(taskData.taskType ? [{ taskType: taskData.taskType }] : []),
            ...(taskData.priority ? [{ priority: taskData.priority }] : [])
          ]
        },
        include: {
          createdBy: { select: { id: true, name: true } },
          project: { select: { id: true, name: true } }
        },
        orderBy: { usageCount: 'desc' },
        take: 5
      });

      // Score suggestions based on similarity
      const scoredSuggestions = suggestions.map(template => {
        let score = 0;
        let reasons = [];

        // Same task type
        if (template.taskType === taskData.taskType) {
          score += 3;
          reasons.push('Same task type');
        }

        // Same priority
        if (template.priority === taskData.priority) {
          score += 2;
          reasons.push('Same priority');
        }

        // Same project
        if (template.projectId === taskData.projectId) {
          score += 2;
          reasons.push('Same project');
        }

        // High usage count
        if (template.usageCount > 10) {
          score += 1;
          reasons.push('Popular template');
        }

        // Tag similarity
        if (taskData.tags && template.tags) {
          const commonTags = taskData.tags.filter(tag => template.tags.includes(tag));
          if (commonTags.length > 0) {
            score += commonTags.length;
            reasons.push(`${commonTags.length} common tags`);
          }
        }

        return {
          ...template,
          score,
          reasons: reasons.join(', ')
        };
      });

      return scoredSuggestions.sort((a, b) => b.score - a.score);
    } catch (error) {
      logger.error('Error suggesting templates:', error);
      throw error;
    }
  }

  // Generate recurring tasks
  async generateRecurringTasks() {
    try {
      const now = new Date();
      
      // Get all active recurring tasks that are due
      const recurringTasks = await prisma.recurringTask.findMany({
        where: {
          isActive: true,
          OR: [
            { nextDue: { lte: now } },
            { nextDue: null }
          ]
        }
      });

      const generatedTasks = [];

      for (const recurringTask of recurringTasks) {
        try {
          // Calculate next due date if not set
          let nextDue = recurringTask.nextDue || this.calculateNextDueDate(recurringTask, now);

          // Check if we should generate a task
          if (nextDue <= now) {
            // Calculate PERT estimate
            const estimatedHours = recurringTask.optimisticHours && recurringTask.pessimisticHours && recurringTask.mostLikelyHours
              ? (recurringTask.optimisticHours + 4 * recurringTask.mostLikelyHours + recurringTask.pessimisticHours) / 6
              : null;

            // Create the task
            const task = await prisma.task.create({
              data: {
                title: recurringTask.name,
                description: recurringTask.description,
                taskType: recurringTask.taskType,
                priority: recurringTask.priority,
                optimisticHours: recurringTask.optimisticHours,
                pessimisticHours: recurringTask.pessimisticHours,
                mostLikelyHours: recurringTask.mostLikelyHours,
                estimatedHours,
                tags: recurringTask.tags,
                milestones: recurringTask.milestones,
                customLabels: recurringTask.customLabels,
                projectId: recurringTask.projectId,
                subProjectId: recurringTask.subProjectId,
                mainAssigneeId: recurringTask.mainAssigneeId,
                createdById: recurringTask.createdById,
                recurringTaskId: recurringTask.id,
                dueDate: this.calculateTaskDueDate(recurringTask, nextDue)
              }
            });

            generatedTasks.push(task);

            // Calculate next due date
            const newNextDue = this.calculateNextDueDate(recurringTask, nextDue);

            // Update recurring task
            await prisma.recurringTask.update({
              where: { id: recurringTask.id },
              data: {
                lastGenerated: now,
                nextDue: newNextDue,
                // Deactivate if past end date
                isActive: recurringTask.recurrenceEndDate ? newNextDue <= recurringTask.recurrenceEndDate : true
              }
            });

            logger.info(`Generated recurring task: ${task.title} from recurring task ${recurringTask.id}`);
          }
        } catch (error) {
          logger.error(`Error generating task for recurring task ${recurringTask.id}:`, error);
        }
      }

      return generatedTasks;
    } catch (error) {
      logger.error('Error generating recurring tasks:', error);
      throw error;
    }
  }

  // Calculate next due date for recurring task
  calculateNextDueDate(recurringTask, fromDate) {
    const date = new Date(fromDate);
    const interval = recurringTask.recurrenceInterval;

    switch (recurringTask.recurrenceType) {
      case 'DAILY':
        date.setDate(date.getDate() + interval);
        break;
      
      case 'WEEKLY':
        if (recurringTask.recurrenceDays.length > 0) {
          // Find next occurrence based on specified days
          const dayMap = { 'SUN': 0, 'MON': 1, 'TUE': 2, 'WED': 3, 'THU': 4, 'FRI': 5, 'SAT': 6 };
          const targetDays = recurringTask.recurrenceDays.map(day => dayMap[day]).sort((a, b) => a - b);
          
          let nextDay = null;
          const currentDay = date.getDay();
          
          // Find next day in current week
          for (const day of targetDays) {
            if (day > currentDay) {
              nextDay = day;
              break;
            }
          }
          
          if (nextDay === null) {
            // Move to next week and use first day
            date.setDate(date.getDate() + (7 - currentDay + targetDays[0]));
          } else {
            date.setDate(date.getDate() + (nextDay - currentDay));
          }
        } else {
          date.setDate(date.getDate() + (7 * interval));
        }
        break;
      
      case 'MONTHLY':
        date.setMonth(date.getMonth() + interval);
        break;
      
      case 'QUARTERLY':
        date.setMonth(date.getMonth() + (3 * interval));
        break;
      
      case 'YEARLY':
        date.setFullYear(date.getFullYear() + interval);
        break;
      
      default:
        date.setDate(date.getDate() + 1);
    }

    return date;
  }

  // Calculate task due date based on recurring task settings
  calculateTaskDueDate(recurringTask, generatedDate) {
    // For now, set due date to the same day
    // This could be enhanced to add buffer time based on task complexity
    return new Date(generatedDate);
  }

  // Get recurring task statistics
  async getRecurringTaskStats(projectId) {
    try {
      const stats = await prisma.recurringTask.aggregate({
        where: { projectId },
        _count: { id: true },
        _sum: { usageCount: true }
      });

      const activeCount = await prisma.recurringTask.count({
        where: { projectId, isActive: true }
      });

      const generatedTasksCount = await prisma.task.count({
        where: {
          projectId,
          recurringTaskId: { not: null }
        }
      });

      return {
        totalRecurringTasks: stats._count.id || 0,
        activeRecurringTasks: activeCount,
        generatedTasksCount,
        totalUsage: stats._sum.usageCount || 0
      };
    } catch (error) {
      logger.error('Error getting recurring task stats:', error);
      throw error;
    }
  }
}

module.exports = new TaskTemplateService();
