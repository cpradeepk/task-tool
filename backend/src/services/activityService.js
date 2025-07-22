const { PrismaClient } = require('@prisma/client');
const logger = require('../config/logger');
const socketServer = require('../socket/socketServer');

const prisma = new PrismaClient();

class ActivityService {
  // Log an activity
  async logActivity(activityData) {
    try {
      const {
        userId,
        action,
        description,
        metadata = null,
        taskId = null,
        projectId = null
      } = activityData;

      const activity = await prisma.activityLog.create({
        data: {
          userId,
          action,
          description,
          metadata,
          taskId,
          projectId
        },
        include: {
          user: { select: { id: true, name: true, email: true } },
          task: { select: { id: true, title: true } },
          project: { select: { id: true, name: true } }
        }
      });

      const formattedActivity = this.formatActivityResponse(activity);

      // Emit activity to relevant users
      if (projectId) {
        socketServer.emitToProject(projectId, 'new_activity', formattedActivity);
      }

      if (taskId) {
        socketServer.emitToTask(taskId, 'new_activity', formattedActivity);
      }

      logger.info(`Activity logged: ${action} by user ${userId}`);
      return formattedActivity;
    } catch (error) {
      logger.error('Error logging activity:', error);
      throw error;
    }
  }

  // Get activities for a project
  async getProjectActivities(projectId, options = {}) {
    try {
      const {
        userId,
        action,
        page = 1,
        limit = 50,
        startDate,
        endDate
      } = options;

      const where = { projectId };

      if (userId) {
        where.userId = userId;
      }

      if (action) {
        where.action = action;
      }

      if (startDate || endDate) {
        where.createdAt = {};
        if (startDate) where.createdAt.gte = new Date(startDate);
        if (endDate) where.createdAt.lte = new Date(endDate);
      }

      const [activities, totalCount] = await Promise.all([
        prisma.activityLog.findMany({
          where,
          include: {
            user: { select: { id: true, name: true, email: true } },
            task: { select: { id: true, title: true } },
            project: { select: { id: true, name: true } }
          },
          orderBy: { createdAt: 'desc' },
          skip: (page - 1) * limit,
          take: limit
        }),
        prisma.activityLog.count({ where })
      ]);

      return {
        activities: activities.map(a => this.formatActivityResponse(a)),
        pagination: {
          page,
          limit,
          total: totalCount,
          pages: Math.ceil(totalCount / limit)
        }
      };
    } catch (error) {
      logger.error('Error getting project activities:', error);
      throw error;
    }
  }

  // Get activities for a task
  async getTaskActivities(taskId, options = {}) {
    try {
      const {
        userId,
        action,
        page = 1,
        limit = 20
      } = options;

      const where = { taskId };

      if (userId) {
        where.userId = userId;
      }

      if (action) {
        where.action = action;
      }

      const [activities, totalCount] = await Promise.all([
        prisma.activityLog.findMany({
          where,
          include: {
            user: { select: { id: true, name: true, email: true } },
            task: { select: { id: true, title: true } },
            project: { select: { id: true, name: true } }
          },
          orderBy: { createdAt: 'desc' },
          skip: (page - 1) * limit,
          take: limit
        }),
        prisma.activityLog.count({ where })
      ]);

      return {
        activities: activities.map(a => this.formatActivityResponse(a)),
        pagination: {
          page,
          limit,
          total: totalCount,
          pages: Math.ceil(totalCount / limit)
        }
      };
    } catch (error) {
      logger.error('Error getting task activities:', error);
      throw error;
    }
  }

  // Get user activities
  async getUserActivities(userId, options = {}) {
    try {
      const {
        projectId,
        action,
        page = 1,
        limit = 50,
        startDate,
        endDate
      } = options;

      const where = { userId };

      if (projectId) {
        where.projectId = projectId;
      }

      if (action) {
        where.action = action;
      }

      if (startDate || endDate) {
        where.createdAt = {};
        if (startDate) where.createdAt.gte = new Date(startDate);
        if (endDate) where.createdAt.lte = new Date(endDate);
      }

      const [activities, totalCount] = await Promise.all([
        prisma.activityLog.findMany({
          where,
          include: {
            user: { select: { id: true, name: true, email: true } },
            task: { select: { id: true, title: true } },
            project: { select: { id: true, name: true } }
          },
          orderBy: { createdAt: 'desc' },
          skip: (page - 1) * limit,
          take: limit
        }),
        prisma.activityLog.count({ where })
      ]);

      return {
        activities: activities.map(a => this.formatActivityResponse(a)),
        pagination: {
          page,
          limit,
          total: totalCount,
          pages: Math.ceil(totalCount / limit)
        }
      };
    } catch (error) {
      logger.error('Error getting user activities:', error);
      throw error;
    }
  }

