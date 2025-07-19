const express = require('express');
const { PrismaClient } = require('@prisma/client');
const { authenticateToken } = require('../middleware/auth');
const logger = require('../config/logger');

const router = express.Router();
const prisma = new PrismaClient();

// Get all tasks
router.get('/', authenticateToken, async (req, res) => {
  try {
    const { projectId, status, priority, assignedToId, search } = req.query;
    
    const where = {};
    
    if (projectId) where.projectId = projectId;
    if (status) where.status = status;
    if (priority) where.priority = priority;
    if (assignedToId) where.assignedToId = assignedToId;
    
    if (search) {
      where.OR = [
        { title: { contains: search, mode: 'insensitive' } },
        { description: { contains: search, mode: 'insensitive' } }
      ];
    }

    // Non-admin users can only see tasks from projects they're members of
    if (!req.user.isAdmin) {
      where.project = {
        members: {
          some: { userId: req.user.id }
        }
      };
    }

    const tasks = await prisma.task.findMany({
      where,
      include: {
        project: {
          select: { id: true, name: true }
        },
        createdBy: {
          select: { id: true, name: true, email: true }
        },
        assignedTo: {
          select: { id: true, name: true, email: true }
        },
        _count: {
          select: { comments: true, attachments: true }
        }
      },
      orderBy: { createdAt: 'desc' }
    });

    res.json(tasks);
  } catch (error) {
    logger.error('Error fetching tasks:', error);
    res.status(500).json({ error: 'Failed to fetch tasks' });
  }
});

// Create task
router.post('/', authenticateToken, async (req, res) => {
  try {
    const { 
      title, 
      description, 
      projectId, 
      priority, 
      dueDate, 
      estimatedHours, 
      assignedToId 
    } = req.body;

    // Verify user has access to the project
    if (!req.user.isAdmin) {
      const projectMember = await prisma.projectMember.findFirst({
        where: {
          projectId,
          userId: req.user.id
        }
      });

      if (!projectMember) {
        return res.status(403).json({ error: 'Access denied to this project' });
      }
    }

    const task = await prisma.task.create({
      data: {
        title,
        description,
        projectId,
        priority: priority || 'MEDIUM',
        status: 'TODO',
        dueDate: dueDate ? new Date(dueDate) : null,
        estimatedHours: estimatedHours ? parseFloat(estimatedHours) : null,
        createdById: req.user.id,
        assignedToId: assignedToId || req.user.id
      },
      include: {
        project: {
          select: { id: true, name: true }
        },
        createdBy: {
          select: { id: true, name: true, email: true }
        },
        assignedTo: {
          select: { id: true, name: true, email: true }
        }
      }
    });

    logger.info(`Task created: ${task.title} by ${req.user.email}`);
    res.status(201).json(task);
  } catch (error) {
    logger.error('Error creating task:', error);
    res.status(500).json({ error: 'Failed to create task' });
  }
});

// Update task
router.put('/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { 
      title, 
      description, 
      status, 
      priority, 
      dueDate, 
      estimatedHours, 
      actualHours,
      assignedToId 
    } = req.body;

    // Check if task exists and user has access
    const existingTask = await prisma.task.findUnique({
      where: { id },
      include: {
        project: {
          include: {
            members: true
          }
        }
      }
    });

    if (!existingTask) {
      return res.status(404).json({ error: 'Task not found' });
    }

    // Check access permissions
    if (!req.user.isAdmin) {
      const hasAccess = existingTask.project.members.some(
        member => member.userId === req.user.id
      );
      
      if (!hasAccess) {
        return res.status(403).json({ error: 'Access denied to this task' });
      }
    }

    const updateData = {};
    if (title !== undefined) updateData.title = title;
    if (description !== undefined) updateData.description = description;
    if (status !== undefined) updateData.status = status;
    if (priority !== undefined) updateData.priority = priority;
    if (dueDate !== undefined) updateData.dueDate = dueDate ? new Date(dueDate) : null;
    if (estimatedHours !== undefined) updateData.estimatedHours = estimatedHours ? parseFloat(estimatedHours) : null;
    if (actualHours !== undefined) updateData.actualHours = actualHours ? parseFloat(actualHours) : null;
    if (assignedToId !== undefined) updateData.assignedToId = assignedToId;

    const task = await prisma.task.update({
      where: { id },
      data: updateData,
      include: {
        project: {
          select: { id: true, name: true }
        },
        createdBy: {
          select: { id: true, name: true, email: true }
        },
        assignedTo: {
          select: { id: true, name: true, email: true }
        }
      }
    });

    logger.info(`Task updated: ${task.title} by ${req.user.email}`);
    res.json(task);
  } catch (error) {
    logger.error('Error updating task:', error);
    res.status(500).json({ error: 'Failed to update task' });
  }
});

// Delete task
router.delete('/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;

    // Check if task exists and user has access
    const existingTask = await prisma.task.findUnique({
      where: { id },
      include: {
        project: {
          include: {
            members: true
          }
        }
      }
    });

    if (!existingTask) {
      return res.status(404).json({ error: 'Task not found' });
    }

    // Check access permissions (only admin or task creator can delete)
    if (!req.user.isAdmin && existingTask.createdById !== req.user.id) {
      return res.status(403).json({ error: 'Only task creator or admin can delete tasks' });
    }

    await prisma.task.delete({
      where: { id }
    });

    logger.info(`Task deleted: ${existingTask.title} by ${req.user.email}`);
    res.json({ message: 'Task deleted successfully' });
  } catch (error) {
    logger.error('Error deleting task:', error);
    res.status(500).json({ error: 'Failed to delete task' });
  }
});

module.exports = router;
