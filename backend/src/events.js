import { knex } from './db/index.js';
import nodemailer from 'nodemailer';

let ioInstance = null;
const userSockets = new Map(); // Map user IDs to socket IDs

export function registerIO(io) {
  ioInstance = io;

  // Handle user authentication and socket mapping
  io.on('connection', (socket) => {
    console.log(`Socket connected: ${socket.id}`);

    // Handle user authentication
    socket.on('authenticate', async (data) => {
      try {
        const { userId, token } = data;
        if (userId && token) {
          // Store user-socket mapping
          userSockets.set(userId, socket.id);
          socket.userId = userId;
          socket.join(`user_${userId}`);

          console.log(`User ${userId} authenticated with socket ${socket.id}`);
          socket.emit('authenticated', { success: true, userId });

          // Send any pending notifications
          await sendPendingNotifications(userId, socket);
        }
      } catch (error) {
        console.error('Socket authentication error:', error);
        socket.emit('authenticated', { success: false, error: 'Authentication failed' });
      }
    });

    // Handle disconnection
    socket.on('disconnect', () => {
      if (socket.userId) {
        userSockets.delete(socket.userId);
        console.log(`User ${socket.userId} disconnected`);
      }
    });

    // Send welcome message
    socket.emit('welcome', {
      message: 'Connected to Task Tool realtime gateway',
      timestamp: new Date().toISOString()
    });
  });
}

// Generic event emitter
export function emitEvent(event, payload) {
  if (ioInstance) {
    ioInstance.emit(event, payload);
  }
}

// Emit to specific user
export function emitToUser(userId, event, payload) {
  if (ioInstance && userSockets.has(userId)) {
    const socketId = userSockets.get(userId);
    ioInstance.to(socketId).emit(event, payload);
  }
}

// Emit to multiple users
export function emitToUsers(userIds, event, payload) {
  userIds.forEach(userId => emitToUser(userId, event, payload));
}

// Send pending notifications to user
async function sendPendingNotifications(userId, socket) {
  try {
    const notifications = await knex('notifications')
      .where('user_id', userId)
      .where('read', false)
      .orderBy('created_at', 'desc')
      .limit(10)
      .catch(() => []);

    if (notifications.length > 0) {
      socket.emit('notifications.pending', {
        count: notifications.length,
        notifications
      });
    }
  } catch (error) {
    console.error('Error sending pending notifications:', error);
  }
}

// Task-related events
export function emitTaskCreated(task) {
  emitEvent('task.created', task);

  // Notify assigned user
  if (task.assigned_to) {
    emitToUser(task.assigned_to, 'notification', {
      type: 'task_assigned',
      title: 'New Task Assigned',
      message: `You have been assigned a new task: ${task.title}`,
      data: { task_id: task.id, task_title: task.title },
      timestamp: new Date().toISOString()
    });

    // Store notification in database
    storeNotification(task.assigned_to, 'task_assigned', `New task assigned: ${task.title}`, {
      task_id: task.id,
      task_title: task.title
    });

    // Send email notification
    sendEmailNotification(task.assigned_to, 'task_assigned', {
      task_id: task.id,
      task_title: task.title,
      project_name: task.project_name,
      priority: task.priority,
      due_date: task.due_date
    });
  }
}

export function emitTaskUpdated(task) {
  emitEvent('task.updated', task);

  // Notify assigned user about task updates
  if (task.assigned_to) {
    emitToUser(task.assigned_to, 'notification', {
      type: 'task_updated',
      title: 'Task Updated',
      message: `Task "${task.title}" has been updated`,
      data: { task_id: task.id, task_title: task.title },
      timestamp: new Date().toISOString()
    });
  }
}

export function emitTaskStatusChanged(task, oldStatus, newStatus) {
  emitEvent('task.status_changed', { task, oldStatus, newStatus });

  // Notify relevant users about status changes
  if (task.assigned_to) {
    emitToUser(task.assigned_to, 'notification', {
      type: 'task_status_changed',
      title: 'Task Status Changed',
      message: `Task "${task.title}" status changed from ${oldStatus} to ${newStatus}`,
      data: { task_id: task.id, task_title: task.title, old_status: oldStatus, new_status: newStatus },
      timestamp: new Date().toISOString()
    });
  }
}

// Chat-related events
export function emitMessageCreated(message) {
  emitEvent('chat.message', message);

  // Notify channel members about new messages
  notifyChannelMembers(message.channel_id, message.user_id, {
    type: 'new_message',
    title: 'New Message',
    message: `New message in channel`,
    data: {
      channel_id: message.channel_id,
      message_id: message.id,
      sender_email: message.email || 'Unknown'
    },
    timestamp: new Date().toISOString()
  });
}

// Project-related events
export function emitProjectCreated(project) {
  emitEvent('project.created', project);
}

export function emitProjectUpdated(project) {
  emitEvent('project.updated', project);
}

// System-wide notifications
export function emitSystemNotification(title, message, userIds = null) {
  const notification = {
    type: 'system',
    title,
    message,
    timestamp: new Date().toISOString()
  };

  if (userIds && Array.isArray(userIds)) {
    // Send to specific users
    emitToUsers(userIds, 'notification', notification);
    userIds.forEach(userId => {
      storeNotification(userId, 'system', message, { title });
    });
  } else {
    // Broadcast to all connected users
    emitEvent('notification', notification);
  }
}

// Helper function to store notifications in database
async function storeNotification(userId, type, message, data = {}) {
  try {
    await knex('notifications').insert({
      user_id: userId,
      type,
      title: data.title || type.replace('_', ' ').toUpperCase(),
      message,
      data: JSON.stringify(data),
      read: false,
      created_at: new Date(),
      updated_at: new Date()
    });
  } catch (error) {
    console.error('Error storing notification:', error);
  }
}