  // Get activity statistics
  async getActivityStats(projectId, options = {}) {
    try {
      const {
        startDate,
        endDate,
        userId
      } = options;

      const where = { projectId };

      if (userId) {
        where.userId = userId;
      }

      if (startDate || endDate) {
        where.createdAt = {};
        if (startDate) where.createdAt.gte = new Date(startDate);
        if (endDate) where.createdAt.lte = new Date(endDate);
      }

      const [totalActivities, actionStats, userStats, dailyStats] = await Promise.all([
        prisma.activityLog.count({ where }),
        
        prisma.activityLog.groupBy({
          by: ['action'],
          where,
          _count: { action: true }
        }),
        
        prisma.activityLog.groupBy({
          by: ['userId'],
          where,
          _count: { userId: true },
          orderBy: { _count: { userId: 'desc' } },
          take: 10
        }),
        
        prisma.$queryRaw`
          SELECT DATE(createdAt) as date, COUNT(*) as count
          FROM activity_logs
          WHERE projectId = ${projectId}
          ${startDate ? `AND createdAt >= ${startDate}` : ''}
          ${endDate ? `AND createdAt <= ${endDate}` : ''}
          GROUP BY DATE(createdAt)
          ORDER BY date DESC
          LIMIT 30
        `
      ]);

      // Get user details for user stats
      const userIds = userStats.map(stat => stat.userId);
      const users = await prisma.user.findMany({
        where: { id: { in: userIds } },
        select: { id: true, name: true, email: true }
      });

      const userMap = users.reduce((acc, user) => {
        acc[user.id] = user;
        return acc;
      }, {});

      return {
        total: totalActivities,
        byAction: actionStats.reduce((acc, stat) => {
          acc[stat.action] = stat._count.action;
          return acc;
        }, {}),
        byUser: userStats.map(stat => ({
          user: userMap[stat.userId],
          count: stat._count.userId
        })),
        daily: dailyStats
      };
    } catch (error) {
      logger.error('Error getting activity stats:', error);
      throw error;
    }
  }

  // Activity logging helpers for common actions
  async logTaskCreated(userId, taskId, projectId, taskTitle) {
    return this.logActivity({
      userId,
      action: 'TASK_CREATED',
      description: `Created task "${taskTitle}"`,
      taskId,
      projectId,
      metadata: { taskTitle }
    });
  }

  async logTaskUpdated(userId, taskId, projectId, taskTitle, changes) {
    return this.logActivity({
      userId,
      action: 'TASK_UPDATED',
      description: `Updated task "${taskTitle}"`,
      taskId,
      projectId,
      metadata: { taskTitle, changes }
    });
  }

  async logTaskCompleted(userId, taskId, projectId, taskTitle) {
    return this.logActivity({
      userId,
      action: 'TASK_COMPLETED',
      description: `Completed task "${taskTitle}"`,
      taskId,
      projectId,
      metadata: { taskTitle }
    });
  }

  async logTaskDeleted(userId, taskId, projectId, taskTitle) {
    return this.logActivity({
      userId,
      action: 'TASK_DELETED',
      description: `Deleted task "${taskTitle}"`,
      taskId,
      projectId,
      metadata: { taskTitle }
    });
  }

  async logTaskAssigned(userId, taskId, projectId, taskTitle, assigneeId, assigneeName) {
    return this.logActivity({
      userId,
      action: 'TASK_ASSIGNED',
      description: `Assigned task "${taskTitle}" to ${assigneeName}`,
      taskId,
      projectId,
      metadata: { taskTitle, assigneeId, assigneeName }
    });
  }

  async logCommentAdded(userId, taskId, projectId, taskTitle, commentContent) {
    return this.logActivity({
      userId,
      action: 'COMMENT_ADDED',
      description: `Added comment to task "${taskTitle}"`,
      taskId,
      projectId,
      metadata: { taskTitle, commentContent: commentContent.substring(0, 100) }
    });
  }

  async logFileUploaded(userId, taskId, projectId, fileName, fileSize) {
    return this.logActivity({
      userId,
      action: 'FILE_UPLOADED',
      description: `Uploaded file "${fileName}"`,
      taskId,
      projectId,
      metadata: { fileName, fileSize }
    });
  }

  async logTimeLogged(userId, taskId, projectId, taskTitle, hours) {
    return this.logActivity({
      userId,
      action: 'TIME_LOGGED',
      description: `Logged ${hours} hours on task "${taskTitle}"`,
      taskId,
      projectId,
      metadata: { taskTitle, hours }
    });
  }

