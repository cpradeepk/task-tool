const { PrismaClient } = require('@prisma/client');
const logger = require('../config/logger');
const activityService = require('../services/activityService');
const notificationService = require('../services/notificationService');

const prisma = new PrismaClient();

// Helper function to calculate PERT estimate
const calculatePERTEstimate = (optimistic, pessimistic, mostLikely) => {
  if (!optimistic || !pessimistic || !mostLikely) return null;
  return (optimistic + 4 * mostLikely + pessimistic) / 6;
};

// Helper function to handle status change auto-dates
const handleStatusChange = (currentStatus, newStatus, currentData) => {
  const updates = {};

  if (newStatus === 'IN_PROGRESS' && currentStatus !== 'IN_PROGRESS') {
    updates.startDate = new Date();
  }

  if (newStatus === 'COMPLETED' && currentStatus !== 'COMPLETED') {
    updates.endDate = new Date();
  }

  return updates;
};

class TaskController {
  async createTask(req, res) {
    try {
      const {
        title,
        description,
        projectId,
        subProjectId,
        parentTaskId,
        mainAssigneeId,
        supportAssignees = [],
        priority = 'NOT_IMPORTANT_NOT_URGENT',
        taskType = 'REQUIREMENT',
        dueDate,
        plannedEndDate,
        optimisticHours,
        pessimisticHours,
        mostLikelyHours,
        tags = [],
        milestones = [],
        customLabels = []
      } = req.body;

      // Verify project access if projectId provided
      if (projectId) {
        const projectMember = await prisma.projectMember.findFirst({
          where: {
            projectId,
            userId: req.user.id
          }
        });

        if (!projectMember) {
          return res.status(403).json({ error: 'No access to this project' });
        }
      }

      // Calculate PERT estimate
      const estimatedHours = calculatePERTEstimate(optimisticHours, pessimisticHours, mostLikelyHours);

      const task = await prisma.task.create({
        data: {
          title,
          description,
          projectId,
          subProjectId,
          parentTaskId,
          mainAssigneeId,
          priority,
          taskType,
          dueDate: dueDate ? new Date(dueDate) : null,
          plannedEndDate: plannedEndDate ? new Date(plannedEndDate) : null,
          optimisticHours: optimisticHours ? parseFloat(optimisticHours) : null,
          pessimisticHours: pessimisticHours ? parseFloat(pessimisticHours) : null,
          mostLikelyHours: mostLikelyHours ? parseFloat(mostLikelyHours) : null,
          estimatedHours,
          tags,
          milestones,
          customLabels,
          createdById: req.user.id
        },
        include: {
          project: {
            select: { id: true, name: true }
          },
          subProject: {
            select: { id: true, name: true }
          },
          parentTask: {
            select: { id: true, title: true }
          },
          mainAssignee: {
            select: { id: true, name: true, email: true }
          },
          createdBy: {
            select: { id: true, name: true, email: true }
          },
          assignments: {
            include: {
              user: {
                select: { id: true, name: true, email: true }
              }
            }
          },
          _count: {
            select: { comments: true, attachments: true, subtasks: true }
          }
        }
      });

      // Create support assignments
      if (supportAssignees.length > 0) {
        await prisma.taskAssignment.createMany({
          data: supportAssignees.map(userId => ({
            taskId: task.id,
            userId,
            role: 'SUPPORT'
          }))
        });
      }

      // Log activity
      await activityService.logTaskCreated(
        req.user.id,
        task.id,
        task.projectId,
        task.title
      );

      // Send notifications to assignees
      const assigneeIds = [
        ...(task.mainAssigneeId ? [task.mainAssigneeId] : []),
        ...supportAssignees
      ].filter(id => id !== req.user.id); // Don't notify the creator

      if (assigneeIds.length > 0) {
        await notificationService.createTaskAssignedNotifications(
          assigneeIds,
          task.id,
          task.title,
          req.user.name
        );
      }

      logger.info(`Task created: ${task.title} by ${req.user.email}`);
      res.status(201).json(task);
    } catch (error) {
      logger.error('Create task error:', error);
      res.status(500).json({ error: 'Failed to create task' });
    }
  }

