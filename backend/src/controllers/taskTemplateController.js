const { PrismaClient } = require('@prisma/client');
const logger = require('../config/logger');
const taskTemplateService = require('../services/taskTemplateService');

const prisma = new PrismaClient();

class TaskTemplateController {
  // Create task template
  async createTemplate(req, res) {
    try {
      const {
        name,
        description,
        taskType,
        priority,
        optimisticHours,
        pessimisticHours,
        mostLikelyHours,
        tags,
        milestones,
        customLabels,
        projectId,
        isPublic
      } = req.body;

      // Verify project access if projectId provided
      if (projectId) {
        const membership = await prisma.projectMember.findFirst({
          where: {
            projectId,
            userId: req.user.id
          }
        });

        if (!membership && !req.user.isAdmin) {
          return res.status(403).json({ error: 'Access denied to this project' });
        }
      }

      const template = await prisma.taskTemplate.create({
        data: {
          name,
          description,
          taskType: taskType || 'REQUIREMENT',
          priority: priority || 'NOT_IMPORTANT_NOT_URGENT',
          optimisticHours: optimisticHours ? parseFloat(optimisticHours) : null,
          pessimisticHours: pessimisticHours ? parseFloat(pessimisticHours) : null,
          mostLikelyHours: mostLikelyHours ? parseFloat(mostLikelyHours) : null,
          tags: tags || [],
          milestones: milestones || [],
          customLabels: customLabels || [],
          projectId,
          isPublic: isPublic || false,
          createdById: req.user.id
        },
        include: {
          createdBy: { select: { id: true, name: true, email: true } },
          project: { select: { id: true, name: true } }
        }
      });

      logger.info(`Task template created: ${template.name} by ${req.user.email}`);
      res.status(201).json(template);
    } catch (error) {
      logger.error('Error creating task template:', error);
      res.status(500).json({ error: 'Failed to create task template' });
    }
  }

  // Get task templates
  async getTemplates(req, res) {
    try {
      const { projectId, isPublic, search, limit = 20 } = req.query;

      const where = {
        OR: [
          { createdById: req.user.id },
          { isPublic: true },
          ...(projectId ? [{
            projectId,
            project: {
              members: {
                some: { userId: req.user.id }
              }
            }
          }] : [])
        ]
      };

      if (projectId) {
        where.projectId = projectId;
      }

      if (isPublic !== undefined) {
        where.isPublic = isPublic === 'true';
      }

      if (search) {
        where.AND = [
          {
            OR: [
              { name: { contains: search, mode: 'insensitive' } },
              { description: { contains: search, mode: 'insensitive' } }
            ]
          }
        ];
      }

      const templates = await prisma.taskTemplate.findMany({
        where,
        include: {
          createdBy: { select: { id: true, name: true, email: true } },
          project: { select: { id: true, name: true } }
        },
        orderBy: { usageCount: 'desc' },
        take: parseInt(limit)
      });

      res.json(templates);
    } catch (error) {
      logger.error('Error getting task templates:', error);
      res.status(500).json({ error: 'Failed to get task templates' });
    }
  }

  // Get template by ID
  async getTemplate(req, res) {
    try {
      const { id } = req.params;

      const template = await prisma.taskTemplate.findFirst({
        where: {
          id,
          OR: [
            { createdById: req.user.id },
            { isPublic: true },
            {
              project: {
                members: {
                  some: { userId: req.user.id }
                }
              }
            }
          ]
        },
        include: {
          createdBy: { select: { id: true, name: true, email: true } },
          project: { select: { id: true, name: true } }
        }
      });

      if (!template) {
        return res.status(404).json({ error: 'Template not found or access denied' });
      }

      res.json(template);
    } catch (error) {
      logger.error('Error getting task template:', error);
      res.status(500).json({ error: 'Failed to get task template' });
    }
  }

