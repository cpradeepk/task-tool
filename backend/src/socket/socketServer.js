const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');
const logger = require('../config/logger');

const prisma = new PrismaClient();

class SocketServer {
  constructor() {
    this.io = null;
    this.connectedUsers = new Map(); // userId -> socketId
    this.userSockets = new Map(); // socketId -> userId
  }

  initialize(server) {
    this.io = new Server(server, {
      path: '/task/socket.io/',
      cors: {
        origin: process.env.FRONTEND_URL || "http://localhost:3000",
        methods: ["GET", "POST"],
        credentials: true
      }
    });

    this.io.use(this.authenticateSocket.bind(this));
    this.io.on('connection', this.handleConnection.bind(this));

    logger.info('Socket.IO server initialized');
    return this.io;
  }

  async authenticateSocket(socket, next) {
    try {
      const token = socket.handshake.auth.token || socket.handshake.headers.authorization?.replace('Bearer ', '');
      
      if (!token) {
        return next(new Error('Authentication token required'));
      }

      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      const user = await prisma.user.findUnique({
        where: { id: decoded.userId },
        select: { id: true, email: true, name: true, isAdmin: true }
      });

      if (!user) {
        return next(new Error('User not found'));
      }

      socket.userId = user.id;
      socket.user = user;
      next();
    } catch (error) {
      logger.error('Socket authentication error:', error);
      next(new Error('Authentication failed'));
    }
  }

  handleConnection(socket) {
    const userId = socket.userId;
    logger.info(`User ${userId} connected via socket ${socket.id}`);

    // Store user connection
    this.connectedUsers.set(userId, socket.id);
    this.userSockets.set(socket.id, userId);

    // Join user to their personal room
    socket.join(`user:${userId}`);

    // Join user to their project channels
    this.joinUserChannels(socket);

    // Handle socket events
    this.setupSocketEvents(socket);

    // Handle disconnection
    socket.on('disconnect', () => {
      logger.info(`User ${userId} disconnected from socket ${socket.id}`);
      this.connectedUsers.delete(userId);
      this.userSockets.delete(socket.id);
    });
  }

  async joinUserChannels(socket) {
    try {
      const userId = socket.userId;
      
      // Get user's project memberships
      const projectMemberships = await prisma.projectMember.findMany({
        where: { userId },
        include: { project: true }
      });

      // Join project rooms
      for (const membership of projectMemberships) {
        socket.join(`project:${membership.projectId}`);
      }

      // Get user's channel memberships
      const channelMemberships = await prisma.chatChannelMember.findMany({
        where: { userId },
        include: { channel: true }
      });

      // Join channel rooms
      for (const membership of channelMemberships) {
        socket.join(`channel:${membership.channelId}`);
      }

      logger.info(`User ${userId} joined ${projectMemberships.length} projects and ${channelMemberships.length} channels`);
    } catch (error) {
      logger.error('Error joining user channels:', error);
    }
  }

  setupSocketEvents(socket) {
    // Chat events
    socket.on('join_channel', this.handleJoinChannel.bind(this, socket));
    socket.on('leave_channel', this.handleLeaveChannel.bind(this, socket));
    socket.on('send_message', this.handleSendMessage.bind(this, socket));
    socket.on('typing_start', this.handleTypingStart.bind(this, socket));
    socket.on('typing_stop', this.handleTypingStop.bind(this, socket));
    socket.on('mark_read', this.handleMarkRead.bind(this, socket));

    // Notification events
    socket.on('mark_notification_read', this.handleMarkNotificationRead.bind(this, socket));
    socket.on('mark_all_notifications_read', this.handleMarkAllNotificationsRead.bind(this, socket));

    // Task events
    socket.on('task_update', this.handleTaskUpdate.bind(this, socket));
    socket.on('join_task', this.handleJoinTask.bind(this, socket));
    socket.on('leave_task', this.handleLeaveTask.bind(this, socket));

    // Project events
    socket.on('join_project', this.handleJoinProject.bind(this, socket));
    socket.on('leave_project', this.handleLeaveProject.bind(this, socket));
  }

  async handleJoinChannel(socket, data) {
    try {
      const { channelId } = data;
      const userId = socket.userId;

      // Verify user has access to channel
      const membership = await prisma.chatChannelMember.findFirst({
        where: { channelId, userId }
      });

      if (!membership) {
        socket.emit('error', { message: 'Access denied to channel' });
        return;
      }

      socket.join(`channel:${channelId}`);
      socket.emit('joined_channel', { channelId });
      
      // Notify other channel members
      socket.to(`channel:${channelId}`).emit('user_joined_channel', {
        channelId,
        user: socket.user
      });

      logger.info(`User ${userId} joined channel ${channelId}`);
    } catch (error) {
      logger.error('Error joining channel:', error);
      socket.emit('error', { message: 'Failed to join channel' });
    }
  }

