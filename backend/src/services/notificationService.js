const { PrismaClient } = require('@prisma/client');
const logger = require('../config/logger');
const socketServer = require('../socket/socketServer');

const prisma = new PrismaClient();

class NotificationService {
  // Create a notification
  async createNotification(notificationData) {
    try {
      const {
        userId,
        title,
        message,
        type = 'INFO',
        data = null,
        taskId = null,
        projectId = null
      } = notificationData;

      const notification = await prisma.notification.create({
        data: {
          userId,
          title,
          message,
          type,
          data,
          taskId,
          projectId
        },
        include: {
          task: { select: { id: true, title: true } },
          project: { select: { id: true, name: true } }
        }
      });

      // Emit notification via socket if user is connected
      socketServer.emitToUser(userId, 'new_notification', this.formatNotificationResponse(notification));

      logger.info(`Notification created for user ${userId}: ${title}`);
      return this.formatNotificationResponse(notification);
    } catch (error) {
      logger.error('Error creating notification:', error);
      throw error;
    }
  }

  // Create bulk notifications
  async createBulkNotifications(notifications) {
    try {
      const createdNotifications = await prisma.notification.createMany({
        data: notifications
      });

      // Get the created notifications with relations
      const notificationsWithRelations = await prisma.notification.findMany({
        where: {
          id: { in: createdNotifications.map(n => n.id) }
        },
        include: {
          task: { select: { id: true, title: true } },
          project: { select: { id: true, name: true } }
        }
      });

      // Emit notifications via socket
      notificationsWithRelations.forEach(notification => {
        socketServer.emitToUser(notification.userId, 'new_notification', this.formatNotificationResponse(notification));
      });

      logger.info(`${notifications.length} bulk notifications created`);
      return notificationsWithRelations.map(n => this.formatNotificationResponse(n));
    } catch (error) {
      logger.error('Error creating bulk notifications:', error);
      throw error;
    }
  }

  // Get notifications for a user
  async getUserNotifications(userId, options = {}) {
    try {
      const {
        isRead,
        type,
        page = 1,
        limit = 20,
        projectId,
        taskId
      } = options;

      const where = { userId };

      if (isRead !== undefined) {
        where.isRead = isRead;
      }

      if (type) {
        where.type = type;
      }

      if (projectId) {
        where.projectId = projectId;
      }

      if (taskId) {
        where.taskId = taskId;
      }

      const [notifications, totalCount] = await Promise.all([
        prisma.notification.findMany({
          where,
          include: {
            task: { select: { id: true, title: true } },
            project: { select: { id: true, name: true } }
          },
          orderBy: { createdAt: 'desc' },
          skip: (page - 1) * limit,
          take: limit
        }),
        prisma.notification.count({ where })
      ]);

      return {
        notifications: notifications.map(n => this.formatNotificationResponse(n)),
        pagination: {
          page,
          limit,
          total: totalCount,
          pages: Math.ceil(totalCount / limit)
        }
      };
    } catch (error) {
      logger.error('Error getting user notifications:', error);
      throw error;
    }
  }

  // Mark notification as read
  async markAsRead(userId, notificationId) {
    try {
      const notification = await prisma.notification.findFirst({
        where: {
          id: notificationId,
          userId
        }
      });

      if (!notification) {
        throw new Error('Notification not found');
      }

      const updatedNotification = await prisma.notification.update({
        where: { id: notificationId },
        data: {
          isRead: true,
          readAt: new Date()
        },
        include: {
          task: { select: { id: true, title: true } },
          project: { select: { id: true, name: true } }
        }
      });

      // Emit update via socket
      socketServer.emitToUser(userId, 'notification_read', {
        notificationId,
        readAt: updatedNotification.readAt
      });

      logger.info(`Notification marked as read: ${notificationId} by user ${userId}`);
      return this.formatNotificationResponse(updatedNotification);
    } catch (error) {
      logger.error('Error marking notification as read:', error);
      throw error;
    }
  }

  // Mark all notifications as read
  async markAllAsRead(userId) {
    try {
      const result = await prisma.notification.updateMany({
        where: {
          userId,
          isRead: false
        },
        data: {
          isRead: true,
          readAt: new Date()
        }
      });

      // Emit update via socket
      socketServer.emitToUser(userId, 'all_notifications_read', {
        count: result.count,
        readAt: new Date()
      });

      logger.info(`${result.count} notifications marked as read for user ${userId}`);
      return { count: result.count };
    } catch (error) {
      logger.error('Error marking all notifications as read:', error);
      throw error;
    }
  }