  // Update template
  async updateTemplate(req, res) {
    try {
      const { id } = req.params;
      const {
        name,
        description,
        taskType,
        priority,
        optimisticHours,
        pessimisticHours,
        mostLikelyHours,
        tags,
        milestones,
        customLabels,
        isPublic
      } = req.body;

      // Verify user owns the template
      const existingTemplate = await prisma.taskTemplate.findFirst({
        where: {
          id,
          createdById: req.user.id
        }
      });

      if (!existingTemplate) {
        return res.status(404).json({ error: 'Template not found or access denied' });
      }

      const updateData = {};
      if (name !== undefined) updateData.name = name;
      if (description !== undefined) updateData.description = description;
      if (taskType !== undefined) updateData.taskType = taskType;
      if (priority !== undefined) updateData.priority = priority;
      if (optimisticHours !== undefined) updateData.optimisticHours = optimisticHours ? parseFloat(optimisticHours) : null;
      if (pessimisticHours !== undefined) updateData.pessimisticHours = pessimisticHours ? parseFloat(pessimisticHours) : null;
      if (mostLikelyHours !== undefined) updateData.mostLikelyHours = mostLikelyHours ? parseFloat(mostLikelyHours) : null;
      if (tags !== undefined) updateData.tags = tags;
      if (milestones !== undefined) updateData.milestones = milestones;
      if (customLabels !== undefined) updateData.customLabels = customLabels;
      if (isPublic !== undefined) updateData.isPublic = isPublic;

      const template = await prisma.taskTemplate.update({
        where: { id },
        data: updateData,
        include: {
          createdBy: { select: { id: true, name: true, email: true } },
          project: { select: { id: true, name: true } }
        }
      });

      logger.info(`Task template updated: ${template.name} by ${req.user.email}`);
      res.json(template);
    } catch (error) {
      logger.error('Error updating task template:', error);
      res.status(500).json({ error: 'Failed to update task template' });
    }
  }

  // Delete template
  async deleteTemplate(req, res) {
    try {
      const { id } = req.params;

      // Verify user owns the template
      const template = await prisma.taskTemplate.findFirst({
        where: {
          id,
          createdById: req.user.id
        }
      });

      if (!template) {
        return res.status(404).json({ error: 'Template not found or access denied' });
      }

      await prisma.taskTemplate.delete({
        where: { id }
      });

      logger.info(`Task template deleted: ${id} by ${req.user.email}`);
      res.status(204).send();
    } catch (error) {
      logger.error('Error deleting task template:', error);
      res.status(500).json({ error: 'Failed to delete task template' });
    }
  }

  // Create task from template
  async createTaskFromTemplate(req, res) {
    try {
      const { templateId } = req.params;
      const overrides = req.body;

      const task = await taskTemplateService.createTaskFromTemplate(templateId, req.user.id, overrides);

      logger.info(`Task created from template ${templateId} by ${req.user.email}`);
      res.status(201).json(task);
    } catch (error) {
      logger.error('Error creating task from template:', error);
      res.status(400).json({ error: error.message });
    }
  }

  // Get popular templates
  async getPopularTemplates(req, res) {
    try {
      const { projectId, limit = 10 } = req.query;

      const templates = await taskTemplateService.getPopularTemplates(projectId, parseInt(limit));
      res.json(templates);
    } catch (error) {
      logger.error('Error getting popular templates:', error);
      res.status(500).json({ error: 'Failed to get popular templates' });
    }
  }

  // Suggest templates
  async suggestTemplates(req, res) {
    try {
      const taskData = req.body;

      const suggestions = await taskTemplateService.suggestTemplates(taskData, req.user.id);
      res.json(suggestions);
    } catch (error) {
      logger.error('Error suggesting templates:', error);
      res.status(500).json({ error: 'Failed to suggest templates' });
    }
  }

