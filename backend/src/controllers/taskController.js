const prisma = require('../config/database');
const logger = require('../config/logger');

class TaskController {
  async createTask(req, res) {
    try {
      const { 
        title, 
        description, 
        projectId, 
        assignedToId, 
        priority = 'MEDIUM',
        dueDate,
        estimatedHours,
        tags = []
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

      const task = await prisma.task.create({
        data: {
          title,
          description,
          projectId,
          assignedToId,
          priority,
          dueDate: dueDate ? new Date(dueDate) : null,
          estimatedHours: estimatedHours ? parseFloat(estimatedHours) : null,
          tags,
          createdById: req.user.id
        },
        include: {
          project: {
            select: { id: true, name: true }
          },
          assignedTo: {
            select: { id: true, name: true, email: true }
          },
          createdBy: {
            select: { id: true, name: true, email: true }
          },
          _count: {
            select: { comments: true, attachments: true }
          }
        }
      });

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
        projectId, 
        assignedToId,
        search 
      } = req.query;
      
      const skip = (page - 1) * limit;

      // Build where clause
      const where = {
        OR: [
          { createdById: req.user.id },
          { assignedToId: req.user.id },
          {
            project: {
              members: {
                some: { userId: req.user.id }
              }
            }
          }
        ]
      };

      if (status) where.status = status;
      if (priority) where.priority = priority;
      if (projectId) where.projectId = projectId;
      if (assignedToId) where.assignedToId = assignedToId;
      if (search) {
        where.OR = [
          { title: { contains: search, mode: 'insensitive' } },
          { description: { contains: search, mode: 'insensitive' } }
        ];
      }

      const [tasks, total] = await Promise.all([
        prisma.task.findMany({
          where,
          skip: parseInt(skip),
          take: parseInt(limit),
          include: {
            project: {
              select: { id: true, name: true }
            },
            assignedTo: {
              select: { id: true, name: true, email: true }
            },
            createdBy: {
              select: { id: true, name: true, email: true }
            },
            _count: {
              select: { comments: true, attachments: true }
            }
          },
          orderBy: { createdAt: 'desc' }
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
            { assignedToId: req.user.id },
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
          assignedTo: {
            select: { id: true, name: true, email: true }
          },
          createdBy: {
            select: { id: true, name: true, email: true }
          },
          comments: {
            include: {
              user: {
                select: { id: true, name: true, email: true }
              }
            },
            orderBy: { createdAt: 'desc' }
          },
          attachments: {
            select: {
              id: true,
              fileName: true,
              originalName: true,
              mimeType: true,
              size: true,
              createdAt: true
            }
          },
          timeEntries: {
            include: {
              user: {
                select: { id: true, name: true, email: true }
              }
            },
            orderBy: { date: 'desc' }
          }
        }
      });

      if (!task) {
        return res.status(404).json({ error: 'Task not found' });
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
        assignedToId, 
        dueDate,
        estimatedHours,
        actualHours,
        tags 
      } = req.body;

      // Check if user has permission to update
      const task = await prisma.task.findFirst({
        where: {
          id,
          OR: [
            { createdById: req.user.id },
            { assignedToId: req.user.id },
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
        return res.status(404).json({ error: 'Task not found or no permission' });
      }

      const updatedTask = await prisma.task.update({
        where: { id },
        data: {
          ...(title && { title }),
          ...(description !== undefined && { description }),
          ...(status && { status }),
          ...(priority && { priority }),
          ...(assignedToId !== undefined && { assignedToId }),
          ...(dueDate && { dueDate: new Date(dueDate) }),
          ...(estimatedHours !== undefined && { estimatedHours: parseFloat(estimatedHours) }),
          ...(actualHours !== undefined && { actualHours: parseFloat(actualHours) }),
          ...(tags && { tags })
        },
        include: {
          project: {
            select: { id: true, name: true }
          },
          assignedTo: {
            select: { id: true, name: true, email: true }
          },
          createdBy: {
            select: { id: true, name: true, email: true }
          }
        }
      });

      res.json(updatedTask);
    } catch (error) {
      logger.error('Update task error:', error);
      res.status(500).json({ error: 'Failed to update task' });
    }
  }

  async deleteTask(req, res) {
    try {
      const { id } = req.params;

      // Check if user has permission to delete
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
        return res.status(404).json({ error: 'Task not found or no permission' });
      }

      await prisma.task.delete({
        where: { id }
      });

      res.json({ message: 'Task deleted successfully' });
    } catch (error) {
      logger.error('Delete task error:', error);
      res.status(500).json({ error: 'Failed to delete task' });
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
            { assignedToId: req.user.id },
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
            { assignedToId: req.user.id },
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

      res.status(201).json(timeEntry);
    } catch (error) {
      logger.error('Add time entry error:', error);
      res.status(500).json({ error: 'Failed to add time entry' });
    }
  }
}

module.exports = new TaskController();