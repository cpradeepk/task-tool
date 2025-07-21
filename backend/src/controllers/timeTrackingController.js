const { PrismaClient } = require('@prisma/client');
const logger = require('../config/logger');
const timeTrackingService = require('../services/timeTrackingService');

const prisma = new PrismaClient();

class TimeTrackingController {
  // Start timer for a task
  async startTimer(req, res) {
    try {
      const { taskId, description } = req.body;
      
      const timeEntry = await timeTrackingService.startTimer(req.user.id, taskId, description);
      
      logger.info(`Timer started for task ${taskId} by user ${req.user.email}`);
      res.status(201).json(timeEntry);
    } catch (error) {
      logger.error('Error starting timer:', error);
      res.status(400).json({ error: error.message });
    }
  }

  // Stop active timer
  async stopTimer(req, res) {
    try {
      const timeEntry = await timeTrackingService.stopTimer(req.user.id);
      
      logger.info(`Timer stopped by user ${req.user.email}`);
      res.json(timeEntry);
    } catch (error) {
      logger.error('Error stopping timer:', error);
      res.status(400).json({ error: error.message });
    }
  }

  // Get active timer
  async getActiveTimer(req, res) {
    try {
      const activeTimer = await timeTrackingService.getActiveTimer(req.user.id);
      res.json(activeTimer);
    } catch (error) {
      logger.error('Error getting active timer:', error);
      res.status(500).json({ error: 'Failed to get active timer' });
    }
  }

  // Get user time report
  async getUserTimeReport(req, res) {
    try {
      const { startDate, endDate, userId } = req.query;
      
      // Users can only get their own reports unless they're admin
      const targetUserId = req.user.isAdmin && userId ? userId : req.user.id;
      
      if (!startDate || !endDate) {
        return res.status(400).json({ error: 'Start date and end date are required' });
      }

      const report = await timeTrackingService.getUserTimeReport(targetUserId, startDate, endDate);
      res.json(report);
    } catch (error) {
      logger.error('Error getting user time report:', error);
      res.status(500).json({ error: 'Failed to get time report' });
    }
  }

  // Get project time report
  async getProjectTimeReport(req, res) {
    try {
      const { projectId } = req.params;
      const { startDate, endDate } = req.query;

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

      if (!startDate || !endDate) {
        return res.status(400).json({ error: 'Start date and end date are required' });
      }

      const report = await timeTrackingService.getProjectTimeReport(projectId, startDate, endDate);
      res.json(report);
    } catch (error) {
      logger.error('Error getting project time report:', error);
      res.status(500).json({ error: 'Failed to get project time report' });
    }
  }

  // Get PERT vs Actual comparison
  async getPERTComparison(req, res) {
    try {
      const { projectId } = req.params;

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

      const comparison = await timeTrackingService.getPERTComparison(projectId);
      res.json(comparison);
    } catch (error) {
      logger.error('Error getting PERT comparison:', error);
      res.status(500).json({ error: 'Failed to get PERT comparison' });
    }
  }

  // Get time analytics
  async getTimeAnalytics(req, res) {
    try {
      const { projectId } = req.params;
      const { period } = req.query;

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

      const analytics = await timeTrackingService.getTimeAnalytics(projectId, period);
      res.json(analytics);
    } catch (error) {
      logger.error('Error getting time analytics:', error);
      res.status(500).json({ error: 'Failed to get time analytics' });
    }
  }

  // Update time entry
  async updateTimeEntry(req, res) {
    try {
      const { id } = req.params;
      const { description, hours, date } = req.body;

      // Verify user owns the time entry or is admin
      const timeEntry = await prisma.timeEntry.findFirst({
        where: {
          id,
          OR: [
            { userId: req.user.id },
            { task: { project: { members: { some: { userId: req.user.id, role: { in: ['OWNER', 'ADMIN'] } } } } } }
          ]
        }
      });

      if (!timeEntry) {
        return res.status(404).json({ error: 'Time entry not found or access denied' });
      }

      const updateData = {};
      if (description !== undefined) updateData.description = description;
      if (hours !== undefined) updateData.hours = parseFloat(hours);
      if (date !== undefined) updateData.date = new Date(date);

      const updatedTimeEntry = await prisma.timeEntry.update({
        where: { id },
        data: updateData,
        include: {
          task: {
            select: { id: true, title: true }
          },
          user: {
            select: { id: true, name: true, email: true }
          }
        }
      });

      // Update task's actual hours
      await timeTrackingService.updateTaskActualHours(timeEntry.taskId);

      logger.info(`Time entry updated: ${id} by ${req.user.email}`);
      res.json(updatedTimeEntry);
    } catch (error) {
      logger.error('Error updating time entry:', error);
      res.status(500).json({ error: 'Failed to update time entry' });
    }
  }

  // Delete time entry
  async deleteTimeEntry(req, res) {
    try {
      const { id } = req.params;

      // Verify user owns the time entry or is admin
      const timeEntry = await prisma.timeEntry.findFirst({
        where: {
          id,
          OR: [
            { userId: req.user.id },
            { task: { project: { members: { some: { userId: req.user.id, role: { in: ['OWNER', 'ADMIN'] } } } } } }
          ]
        }
      });

      if (!timeEntry) {
        return res.status(404).json({ error: 'Time entry not found or access denied' });
      }

      await prisma.timeEntry.delete({
        where: { id }
      });

      // Update task's actual hours
      await timeTrackingService.updateTaskActualHours(timeEntry.taskId);

      logger.info(`Time entry deleted: ${id} by ${req.user.email}`);
      res.status(204).send();
    } catch (error) {
      logger.error('Error deleting time entry:', error);
      res.status(500).json({ error: 'Failed to delete time entry' });
    }
  }

  // Get time entries for a task
  async getTaskTimeEntries(req, res) {
    try {
      const { taskId } = req.params;

      // Verify user has access to the task
      const task = await prisma.task.findFirst({
        where: {
          id: taskId,
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
        return res.status(404).json({ error: 'Task not found or access denied' });
      }

      const timeEntries = await prisma.timeEntry.findMany({
        where: { taskId },
        include: {
          user: {
            select: { id: true, name: true, email: true }
          }
        },
        orderBy: { date: 'desc' }
      });

      res.json(timeEntries);
    } catch (error) {
      logger.error('Error getting task time entries:', error);
      res.status(500).json({ error: 'Failed to get task time entries' });
    }
  }

  // Get user's recent time entries
  async getRecentTimeEntries(req, res) {
    try {
      const { limit = 10 } = req.query;

      const timeEntries = await prisma.timeEntry.findMany({
        where: { 
          userId: req.user.id,
          endTime: { not: null }
        },
        include: {
          task: {
            select: {
              id: true,
              title: true,
              project: { select: { id: true, name: true } }
            }
          }
        },
        orderBy: { date: 'desc' },
        take: parseInt(limit)
      });

      res.json(timeEntries);
    } catch (error) {
      logger.error('Error getting recent time entries:', error);
      res.status(500).json({ error: 'Failed to get recent time entries' });
    }
  }
}

module.exports = new TimeTrackingController();