// Helper function to notify channel members
async function notifyChannelMembers(channelId, senderId, notification) {
  try {
    const members = await knex('channel_members')
      .where('channel_id', channelId)
      .where('user_id', '!=', senderId) // Don't notify the sender
      .pluck('user_id')
      .catch(() => []);

    members.forEach(userId => {
      emitToUser(userId, 'notification', notification);
      storeNotification(userId, notification.type, notification.message, notification.data);
    });
  } catch (error) {
    console.error('Error notifying channel members:', error);
  }
}

// Deadline reminder notifications
export function emitDeadlineReminder(task, daysUntilDeadline) {
  if (task.assigned_to) {
    const urgency = daysUntilDeadline <= 1 ? 'urgent' : 'normal';
    const message = daysUntilDeadline === 0
      ? `Task "${task.title}" is due today!`
      : `Task "${task.title}" is due in ${daysUntilDeadline} day${daysUntilDeadline > 1 ? 's' : ''}`;

    emitToUser(task.assigned_to, 'notification', {
      type: 'deadline_reminder',
      title: 'Deadline Reminder',
      message,
      urgency,
      data: {
        task_id: task.id,
        task_title: task.title,
        due_date: task.due_date,
        days_until_deadline: daysUntilDeadline
      },
      timestamp: new Date().toISOString()
    });

    storeNotification(task.assigned_to, 'deadline_reminder', message, {
      task_id: task.id,
      urgency,
      days_until_deadline: daysUntilDeadline
    });
  }
}

// User activity notifications
export function emitUserActivity(userId, activity, data = {}) {
  emitToUser(userId, 'user.activity', {
    activity,
    data,
    timestamp: new Date().toISOString()
  });
}

// Email functionality
const createEmailTransporter = () => {
  if (process.env.EMAIL_SERVICE === 'gmail') {
    return nodemailer.createTransporter({
      service: 'gmail',
      auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS
      }
    });
  } else if (process.env.SMTP_HOST) {
    return nodemailer.createTransporter({
      host: process.env.SMTP_HOST,
      port: process.env.SMTP_PORT || 587,
      secure: process.env.SMTP_SECURE === 'true',
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS
      }
    });
  }
  return null;
};

// Send email notification
export async function sendEmailNotification(userId, template, data) {
  try {
    const transporter = createEmailTransporter();
    if (!transporter) return;

    // Get user email
    const user = await knex('users').where('id', userId).first();
    if (!user || !user.email || !user.email_notifications) return;

    const emailTemplates = {
      task_assigned: {
        subject: `New Task Assigned: ${data.task_title}`,
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #FFA301;">Task Assigned</h2>
            <p>Hello ${user.name},</p>
            <p>You have been assigned a new task:</p>
            <div style="background: #f5f5f5; padding: 15px; border-radius: 5px; margin: 15px 0;">
              <h3 style="margin: 0 0 10px 0;">${data.task_title}</h3>
              <p style="margin: 0;"><strong>Project:</strong> ${data.project_name || 'N/A'}</p>
              <p style="margin: 0;"><strong>Priority:</strong> ${data.priority || 'Medium'}</p>
              ${data.due_date ? `<p style="margin: 0;"><strong>Due Date:</strong> ${data.due_date}</p>` : ''}
            </div>
            <p><a href="${process.env.APP_URL || 'https://task.amtariksha.com'}/task/tasks/${data.task_id}" style="background: #FFA301; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">View Task</a></p>
            <p>Best regards,<br>Task Tool Team</p>
          </div>
        `
      },
      deadline_reminder: {
        subject: `Deadline Reminder: ${data.task_title}`,
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #dc3545;">Deadline Reminder</h2>
            <p>Hello ${user.name},</p>
            <p>This is a reminder that the following task is due ${data.time_remaining}:</p>
            <div style="background: #fff3cd; border: 1px solid #ffeaa7; padding: 15px; border-radius: 5px; margin: 15px 0;">
              <h3 style="margin: 0 0 10px 0;">${data.task_title}</h3>
              <p style="margin: 0;"><strong>Due Date:</strong> ${data.due_date}</p>
              <p style="margin: 0;"><strong>Priority:</strong> ${data.priority || 'Medium'}</p>
            </div>
            <p><a href="${process.env.APP_URL || 'https://task.amtariksha.com'}/task/tasks/${data.task_id}" style="background: #dc3545; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">View Task</a></p>
            <p>Best regards,<br>Task Tool Team</p>
          </div>
        `
      }
    };

    const emailTemplate = emailTemplates[template];
    if (!emailTemplate) return;

    const mailOptions = {
      from: process.env.EMAIL_FROM || 'noreply@tasktool.com',
      to: user.email,
      subject: emailTemplate.subject,
      html: emailTemplate.html
    };

    const info = await transporter.sendMail(mailOptions);

    // Log email
    await knex('email_logs').insert({
      user_id: userId,
      recipient: user.email,
      subject: emailTemplate.subject,
      template,
      status: 'sent',
      message_id: info.messageId,
      created_at: new Date()
    }).catch(() => {});

    console.log(`Email sent to ${user.email}: ${emailTemplate.subject}`);
  } catch (error) {
    console.error('Email send error:', error);

    // Log failed email
    await knex('email_logs').insert({
      user_id: userId,
      recipient: 'unknown',
      subject: template,
      template,
      status: 'failed',
      error_message: error.message,
      created_at: new Date()
    }).catch(() => {});
  }
}