  async logProjectCreated(userId, projectId, projectName) {
    return this.logActivity({
      userId,
      action: 'PROJECT_CREATED',
      description: `Created project "${projectName}"`,
      projectId,
      metadata: { projectName }
    });
  }

  async logProjectUpdated(userId, projectId, projectName, changes) {
    return this.logActivity({
      userId,
      action: 'PROJECT_UPDATED',
      description: `Updated project "${projectName}"`,
      projectId,
      metadata: { projectName, changes }
    });
  }

  async logUserJoined(userId, projectId, projectName, newUserId, newUserName) {
    return this.logActivity({
      userId,
      action: 'USER_JOINED',
      description: `${newUserName} joined the project`,
      projectId,
      metadata: { projectName, newUserId, newUserName }
    });
  }

  async logChannelCreated(userId, projectId, channelName) {
    return this.logActivity({
      userId,
      action: 'CHANNEL_CREATED',
      description: `Created channel "${channelName}"`,
      projectId,
      metadata: { channelName }
    });
  }

  async logMessageSent(userId, projectId, channelName, messageContent) {
    return this.logActivity({
      userId,
      action: 'MESSAGE_SENT',
      description: `Sent message in channel "${channelName}"`,
      projectId,
      metadata: { channelName, messageContent: messageContent.substring(0, 50) }
    });
  }

  // Format activity response
  formatActivityResponse(activity) {
    return {
      id: activity.id,
      action: activity.action,
      description: activity.description,
      metadata: activity.metadata,
      createdAt: activity.createdAt,
      user: activity.user,
      task: activity.task,
      project: activity.project
    };
  }

  // Log task created
  async logTaskCreated(userId, taskId, projectId, taskTitle) {
    return this.logActivity({
      action: 'TASK_CREATED',
      description: `created task "${taskTitle}"`,
      userId,
      taskId,
      projectId,
      metadata: { taskTitle }
    });
  }

  // Log task updated
  async logTaskUpdated(userId, taskId, projectId, taskTitle) {
    return this.logActivity({
      action: 'TASK_UPDATED',
      description: `updated task "${taskTitle}"`,
      userId,
      taskId,
      projectId,
      metadata: { taskTitle }
    });
  }

  // Log task assigned
  async logTaskAssigned(userId, taskId, projectId, taskTitle, assigneeId) {
    return this.logActivity({
      action: 'TASK_ASSIGNED',
      description: `assigned task "${taskTitle}" to user`,
      userId,
      taskId,
      projectId,
      metadata: { taskTitle, assigneeId }
    });
  }

  // Log task status changed
  async logTaskStatusChanged(userId, taskId, projectId, taskTitle, oldStatus, newStatus) {
    return this.logActivity({
      action: 'STATUS_CHANGED',
      description: `changed status of task "${taskTitle}" from ${oldStatus} to ${newStatus}`,
      userId,
      taskId,
      projectId,
      metadata: { taskTitle, oldStatus, newStatus }
    });
  }

  // Log task priority changed
  async logTaskPriorityChanged(userId, taskId, projectId, taskTitle, oldPriority, newPriority) {
    return this.logActivity({
      action: 'PRIORITY_CHANGED',
      description: `changed priority of task "${taskTitle}" from ${oldPriority} to ${newPriority}`,
      userId,
      taskId,
      projectId,
      metadata: { taskTitle, oldPriority, newPriority }
    });
  }

  // Log dependency added
  async logDependencyAdded(userId, taskId, projectId, taskTitle, dependsOnTaskTitle) {
    return this.logActivity({
      action: 'DEPENDENCY_ADDED',
      description: `added dependency: task "${taskTitle}" now depends on "${dependsOnTaskTitle}"`,
      userId,
      taskId,
      projectId,
      metadata: { taskTitle, dependsOnTaskTitle }
    });
  }

  // Log dependency removed
  async logDependencyRemoved(userId, taskId, projectId, taskTitle, dependsOnTaskTitle) {
    return this.logActivity({
      action: 'DEPENDENCY_REMOVED',
      description: `removed dependency: task "${taskTitle}" no longer depends on "${dependsOnTaskTitle}"`,
      userId,
      taskId,
      projectId,
      metadata: { taskTitle, dependsOnTaskTitle }
    });
  }

  // Log time logged
  async logTimeLogged(userId, taskId, projectId, taskTitle, hours, description) {
    return this.logActivity({
      action: 'TIME_LOGGED',
      description: `logged ${hours} hours on task "${taskTitle}"${description ? `: ${description}` : ''}`,
      userId,
      taskId,
      projectId,
      metadata: { taskTitle, hours, description }
    });
  }
}

module.exports = new ActivityService();
