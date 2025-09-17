import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';
import { emitToUser } from '../events.js';

const router = express.Router();
router.use(requireAuth);

// Get user's notifications
router.get('/', async (req, res) => {
  try {
    const userId = req.user.id;
    const { limit = 20, offset = 0, unread_only = false } = req.query;
    
    let query = knex('notifications').where('user_id', userId);
    
    if (unread_only === 'true') {
      query = query.where('read', false);
    }
    
    const notifications = await query
      .orderBy('created_at', 'desc')
      .limit(parseInt(limit))
      .offset(parseInt(offset))
      .catch(() => []);
    
    // Parse JSON data
    const notificationsWithData = notifications.map(notification => ({
      ...notification,
      data: notification.data ? JSON.parse(notification.data) : {}
    }));
    
    // Get unread count
    const [{ count: unreadCount }] = await knex('notifications')
      .where('user_id', userId)
      .where('read', false)
      .count('* as count')
      .catch(() => [{ count: 0 }]);
    
    res.json({
      notifications: notificationsWithData,
      unread_count: parseInt(unreadCount),
      pagination: {
        limit: parseInt(limit),
        offset: parseInt(offset),
        has_more: notifications.length === parseInt(limit)
      }
    });
  } catch (error) {
    console.error('Error fetching notifications:', error);
    res.status(500).json({ error: 'Failed to fetch notifications' });
  }
});

// Mark notification as read
router.patch('/:notificationId/read', async (req, res) => {
  try {
    const userId = req.user.id;
    const notificationId = parseInt(req.params.notificationId);
    
    const updated = await knex('notifications')
      .where({ id: notificationId, user_id: userId })
      .update({ 
        read: true, 
        read_at: new Date(),
        updated_at: new Date()
      });
    
    if (updated === 0) {
      return res.status(404).json({ error: 'Notification not found' });
    }
    
    // Get updated unread count
    const [{ count: unreadCount }] = await knex('notifications')
      .where('user_id', userId)
      .where('read', false)
      .count('* as count')
      .catch(() => [{ count: 0 }]);
    
    // Emit real-time update
    emitToUser(userId, 'notification.read', {
      notification_id: notificationId,
      unread_count: parseInt(unreadCount)
    });
    
    res.json({ 
      message: 'Notification marked as read',
      unread_count: parseInt(unreadCount)
    });
  } catch (error) {
    console.error('Error marking notification as read:', error);
    res.status(500).json({ error: 'Failed to mark notification as read' });
  }
});

// Mark all notifications as read
router.patch('/read-all', async (req, res) => {
  try {
    const userId = req.user.id;
    
    await knex('notifications')
      .where('user_id', userId)
      .where('read', false)
      .update({ 
        read: true, 
        read_at: new Date(),
        updated_at: new Date()
      });
    
    // Emit real-time update
    emitToUser(userId, 'notifications.read_all', {
      unread_count: 0
    });
    
    res.json({ 
      message: 'All notifications marked as read',
      unread_count: 0
    });
  } catch (error) {
    console.error('Error marking all notifications as read:', error);
    res.status(500).json({ error: 'Failed to mark all notifications as read' });
  }
});

// Delete notification
router.delete('/:notificationId', async (req, res) => {
  try {
    const userId = req.user.id;
    const notificationId = parseInt(req.params.notificationId);
    
    const deleted = await knex('notifications')
      .where({ id: notificationId, user_id: userId })
      .del();
    
    if (deleted === 0) {
      return res.status(404).json({ error: 'Notification not found' });
    }
    
    res.json({ message: 'Notification deleted successfully' });
  } catch (error) {
    console.error('Error deleting notification:', error);
    res.status(500).json({ error: 'Failed to delete notification' });
  }
});

// Get notification statistics
router.get('/stats', async (req, res) => {
  try {
    const userId = req.user.id;
    
    const [totalCount] = await knex('notifications')
      .where('user_id', userId)
      .count('* as count')
      .catch(() => [{ count: 0 }]);
    
    const [unreadCount] = await knex('notifications')
      .where('user_id', userId)
      .where('read', false)
      .count('* as count')
      .catch(() => [{ count: 0 }]);
    
    const typeStats = await knex('notifications')
      .where('user_id', userId)
      .select('type')
      .count('* as count')
      .groupBy('type')
      .catch(() => []);
    
    const recentCount = await knex('notifications')
      .where('user_id', userId)
      .where('created_at', '>', knex.raw("NOW() - INTERVAL '24 hours'"))
      .count('* as count')
      .first()
      .catch(() => ({ count: 0 }));
    
    res.json({
      total_notifications: parseInt(totalCount.count),
      unread_notifications: parseInt(unreadCount.count),
      recent_notifications: parseInt(recentCount.count),
      types: typeStats.map(stat => ({
        type: stat.type,
        count: parseInt(stat.count)
      }))
    });
  } catch (error) {
    console.error('Error fetching notification stats:', error);
    res.status(500).json({ error: 'Failed to fetch notification statistics' });
  }
});

// Test notification endpoint (for development)
router.post('/test', async (req, res) => {
  try {
    const userId = req.user.id;
    const { title = 'Test Notification', message = 'This is a test notification', type = 'test' } = req.body;
    
    // Store notification
    const [notification] = await knex('notifications').insert({
      user_id: userId,
      type,
      title,
      message,
      data: JSON.stringify({ test: true }),
      read: false,
      created_at: new Date(),
      updated_at: new Date()
    }).returning('*');
    
    // Emit real-time notification
    emitToUser(userId, 'notification', {
      type,
      title,
      message,
      data: { test: true },
      timestamp: new Date().toISOString()
    });
    
    res.json({ 
      message: 'Test notification sent',
      notification
    });
  } catch (error) {
    console.error('Error sending test notification:', error);
    res.status(500).json({ error: 'Failed to send test notification' });
  }
});

export default router;
