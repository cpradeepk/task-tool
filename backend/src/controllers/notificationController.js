const { PrismaClient } = require('@prisma/client');
const logger = require('../config/logger');
const notificationService = require('../services/notificationService');

const prisma = new PrismaClient();

class NotificationController {
  // Get notifications for the authenticated user
  async getNotifications(req, res) {
    try {
      const {
        isRead,
        type,
        page,
        limit,
        projectId,
        taskId
      } = req.query;

      const options = {
        isRead: isRead !== undefined ? isRead === 'true' : undefined,
        type,
        page: page ? parseInt(page) : 1,
        limit: limit ? parseInt(limit) : 20,
        projectId,
        taskId
      };

      const result = await notificationService.getUserNotifications(req.user.id, options);
      res.json(result);
    } catch (error) {
      logger.error('Error getting notifications:', error);
      res.status(500).json({ error: 'Failed to get notifications' });
    }
  }

  // Get notification statistics
  async getNotificationStats(req, res) {
    try {
      const stats = await notificationService.getNotificationStats(req.user.id);
      res.json(stats);
    } catch (error) {
      logger.error('Error getting notification stats:', error);
      res.status(500).json({ error: 'Failed to get notification statistics' });
    }
  }

  // Mark notification as read
  async markAsRead(req, res) {
    try {
      const { notificationId } = req.params;
      const notification = await notificationService.markAsRead(req.user.id, notificationId);
      
      logger.info(`Notification marked as read: ${notificationId} by ${req.user.email}`);
      res.json(notification);
    } catch (error) {
      logger.error('Error marking notification as read:', error);
      res.status(400).json({ error: error.message });
    }
  }

  // Mark all notifications as read
  async markAllAsRead(req, res) {
    try {
      const result = await notificationService.markAllAsRead(req.user.id);
      
      logger.info(`All notifications marked as read by ${req.user.email}`);
      res.json(result);
    } catch (error) {
      logger.error('Error marking all notifications as read:', error);
      res.status(500).json({ error: 'Failed to mark all notifications as read' });
    }
  }

  // Delete notification
  async deleteNotification(req, res) {
    try {
      const { notificationId } = req.params;
      await notificationService.deleteNotification(req.user.id, notificationId);
      
      logger.info(`Notification deleted: ${notificationId} by ${req.user.email}`);
      res.status(204).send();
    } catch (error) {
      logger.error('Error deleting notification:', error);
      res.status(400).json({ error: error.message });
    }
  }

  // Create notification (admin only)
  async createNotification(req, res) {
    try {
      if (!req.user.isAdmin) {
        return res.status(403).json({ error: 'Only administrators can create notifications' });
      }

      const notificationData = req.body;
      const notification = await notificationService.createNotification(notificationData);
      
      logger.info(`Notification created by admin ${req.user.email}`);
      res.status(201).json(notification);
    } catch (error) {
      logger.error('Error creating notification:', error);
      res.status(400).json({ error: error.message });
    }
  }

  // Create bulk notifications (admin only)
  async createBulkNotifications(req, res) {
    try {
      if (!req.user.isAdmin) {
        return res.status(403).json({ error: 'Only administrators can create bulk notifications' });
      }

      const { notifications } = req.body;
      
      if (!Array.isArray(notifications) || notifications.length === 0) {
        return res.status(400).json({ error: 'Notifications array is required' });
      }

      const createdNotifications = await notificationService.createBulkNotifications(notifications);
      
      logger.info(`${notifications.length} bulk notifications created by admin ${req.user.email}`);
      res.status(201).json(createdNotifications);
    } catch (error) {
      logger.error('Error creating bulk notifications:', error);
      res.status(400).json({ error: error.message });
    }
  }

  // Get notification preferences (placeholder for future implementation)
  async getNotificationPreferences(req, res) {
    try {
      // This would typically fetch user's notification preferences from database
      // For now, return default preferences
      const preferences = {
        email: {
          taskAssigned: true,
          taskCompleted: true,
          taskOverdue: true,
          commentAdded: true,
          projectUpdated: true,
          deadlineReminder: true
        },
        push: {
          taskAssigned: true,
          taskCompleted: false,
          taskOverdue: true,
          commentAdded: true,
          projectUpdated: false,
          deadlineReminder: true
        },
        inApp: {
          taskAssigned: true,
          taskCompleted: true,
          taskOverdue: true,
          commentAdded: true,
          projectUpdated: true,
          deadlineReminder: true,
          mention: true
        }
      };

      res.json(preferences);
    } catch (error) {
      logger.error('Error getting notification preferences:', error);
      res.status(500).json({ error: 'Failed to get notification preferences' });
    }
  }

  // Update notification preferences (placeholder for future implementation)
  async updateNotificationPreferences(req, res) {
    try {
      const preferences = req.body;
      
      // This would typically update user's notification preferences in database
      // For now, just return the received preferences
      
      logger.info(`Notification preferences updated by ${req.user.email}`);
      res.json(preferences);
    } catch (error) {
      logger.error('Error updating notification preferences:', error);
      res.status(500).json({ error: 'Failed to update notification preferences' });
    }
  }

  // Test notification (admin only)
  async testNotification(req, res) {
    try {
      if (!req.user.isAdmin) {
        return res.status(403).json({ error: 'Only administrators can send test notifications' });
      }

      const { userId, title, message, type = 'INFO' } = req.body;

      if (!userId || !title || !message) {
        return res.status(400).json({ error: 'userId, title, and message are required' });
      }

      const notification = await notificationService.createNotification({
        userId,
        title,
        message,
        type,
        data: { isTest: true }
      });

      logger.info(`Test notification sent by admin ${req.user.email} to user ${userId}`);
      res.status(201).json(notification);
    } catch (error) {
      logger.error('Error sending test notification:', error);
      res.status(400).json({ error: error.message });
    }
  }
}

module.exports = new NotificationController();