  // Create recurring task
  async createRecurringTask(req, res) {
    try {
      const {
        name,
        description,
        taskType,
        priority,
        recurrenceType,
        recurrenceInterval,
        recurrenceDays,
        recurrenceEndDate,
        optimisticHours,
        pessimisticHours,
        mostLikelyHours,
        tags,
        milestones,
        customLabels,
        projectId,
        subProjectId,
        mainAssigneeId
      } = req.body;

      // Verify project access if projectId provided
      if (projectId) {
        const membership = await prisma.projectMember.findFirst({
          where: {
            projectId,
            userId: req.user.id
          }
        });

        if (!membership && !req.user.isAdmin) {
          return res.status(403).json({ error: 'Access denied to this project' });
        }
      }

      // Calculate next due date
      const nextDue = taskTemplateService.calculateNextDueDate({
        recurrenceType,
        recurrenceInterval: recurrenceInterval || 1,
        recurrenceDays: recurrenceDays || []
      }, new Date());

      const recurringTask = await prisma.recurringTask.create({
        data: {
          name,
          description,
          taskType: taskType || 'REQUIREMENT',
          priority: priority || 'NOT_IMPORTANT_NOT_URGENT',
          recurrenceType,
          recurrenceInterval: recurrenceInterval || 1,
          recurrenceDays: recurrenceDays || [],
          recurrenceEndDate: recurrenceEndDate ? new Date(recurrenceEndDate) : null,
          optimisticHours: optimisticHours ? parseFloat(optimisticHours) : null,
          pessimisticHours: pessimisticHours ? parseFloat(pessimisticHours) : null,
          mostLikelyHours: mostLikelyHours ? parseFloat(mostLikelyHours) : null,
          tags: tags || [],
          milestones: milestones || [],
          customLabels: customLabels || [],
          projectId,
          subProjectId,
          mainAssigneeId,
          createdById: req.user.id,
          nextDue
        },
        include: {
          createdBy: { select: { id: true, name: true, email: true } },
          project: { select: { id: true, name: true } },
          subProject: { select: { id: true, name: true } },
          mainAssignee: { select: { id: true, name: true, email: true } }
        }
      });

      logger.info(`Recurring task created: ${recurringTask.name} by ${req.user.email}`);
      res.status(201).json(recurringTask);
    } catch (error) {
      logger.error('Error creating recurring task:', error);
      res.status(500).json({ error: 'Failed to create recurring task' });
    }
  }

  // Get recurring tasks
  async getRecurringTasks(req, res) {
    try {
      const { projectId, isActive } = req.query;

      const where = {};
      
      if (projectId) {
        where.projectId = projectId;
        
        // Verify user has access to the project
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
      } else {
        // User can only see recurring tasks they created or are assigned to
        where.OR = [
          { createdById: req.user.id },
          { mainAssigneeId: req.user.id },
          {
            project: {
              members: {
                some: { userId: req.user.id }
              }
            }
          }
        ];
      }

      if (isActive !== undefined) {
        where.isActive = isActive === 'true';
      }

      const recurringTasks = await prisma.recurringTask.findMany({
        where,
        include: {
          createdBy: { select: { id: true, name: true, email: true } },
          project: { select: { id: true, name: true } },
          subProject: { select: { id: true, name: true } },
          mainAssignee: { select: { id: true, name: true, email: true } },
          _count: { select: { generatedTasks: true } }
        },
        orderBy: { createdAt: 'desc' }
      });

      res.json(recurringTasks);
    } catch (error) {
      logger.error('Error getting recurring tasks:', error);
      res.status(500).json({ error: 'Failed to get recurring tasks' });
    }
  }

  // Generate recurring tasks manually
  async generateRecurringTasks(req, res) {
    try {
      // Only admins can manually trigger generation
      if (!req.user.isAdmin) {
        return res.status(403).json({ error: 'Only administrators can manually generate recurring tasks' });
      }

      const generatedTasks = await taskTemplateService.generateRecurringTasks();

      logger.info(`Generated ${generatedTasks.length} recurring tasks by ${req.user.email}`);
      res.json({
        message: `Generated ${generatedTasks.length} tasks`,
        tasks: generatedTasks
      });
    } catch (error) {
      logger.error('Error generating recurring tasks:', error);
      res.status(500).json({ error: 'Failed to generate recurring tasks' });
    }
  }
}

module.exports = new TaskTemplateController();
