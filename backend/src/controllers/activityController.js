const { PrismaClient } = require('@prisma/client');
const logger = require('../config/logger');
const activityService = require('../services/activityService');

const prisma = new PrismaClient();

class ActivityController {
  // Get project activities
  async getProjectActivities(req, res) {
    try {
      const { projectId } = req.params;
      const { userId, action, page, limit, startDate, endDate } = req.query;

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

      const options = {
        userId,
        action,
        page: page ? parseInt(page) : 1,
        limit: limit ? parseInt(limit) : 50,
        startDate,
        endDate
      };

      const result = await activityService.getProjectActivities(projectId, options);
      res.json(result);
    } catch (error) {
      logger.error('Error getting project activities:', error);
      res.status(500).json({ error: 'Failed to get project activities' });
    }
  }

  // Get task activities
  async getTaskActivities(req, res) {
    try {
      const { taskId } = req.params;
      const { userId, action, page, limit } = req.query;

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

      const options = {
        userId,
        action,
        page: page ? parseInt(page) : 1,
        limit: limit ? parseInt(limit) : 20
      };

      const result = await activityService.getTaskActivities(taskId, options);
      res.json(result);
    } catch (error) {
      logger.error('Error getting task activities:', error);
      res.status(500).json({ error: 'Failed to get task activities' });
    }
  }

  // Get user activities
  async getUserActivities(req, res) {
    try {
      const { userId } = req.params;
      const { projectId, action, page, limit, startDate, endDate } = req.query;

      // Users can only get their own activities unless they're admin
      const targetUserId = req.user.isAdmin && userId ? userId : req.user.id;

      const options = {
        projectId,
        action,
        page: page ? parseInt(page) : 1,
        limit: limit ? parseInt(limit) : 50,
        startDate,
        endDate
      };

      const result = await activityService.getUserActivities(targetUserId, options);
      res.json(result);
    } catch (error) {
      logger.error('Error getting user activities:', error);
      res.status(500).json({ error: 'Failed to get user activities' });
    }
  }

  // Get activity statistics
  async getActivityStats(req, res) {
    try {
      const { projectId } = req.params;
      const { startDate, endDate, userId } = req.query;

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

      const options = {
        startDate,
        endDate,
        userId
      };

      const stats = await activityService.getActivityStats(projectId, options);
      res.json(stats);
    } catch (error) {
      logger.error('Error getting activity stats:', error);
      res.status(500).json({ error: 'Failed to get activity statistics' });
    }
  }

  // Get recent activities (dashboard)
  async getRecentActivities(req, res) {
    try {
      const { limit = 20 } = req.query;

      // Get user's project memberships
      const projectMemberships = await prisma.projectMember.findMany({
        where: { userId: req.user.id },
        select: { projectId: true }
      });

      const projectIds = projectMemberships.map(m => m.projectId);

      if (projectIds.length === 0) {
        return res.json({ activities: [], pagination: { page: 1, limit: parseInt(limit), total: 0, pages: 0 } });
      }

      // Get recent activities from user's projects
      const activities = await prisma.activityLog.findMany({
        where: {
          projectId: { in: projectIds }
        },
        include: {
          user: { select: { id: true, name: true, email: true } },
          task: { select: { id: true, title: true } },
          project: { select: { id: true, name: true } }
        },
        orderBy: { createdAt: 'desc' },
        take: parseInt(limit)
      });

      const result = {
        activities: activities.map(a => activityService.formatActivityResponse(a)),
        pagination: {
          page: 1,
          limit: parseInt(limit),
          total: activities.length,
          pages: 1
        }
      };

      res.json(result);
    } catch (error) {
      logger.error('Error getting recent activities:', error);
      res.status(500).json({ error: 'Failed to get recent activities' });
    }
  }

  // Get activity feed for dashboard
  async getActivityFeed(req, res) {
    try {
      const { page = 1, limit = 30, projectId } = req.query;

      let projectIds = [];

      if (projectId) {
        // Verify user has access to the specific project
        const membership = await prisma.projectMember.findFirst({
          where: {
            projectId,
            userId: req.user.id
          }
        });

        if (!membership && !req.user.isAdmin) {
          return res.status(403).json({ error: 'Access denied to this project' });
        }

        projectIds = [projectId];
      } else {
        // Get user's project memberships
        const projectMemberships = await prisma.projectMember.findMany({
          where: { userId: req.user.id },
          select: { projectId: true }
        });

        projectIds = projectMemberships.map(m => m.projectId);
      }

      if (projectIds.length === 0) {
        return res.json({
          activities: [],
          pagination: { page: parseInt(page), limit: parseInt(limit), total: 0, pages: 0 }
        });
      }

      const [activities, totalCount] = await Promise.all([
        prisma.activityLog.findMany({
          where: {
            projectId: { in: projectIds }
          },
          include: {
            user: { select: { id: true, name: true, email: true } },
            task: { select: { id: true, title: true } },
            project: { select: { id: true, name: true } }
          },
          orderBy: { createdAt: 'desc' },
          skip: (parseInt(page) - 1) * parseInt(limit),
          take: parseInt(limit)
        }),
        prisma.activityLog.count({
          where: {
            projectId: { in: projectIds }
          }
        })
      ]);

      const result = {
        activities: activities.map(a => activityService.formatActivityResponse(a)),
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total: totalCount,
          pages: Math.ceil(totalCount / parseInt(limit))
        }
      };

      res.json(result);
    } catch (error) {
      logger.error('Error getting activity feed:', error);
      res.status(500).json({ error: 'Failed to get activity feed' });
    }
  }

  // Log custom activity (admin only)
  async logActivity(req, res) {
    try {
      if (!req.user.isAdmin) {
        return res.status(403).json({ error: 'Only administrators can log custom activities' });
      }

      const activityData = {
        ...req.body,
        userId: req.body.userId || req.user.id
      };

      const activity = await activityService.logActivity(activityData);

      logger.info(`Custom activity logged by admin ${req.user.email}`);
      res.status(201).json(activity);
    } catch (error) {
      logger.error('Error logging custom activity:', error);
      res.status(400).json({ error: error.message });
    }
  }
}

module.exports = new ActivityController();