  async handleLeaveChannel(socket, data) {
    try {
      const { channelId } = data;
      const userId = socket.userId;

      socket.leave(`channel:${channelId}`);
      socket.emit('left_channel', { channelId });

      // Notify other channel members
      socket.to(`channel:${channelId}`).emit('user_left_channel', {
        channelId,
        user: socket.user
      });

      logger.info(`User ${userId} left channel ${channelId}`);
    } catch (error) {
      logger.error('Error leaving channel:', error);
    }
  }

  async handleSendMessage(socket, data) {
    try {
      const { channelId, content, messageType = 'TEXT', recipientId } = data;
      const userId = socket.userId;

      // Create message in database (this will be handled by the chat service)
      // For now, just emit the message
      const messageData = {
        id: `temp_${Date.now()}`,
        content,
        messageType,
        senderId: userId,
        sender: socket.user,
        channelId,
        recipientId,
        createdAt: new Date().toISOString()
      };

      if (channelId) {
        // Channel message
        this.io.to(`channel:${channelId}`).emit('new_message', messageData);
      } else if (recipientId) {
        // Direct message
        this.io.to(`user:${recipientId}`).emit('new_message', messageData);
        this.io.to(`user:${userId}`).emit('new_message', messageData);
      }

      logger.info(`Message sent by user ${userId} to ${channelId ? `channel ${channelId}` : `user ${recipientId}`}`);
    } catch (error) {
      logger.error('Error sending message:', error);
      socket.emit('error', { message: 'Failed to send message' });
    }
  }

  handleTypingStart(socket, data) {
    const { channelId, recipientId } = data;
    const userId = socket.userId;

    if (channelId) {
      socket.to(`channel:${channelId}`).emit('user_typing', {
        channelId,
        userId,
        user: socket.user
      });
    } else if (recipientId) {
      this.io.to(`user:${recipientId}`).emit('user_typing', {
        userId,
        user: socket.user
      });
    }
  }

  handleTypingStop(socket, data) {
    const { channelId, recipientId } = data;
    const userId = socket.userId;

    if (channelId) {
      socket.to(`channel:${channelId}`).emit('user_stopped_typing', {
        channelId,
        userId
      });
    } else if (recipientId) {
      this.io.to(`user:${recipientId}`).emit('user_stopped_typing', {
        userId
      });
    }
  }

  async handleMarkRead(socket, data) {
    try {
      const { channelId, messageId } = data;
      const userId = socket.userId;

      // Update last read timestamp (this will be handled by the chat service)
      socket.to(`channel:${channelId}`).emit('message_read', {
        channelId,
        messageId,
        userId
      });
    } catch (error) {
      logger.error('Error marking message as read:', error);
    }
  }

  async handleMarkNotificationRead(socket, data) {
    try {
      const { notificationId } = data;
      const userId = socket.userId;

      // This will be handled by the notification service
      socket.emit('notification_read', { notificationId });
    } catch (error) {
      logger.error('Error marking notification as read:', error);
    }
  }

  async handleMarkAllNotificationsRead(socket, data) {
    try {
      const userId = socket.userId;

      // This will be handled by the notification service
      socket.emit('all_notifications_read');
    } catch (error) {
      logger.error('Error marking all notifications as read:', error);
    }
  }

  handleTaskUpdate(socket, data) {
    const { taskId, projectId, update } = data;
    
    // Broadcast task update to project members
    if (projectId) {
      socket.to(`project:${projectId}`).emit('task_updated', {
        taskId,
        update,
        updatedBy: socket.user
      });
    }
  }

  handleJoinTask(socket, data) {
    const { taskId } = data;
    socket.join(`task:${taskId}`);
  }

  handleLeaveTask(socket, data) {
    const { taskId } = data;
    socket.leave(`task:${taskId}`);
  }

  handleJoinProject(socket, data) {
    const { projectId } = data;
    socket.join(`project:${projectId}`);
  }

  handleLeaveProject(socket, data) {
    const { projectId } = data;
    socket.leave(`project:${projectId}`);
  }

  // Utility methods for emitting events from other parts of the application
  emitToUser(userId, event, data) {
    if (this.connectedUsers.has(userId)) {
      this.io.to(`user:${userId}`).emit(event, data);
    }
  }

  emitToChannel(channelId, event, data) {
    this.io.to(`channel:${channelId}`).emit(event, data);
  }

  emitToProject(projectId, event, data) {
    this.io.to(`project:${projectId}`).emit(event, data);
  }

  emitToTask(taskId, event, data) {
    this.io.to(`task:${taskId}`).emit(event, data);
  }

  getConnectedUsers() {
    return Array.from(this.connectedUsers.keys());
  }

  isUserConnected(userId) {
    return this.connectedUsers.has(userId);
  }
}

module.exports = new SocketServer();