  // Delete notification
  async deleteNotification(userId, notificationId) {
    try {
      const notification = await prisma.notification.findFirst({
        where: {
          id: notificationId,
          userId
        }
      });

      if (!notification) {
        throw new Error('Notification not found');
      }

      await prisma.notification.delete({
        where: { id: notificationId }
      });

      // Emit deletion via socket
      socketServer.emitToUser(userId, 'notification_deleted', { notificationId });

      logger.info(`Notification deleted: ${notificationId} by user ${userId}`);
    } catch (error) {
      logger.error('Error deleting notification:', error);
      throw error;
    }
  }

  // Get notification statistics
  async getNotificationStats(userId) {
    try {
      const [totalCount, unreadCount, typeStats] = await Promise.all([
        prisma.notification.count({ where: { userId } }),
        prisma.notification.count({ where: { userId, isRead: false } }),
        prisma.notification.groupBy({
          by: ['type'],
          where: { userId },
          _count: { type: true }
        })
      ]);

      return {
        total: totalCount,
        unread: unreadCount,
        byType: typeStats.reduce((acc, stat) => {
          acc[stat.type] = stat._count.type;
          return acc;
        }, {})
      };
    } catch (error) {
      logger.error('Error getting notification stats:', error);
      throw error;
    }
  }

  // Task-related notification helpers
  async notifyTaskAssigned(taskId, assigneeId, assignedById) {
    try {
      const task = await prisma.task.findUnique({
        where: { id: taskId },
        include: {
          project: { select: { id: true, name: true } },
          createdBy: { select: { id: true, name: true } }
        }
      });

      if (!task) return;

      const assignedBy = await prisma.user.findUnique({
        where: { id: assignedById },
        select: { name: true }
      });

      await this.createNotification({
        userId: assigneeId,
        title: 'Task Assigned',
        message: `You have been assigned to task "${task.title}" by ${assignedBy?.name || 'Unknown'}`,
        type: 'TASK_ASSIGNED',
        taskId,
        projectId: task.projectId,
        data: {
          taskTitle: task.title,
          assignedBy: assignedBy?.name,
          projectName: task.project?.name
        }
      });
    } catch (error) {
      logger.error('Error creating task assignment notification:', error);
    }
  }

  async notifyTaskUpdated(taskId, updatedById, changes) {
    try {
      const task = await prisma.task.findUnique({
        where: { id: taskId },
        include: {
          project: { select: { id: true, name: true } },
          mainAssignee: { select: { id: true, name: true } },
          assignments: {
            include: {
              user: { select: { id: true, name: true } }
            }
          }
        }
      });

      if (!task) return;

      const updatedBy = await prisma.user.findUnique({
        where: { id: updatedById },
        select: { name: true }
      });

      // Notify assignees
      const notifyUserIds = new Set();
      if (task.mainAssigneeId && task.mainAssigneeId !== updatedById) {
        notifyUserIds.add(task.mainAssigneeId);
      }
      task.assignments.forEach(assignment => {
        if (assignment.userId !== updatedById) {
          notifyUserIds.add(assignment.userId);
        }
      });

      const changeDescription = Object.keys(changes).join(', ');

      for (const userId of notifyUserIds) {
        await this.createNotification({
          userId,
          title: 'Task Updated',
          message: `Task "${task.title}" was updated by ${updatedBy?.name || 'Unknown'}. Changes: ${changeDescription}`,
          type: 'TASK_UPDATED',
          taskId,
          projectId: task.projectId,
          data: {
            taskTitle: task.title,
            updatedBy: updatedBy?.name,
            changes,
            projectName: task.project?.name
          }
        });
      }
    } catch (error) {
      logger.error('Error creating task update notification:', error);
    }
  }

  async notifyTaskCompleted(taskId, completedById) {
    try {
      const task = await prisma.task.findUnique({
        where: { id: taskId },
        include: {
          project: { select: { id: true, name: true } },
          createdBy: { select: { id: true, name: true } }
        }
      });

      if (!task) return;

      const completedBy = await prisma.user.findUnique({
        where: { id: completedById },
        select: { name: true }
      });

      // Notify task creator if different from completer
      if (task.createdById !== completedById) {
        await this.createNotification({
          userId: task.createdById,
          title: 'Task Completed',
          message: `Task "${task.title}" has been completed by ${completedBy?.name || 'Unknown'}`,
          type: 'TASK_COMPLETED',
          taskId,
          projectId: task.projectId,
          data: {
            taskTitle: task.title,
            completedBy: completedBy?.name,
            projectName: task.project?.name
          }
        });
      }
    } catch (error) {
      logger.error('Error creating task completion notification:', error);
    }
  }