  async getTasks(req, res) {
    try {
      const {
        page = 1,
        limit = 10,
        status,
        priority,
        taskType,
        projectId,
        subProjectId,
        parentTaskId,
        mainAssigneeId,
        search,
        sortBy = 'createdAt',
        sortOrder = 'desc'
      } = req.query;

      const skip = (page - 1) * limit;

      // Build where clause - user can see tasks they created, are assigned to, or are in projects they're members of
      const where = {
        OR: [
          { createdById: req.user.id },
          { mainAssigneeId: req.user.id },
          {
            assignments: {
              some: { userId: req.user.id }
            }
          },
          {
            project: {
              members: {
                some: { userId: req.user.id }
              }
            }
          }
        ]
      };

      // Apply filters
      if (status) where.status = status;
      if (priority) where.priority = priority;
      if (taskType) where.taskType = taskType;
      if (projectId) where.projectId = projectId;
      if (subProjectId) where.subProjectId = subProjectId;
      if (parentTaskId) where.parentTaskId = parentTaskId;
      if (mainAssigneeId) where.mainAssigneeId = mainAssigneeId;

      // Search functionality
      if (search) {
        where.AND = [
          {
            OR: [
              { title: { contains: search, mode: 'insensitive' } },
              { description: { contains: search, mode: 'insensitive' } },
              { tags: { has: search } },
              { customLabels: { has: search } }
            ]
          }
        ];
      }

      // Build order by clause
      const orderBy = {};
      orderBy[sortBy] = sortOrder;

      const [tasks, total] = await Promise.all([
        prisma.task.findMany({
          where,
          skip: parseInt(skip),
          take: parseInt(limit),
          include: {
            project: {
              select: { id: true, name: true }
            },
            subProject: {
              select: { id: true, name: true }
            },
            parentTask: {
              select: { id: true, title: true }
            },
            mainAssignee: {
              select: { id: true, name: true, email: true }
            },
            createdBy: {
              select: { id: true, name: true, email: true }
            },
            assignments: {
              include: {
                user: {
                  select: { id: true, name: true, email: true }
                }
              }
            },
            subtasks: {
              select: { id: true, title: true, status: true }
            },
            _count: {
              select: { comments: true, attachments: true, subtasks: true }
            }
          },
          orderBy
        }),
        prisma.task.count({ where })
      ]);

      res.json({
        tasks,
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total,
          pages: Math.ceil(total / limit)
        }
      });
    } catch (error) {
      logger.error('Get tasks error:', error);
      res.status(500).json({ error: 'Failed to get tasks' });
    }
  }

  async getTask(req, res) {
    try {
      const { id } = req.params;

      const task = await prisma.task.findFirst({
        where: {
          id,
          OR: [
            { createdById: req.user.id },
            { mainAssigneeId: req.user.id },
            {
              assignments: {
                some: { userId: req.user.id }
              }
            },
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
          project: {
            select: { id: true, name: true }
          },
          subProject: {
            select: { id: true, name: true }
          },
          parentTask: {
            select: { id: true, title: true }
          },
          mainAssignee: {
            select: { id: true, name: true, email: true }
          },
          createdBy: {
            select: { id: true, name: true, email: true }
          },
          assignments: {
            include: {
              user: {
                select: { id: true, name: true, email: true }
              }
            }
          },
          subtasks: {
            include: {
              mainAssignee: {
                select: { id: true, name: true, email: true }
              }
            }
          },
          preDependencies: {
            include: {
              preTask: {
                select: { id: true, title: true, status: true }
              }
            }
          },
          postDependencies: {
            include: {
              postTask: {
                select: { id: true, title: true, status: true }
              }
            }
          },
          comments: {
            include: {
              user: {
                select: { id: true, name: true, email: true }
              }
            },
            orderBy: { createdAt: 'desc' }
          },
          timeEntries: {
            include: {
              user: {
                select: { id: true, name: true, email: true }
              }
            },
            orderBy: { date: 'desc' }
          },
          attachments: true,
          _count: {
            select: { comments: true, attachments: true, subtasks: true }
          }
        }
      });

      if (!task) {
        return res.status(404).json({ error: 'Task not found or access denied' });
      }

      res.json(task);
    } catch (error) {
      logger.error('Get task error:', error);
      res.status(500).json({ error: 'Failed to get task' });
    }
  }

  async updateTask(req, res) {
    try {
      const { id } = req.params;
      const {
        title,
        description,
        status,
        priority,
        taskType,
        dueDate,
        plannedEndDate,
        optimisticHours,
        pessimisticHours,
        mostLikelyHours,
        mainAssigneeId,
        supportAssignees = [],
        tags,
        milestones,
        customLabels
      } = req.body;

      // Get current task to check permissions and current status
      const currentTask = await prisma.task.findFirst({
        where: {
          id,
          OR: [
            { createdById: req.user.id },
            { mainAssigneeId: req.user.id },
            {
              assignments: {
                some: { userId: req.user.id }
              }
            },
            {
              project: {
                members: {
                  some: { userId: req.user.id }
                }
              }
            }
          ]
        }
      });

      if (!currentTask) {
        return res.status(404).json({ error: 'Task not found or access denied' });
      }

      // Prepare update data
      const updateData = {};
      if (title !== undefined) updateData.title = title;
      if (description !== undefined) updateData.description = description;
      if (priority !== undefined) updateData.priority = priority;
      if (taskType !== undefined) updateData.taskType = taskType;
      if (dueDate !== undefined) updateData.dueDate = dueDate ? new Date(dueDate) : null;
      if (plannedEndDate !== undefined) updateData.plannedEndDate = plannedEndDate ? new Date(plannedEndDate) : null;
      if (optimisticHours !== undefined) updateData.optimisticHours = optimisticHours ? parseFloat(optimisticHours) : null;
      if (pessimisticHours !== undefined) updateData.pessimisticHours = pessimisticHours ? parseFloat(pessimisticHours) : null;
      if (mostLikelyHours !== undefined) updateData.mostLikelyHours = mostLikelyHours ? parseFloat(mostLikelyHours) : null;
      if (mainAssigneeId !== undefined) updateData.mainAssigneeId = mainAssigneeId;
      if (tags !== undefined) updateData.tags = tags;
      if (milestones !== undefined) updateData.milestones = milestones;
      if (customLabels !== undefined) updateData.customLabels = customLabels;

      // Handle status change auto-dates
      if (status !== undefined && status !== currentTask.status) {
        updateData.status = status;
        const statusUpdates = handleStatusChange(currentTask.status, status, currentTask);
        Object.assign(updateData, statusUpdates);
      }

      // Recalculate PERT estimate if any time values changed
      if (optimisticHours !== undefined || pessimisticHours !== undefined || mostLikelyHours !== undefined) {
        const newOptimistic = optimisticHours !== undefined ? optimisticHours : currentTask.optimisticHours;
        const newPessimistic = pessimisticHours !== undefined ? pessimisticHours : currentTask.pessimisticHours;
        const newMostLikely = mostLikelyHours !== undefined ? mostLikelyHours : currentTask.mostLikelyHours;
        updateData.estimatedHours = calculatePERTEstimate(newOptimistic, newPessimistic, newMostLikely);
      }

      const task = await prisma.task.update({
        where: { id },
        data: updateData,
        include: {
          project: {
            select: { id: true, name: true }
          },
          subProject: {
            select: { id: true, name: true }
          },
          parentTask: {
            select: { id: true, title: true }
          },
          mainAssignee: {
            select: { id: true, name: true, email: true }
          },
          createdBy: {
            select: { id: true, name: true, email: true }
          },
          assignments: {
            include: {
              user: {
                select: { id: true, name: true, email: true }
              }
            }
          },
          _count: {
            select: { comments: true, attachments: true, subtasks: true }
          }
        }
      });

      // Update support assignments if provided
      if (supportAssignees.length >= 0) {
        // Remove existing support assignments
        await prisma.taskAssignment.deleteMany({
          where: {
            taskId: id,
            role: 'SUPPORT'
          }
        });

        // Add new support assignments
        if (supportAssignees.length > 0) {
          await prisma.taskAssignment.createMany({
            data: supportAssignees.map(userId => ({
              taskId: id,
              userId,
              role: 'SUPPORT'
            }))
          });
        }
      }

      // Log activity for significant changes
      const changes = [];
      if (status !== undefined && status !== currentTask.status) {
        changes.push(`status changed from ${currentTask.status} to ${status}`);

        // Log specific activity for status changes
        if (status === 'COMPLETED') {
          await activityService.logTaskCompleted(
            req.user.id,
            task.id,
            task.projectId,
            task.title
          );

          // Notify relevant users about completion
          const notifyUsers = [
            currentTask.createdById,
            ...(currentTask.mainAssigneeId ? [currentTask.mainAssigneeId] : []),
            ...supportAssignees
          ].filter((id, index, arr) => arr.indexOf(id) === index && id !== req.user.id);

          if (notifyUsers.length > 0) {
            await notificationService.createTaskCompletedNotifications(
              notifyUsers,
              task.id,
              task.title,
              req.user.name
            );
          }
        } else {
          await activityService.logTaskStatusChanged(
            req.user.id,
            task.id,
            task.projectId,
            task.title,
            currentTask.status,
            status
          );
        }
      }

      if (mainAssigneeId !== undefined && mainAssigneeId !== currentTask.mainAssigneeId) {
        changes.push(`assignee changed`);

        // Log assignment change
        await activityService.logTaskAssigned(
          req.user.id,
          task.id,
          task.projectId,
          task.title,
          mainAssigneeId
        );

        // Notify new assignee
        if (mainAssigneeId && mainAssigneeId !== req.user.id) {
          await notificationService.createTaskAssignedNotifications(
            [mainAssigneeId],
            task.id,
            task.title,
            req.user.name
          );
        }
      }

      if (priority !== undefined && priority !== currentTask.priority) {
        changes.push(`priority changed from ${currentTask.priority} to ${priority}`);

        await activityService.logTaskPriorityChanged(
          req.user.id,
          task.id,
          task.projectId,
          task.title,
          currentTask.priority,
          priority
        );
      }

      // General task update activity if other changes were made
      if (changes.length === 0 && Object.keys(updateData).length > 0) {
        await activityService.logTaskUpdated(
          req.user.id,
          task.id,
          task.projectId,
          task.title
        );
      }

      logger.info(`Task updated: ${task.title} by ${req.user.email}`);
      res.json(task);
    } catch (error) {
      logger.error('Update task error:', error);
      res.status(500).json({ error: 'Failed to update task' });
    }
  }

  async deleteTask(req, res) {
    try {
      const { id } = req.params;

      // Check if user has permission to delete (only creator or project admin)
      const task = await prisma.task.findFirst({
        where: {
          id,
          OR: [
            { createdById: req.user.id },
            {
              project: {
                members: {
                  some: {
                    userId: req.user.id,
                    role: { in: ['OWNER', 'ADMIN'] }
                  }
                }
              }
            }
          ]
        }
      });

      if (!task) {
        return res.status(404).json({ error: 'Task not found or no permission to delete' });
      }

      await prisma.task.delete({
        where: { id }
      });

      logger.info(`Task deleted: ${id} by ${req.user.email}`);
      res.status(204).send();
    } catch (error) {
      logger.error('Delete task error:', error);
      res.status(500).json({ error: 'Failed to delete task' });
    }
  }

  // Add task dependency
  async addTaskDependency(req, res) {
    try {
      const { id } = req.params; // postTaskId (dependent task)
      const { preTaskId, dependencyType = 'FINISH_TO_START' } = req.body;

      // Verify user has access to both tasks
      const [preTask, postTask] = await Promise.all([
        prisma.task.findFirst({
          where: {
            id: preTaskId,
            OR: [
              { createdById: req.user.id },
              { mainAssigneeId: req.user.id },
              {
                project: {
                  members: {
                    some: { userId: req.user.id }
                  }
                }
              }
            ]
          }
        }),
        prisma.task.findFirst({
          where: {
            id,
            OR: [
              { createdById: req.user.id },
              { mainAssigneeId: req.user.id },
              {
                project: {
                  members: {
                    some: { userId: req.user.id }
                  }
                }
              }
            ]
          }
        })
      ]);

      if (!preTask || !postTask) {
        return res.status(404).json({ error: 'One or both tasks not found or access denied' });
      }

      // Check for circular dependencies
      const existingDependency = await prisma.taskDependency.findFirst({
        where: {
          preTaskId: id,
          postTaskId: preTaskId
        }
      });

      if (existingDependency) {
        return res.status(400).json({ error: 'Cannot create circular dependency' });
      }

      const dependency = await prisma.taskDependency.create({
        data: {
          preTaskId,
          postTaskId: id,
          dependencyType
        },
        include: {
          preTask: {
            select: { id: true, title: true, status: true }
          },
          postTask: {
            select: { id: true, title: true, status: true }
          }
        }
      });

      logger.info(`Task dependency created: ${preTaskId} -> ${id} by ${req.user.email}`);
      res.status(201).json(dependency);
    } catch (error) {
      logger.error('Add task dependency error:', error);
      if (error.code === 'P2002') {
        return res.status(400).json({ error: 'Dependency already exists' });
      }
      res.status(500).json({ error: 'Failed to add task dependency' });
    }
  }

  // Remove task dependency
  async removeTaskDependency(req, res) {
    try {
      const { id, dependencyId } = req.params;

      // Verify user has access to the task
      const task = await prisma.task.findFirst({
        where: {
          id,
          OR: [
            { createdById: req.user.id },
            { mainAssigneeId: req.user.id },
            {
              project: {
                members: {
                  some: { userId: req.user.id }
                }
              }
            }
          ]
        }
      });

      if (!task) {
        return res.status(404).json({ error: 'Task not found or access denied' });
      }

      await prisma.taskDependency.delete({
        where: {
          id: dependencyId,
          postTaskId: id
        }
      });

      logger.info(`Task dependency removed: ${dependencyId} by ${req.user.email}`);
      res.status(204).send();
    } catch (error) {
      logger.error('Remove task dependency error:', error);
      if (error.code === 'P2025') {
        return res.status(404).json({ error: 'Dependency not found' });
      }
      res.status(500).json({ error: 'Failed to remove task dependency' });
    }
  }

  async addComment(req, res) {
    try {
      const { id } = req.params;
      const { content } = req.body;

      // Verify task access
      const task = await prisma.task.findFirst({
        where: {
          id,
          OR: [
            { createdById: req.user.id },
            { mainAssigneeId: req.user.id },
            {
              assignments: {
                some: { userId: req.user.id }
              }
            },
            {
              project: {
                members: {
                  some: { userId: req.user.id }
                }
              }
            }
          ]
        }
      });

      if (!task) {
        return res.status(404).json({ error: 'Task not found or no access' });
      }

      const comment = await prisma.taskComment.create({
        data: {
          content,
          taskId: id,
          userId: req.user.id
        },
        include: {
          user: {
            select: { id: true, name: true, email: true }
          }
        }
      });

      logger.info(`Comment added to task ${id} by ${req.user.email}`);
      res.status(201).json(comment);
    } catch (error) {
      logger.error('Add comment error:', error);
      res.status(500).json({ error: 'Failed to add comment' });
    }
  }

  async addTimeEntry(req, res) {
    try {
      const { id } = req.params;
      const { description, hours, date } = req.body;

      // Verify task access
      const task = await prisma.task.findFirst({
        where: {
          id,
          OR: [
            { createdById: req.user.id },
            { mainAssigneeId: req.user.id },
            {
              assignments: {
                some: { userId: req.user.id }
              }
            },
            {
              project: {
                members: {
                  some: { userId: req.user.id }
                }
              }
            }
          ]
        }
      });

      if (!task) {
        return res.status(404).json({ error: 'Task not found or no access' });
      }

      const timeEntry = await prisma.timeEntry.create({
        data: {
          description,
          hours: parseFloat(hours),
          date: date ? new Date(date) : new Date(),
          taskId: id,
          userId: req.user.id
        },
        include: {
          user: {
            select: { id: true, name: true, email: true }
          }
        }
      });

      // Update actual hours on task
      const totalHours = await prisma.timeEntry.aggregate({
        where: { taskId: id },
        _sum: { hours: true }
      });

      await prisma.task.update({
        where: { id },
        data: { actualHours: totalHours._sum.hours }
      });

      logger.info(`Time entry added to task ${id} by ${req.user.email}`);
      res.status(201).json(timeEntry);
    } catch (error) {
      logger.error('Add time entry error:', error);
      res.status(500).json({ error: 'Failed to add time entry' });
    }
  }
}

module.exports = new TaskController();