  async notifyTaskOverdue(taskId) {
    try {
      const task = await prisma.task.findUnique({
        where: { id: taskId },
        include: {
          project: { select: { id: true, name: true } },
          mainAssignee: { select: { id: true, name: true } },
          assignments: {
            include: {
              user: { select: { id: true, name: true } }
            }
          }
        }
      });

      if (!task) return;

      // Notify assignees
      const notifyUserIds = new Set();
      if (task.mainAssigneeId) {
        notifyUserIds.add(task.mainAssigneeId);
      }
      task.assignments.forEach(assignment => {
        notifyUserIds.add(assignment.userId);
      });

      for (const userId of notifyUserIds) {
        await this.createNotification({
          userId,
          title: 'Task Overdue',
          message: `Task "${task.title}" is overdue and requires attention`,
          type: 'TASK_OVERDUE',
          taskId,
          projectId: task.projectId,
          data: {
            taskTitle: task.title,
            dueDate: task.dueDate,
            projectName: task.project?.name
          }
        });
      }
    } catch (error) {
      logger.error('Error creating task overdue notification:', error);
    }
  }

  async notifyCommentAdded(taskId, commentId, authorId) {
    try {
      const [task, comment] = await Promise.all([
        prisma.task.findUnique({
          where: { id: taskId },
          include: {
            project: { select: { id: true, name: true } },
            mainAssignee: { select: { id: true, name: true } },
            assignments: {
              include: {
                user: { select: { id: true, name: true } }
              }
            }
          }
        }),
        prisma.taskComment.findUnique({
          where: { id: commentId },
          include: {
            user: { select: { id: true, name: true } }
          }
        })
      ]);

      if (!task || !comment) return;

      // Notify assignees and task creator
      const notifyUserIds = new Set();
      if (task.createdById !== authorId) {
        notifyUserIds.add(task.createdById);
      }
      if (task.mainAssigneeId && task.mainAssigneeId !== authorId) {
        notifyUserIds.add(task.mainAssigneeId);
      }
      task.assignments.forEach(assignment => {
        if (assignment.userId !== authorId) {
          notifyUserIds.add(assignment.userId);
        }
      });

      for (const userId of notifyUserIds) {
        await this.createNotification({
          userId,
          title: 'New Comment',
          message: `${comment.user.name} commented on task "${task.title}"`,
          type: 'COMMENT_ADDED',
          taskId,
          projectId: task.projectId,
          data: {
            taskTitle: task.title,
            commentAuthor: comment.user.name,
            commentContent: comment.content.substring(0, 100),
            projectName: task.project?.name
          }
        });
      }
    } catch (error) {
      logger.error('Error creating comment notification:', error);
    }
  }

  // Format notification response
  formatNotificationResponse(notification) {
    return {
      id: notification.id,
      title: notification.title,
      message: notification.message,
      type: notification.type,
      isRead: notification.isRead,
      data: notification.data,
      createdAt: notification.createdAt,
      readAt: notification.readAt,
      task: notification.task,
      project: notification.project
    };
  }

  // Create task assigned notifications
  async createTaskAssignedNotifications(userIds, taskId, taskTitle, assignerName) {
    const notifications = userIds.map(userId => ({
      userId,
      title: 'Task Assigned',
      message: `${assignerName} assigned you to task "${taskTitle}"`,
      type: 'TASK_ASSIGNED',
      taskId,
      data: {
        taskId,
        taskTitle,
        assignerName
      }
    }));

    return this.createBulkNotifications(notifications);
  }

  // Create task completed notifications
  async createTaskCompletedNotifications(userIds, taskId, taskTitle, completerName) {
    const notifications = userIds.map(userId => ({
      userId,
      title: 'Task Completed',
      message: `${completerName} completed task "${taskTitle}"`,
      type: 'TASK_COMPLETED',
      taskId,
      data: {
        taskId,
        taskTitle,
        completerName
      }
    }));

    return this.createBulkNotifications(notifications);
  }

  // Create task overdue notifications
  async createTaskOverdueNotifications(userIds, taskId, taskTitle) {
    const notifications = userIds.map(userId => ({
      userId,
      title: 'Task Overdue',
      message: `Task "${taskTitle}" is overdue`,
      type: 'TASK_OVERDUE',
      taskId,
      data: {
        taskId,
        taskTitle
      }
    }));

    return this.createBulkNotifications(notifications);
  }

  // Create comment added notifications
  async createCommentAddedNotifications(userIds, taskId, taskTitle, commenterName, commentText) {
    const notifications = userIds.map(userId => ({
      userId,
      title: 'New Comment',
      message: `${commenterName} commented on task "${taskTitle}": ${commentText.substring(0, 100)}${commentText.length > 100 ? '...' : ''}`,
      type: 'COMMENT_ADDED',
      taskId,
      data: {
        taskId,
        taskTitle,
        commenterName,
        commentText
      }
    }));

    return this.createBulkNotifications(notifications);
  }
}

module.exports = new NotificationService();
