const { PrismaClient } = require('@prisma/client');
const logger = require('../config/logger');
const socketServer = require('../socket/socketServer');

const prisma = new PrismaClient();

class ChatService {
  // Create a new chat channel
  async createChannel(userId, channelData) {
    try {
      const {
        name,
        description,
        isPrivate = false,
        channelType = 'PROJECT',
        projectId,
        memberIds = []
      } = channelData;

      // Verify user has access to project if projectId provided
      if (projectId) {
        const membership = await prisma.projectMember.findFirst({
          where: {
            projectId,
            userId,
            role: { in: ['OWNER', 'ADMIN'] }
          }
        });

        if (!membership) {
          throw new Error('Only project owners and admins can create channels');
        }
      }

      const channel = await prisma.chatChannel.create({
        data: {
          name,
          description,
          isPrivate,
          channelType,
          projectId,
          createdById: userId,
          members: {
            create: [
              { userId, role: 'ADMIN' },
              ...memberIds.map(memberId => ({ userId: memberId, role: 'MEMBER' }))
            ]
          }
        },
        include: {
          createdBy: { select: { id: true, name: true, email: true } },
          project: { select: { id: true, name: true } },
          members: {
            include: {
              user: { select: { id: true, name: true, email: true } }
            }
          },
          _count: { select: { messages: true } }
        }
      });

      // Notify channel members via socket
      channel.members.forEach(member => {
        socketServer.emitToUser(member.userId, 'channel_created', {
          channel: this.formatChannelResponse(channel)
        });
      });

      logger.info(`Channel created: ${channel.name} by user ${userId}`);
      return this.formatChannelResponse(channel);
    } catch (error) {
      logger.error('Error creating channel:', error);
      throw error;
    }
  }

  // Get channels for a user
  async getUserChannels(userId, projectId = null) {
    try {
      const where = {
        members: {
          some: { userId }
        }
      };

      if (projectId) {
        where.projectId = projectId;
      }

      const channels = await prisma.chatChannel.findMany({
        where,
        include: {
          createdBy: { select: { id: true, name: true, email: true } },
          project: { select: { id: true, name: true } },
          members: {
            include: {
              user: { select: { id: true, name: true, email: true } }
            }
          },
          _count: { select: { messages: true } }
        },
        orderBy: { updatedAt: 'desc' }
      });

      return channels.map(channel => this.formatChannelResponse(channel));
    } catch (error) {
      logger.error('Error getting user channels:', error);
      throw error;
    }
  }

  // Send a message
  async sendMessage(userId, messageData) {
    try {
      const {
        channelId,
        recipientId,
        content,
        messageType = 'TEXT',
        parentMessageId,
        attachmentIds = []
      } = messageData;

      // Validate message target
      if (!channelId && !recipientId) {
        throw new Error('Either channelId or recipientId must be provided');
      }

      // Verify user has access to channel if channelId provided
      if (channelId) {
        const membership = await prisma.chatChannelMember.findFirst({
          where: { channelId, userId }
        });

        if (!membership) {
          throw new Error('User is not a member of this channel');
        }
      }

      const message = await prisma.chatMessage.create({
        data: {
          content,
          messageType,
          senderId: userId,
          channelId,
          recipientId,
          parentMessageId,
          attachments: attachmentIds.length > 0 ? {
            connect: attachmentIds.map(id => ({ id }))
          } : undefined
        },
        include: {
          sender: { select: { id: true, name: true, email: true } },
          recipient: { select: { id: true, name: true, email: true } },
          channel: { select: { id: true, name: true } },
          parentMessage: {
            select: { id: true, content: true, senderId: true }
          },
          replies: {
            select: { id: true, content: true, senderId: true },
            take: 3
          },
          attachments: true,
          _count: { select: { replies: true } }
        }
      });

      // Update channel's updatedAt timestamp
      if (channelId) {
        await prisma.chatChannel.update({
          where: { id: channelId },
          data: { updatedAt: new Date() }
        });
      }

      const formattedMessage = this.formatMessageResponse(message);

      // Emit message via socket
      if (channelId) {
        socketServer.emitToChannel(channelId, 'new_message', formattedMessage);
      } else if (recipientId) {
        socketServer.emitToUser(recipientId, 'new_message', formattedMessage);
        socketServer.emitToUser(userId, 'new_message', formattedMessage);
      }

      logger.info(`Message sent by user ${userId} to ${channelId ? `channel ${channelId}` : `user ${recipientId}`}`);
      return formattedMessage;
    } catch (error) {
      logger.error('Error sending message:', error);
      throw error;
    }
  }

  // Get messages for a channel or direct conversation
  async getMessages(userId, options) {
    try {
      const {
        channelId,
        recipientId,
        page = 1,
        limit = 50,
        before,
        after
      } = options;

      let where = {};

      if (channelId) {
        // Verify user has access to channel
        const membership = await prisma.chatChannelMember.findFirst({
          where: { channelId, userId }
        });

        if (!membership) {
          throw new Error('User is not a member of this channel');
        }

        where.channelId = channelId;
      } else if (recipientId) {
        // Direct messages
        where.OR = [
          { senderId: userId, recipientId },
          { senderId: recipientId, recipientId: userId }
        ];
      } else {
        throw new Error('Either channelId or recipientId must be provided');
      }

      // Add time-based filtering
      if (before) {
        where.createdAt = { lt: new Date(before) };
      }
      if (after) {
        where.createdAt = { gt: new Date(after) };
      }

      const messages = await prisma.chatMessage.findMany({
        where,
        include: {
          sender: { select: { id: true, name: true, email: true } },
          recipient: { select: { id: true, name: true, email: true } },
          parentMessage: {
            select: { id: true, content: true, senderId: true }
          },
          replies: {
            select: { id: true, content: true, senderId: true },
            take: 3
          },
          attachments: true,
          _count: { select: { replies: true } }
        },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit
      });

      return {
        messages: messages.reverse().map(msg => this.formatMessageResponse(msg)),
        pagination: {
          page,
          limit,
          hasMore: messages.length === limit
        }
      };
    } catch (error) {
      logger.error('Error getting messages:', error);
      throw error;
    }
  }

  // Join a channel
  async joinChannel(userId, channelId, role = 'MEMBER') {
    try {
      // Check if channel exists and user has permission to join
      const channel = await prisma.chatChannel.findUnique({
        where: { id: channelId },
        include: { project: true }
      });

      if (!channel) {
        throw new Error('Channel not found');
      }

      // Check if user is already a member
      const existingMembership = await prisma.chatChannelMember.findFirst({
        where: { channelId, userId }
      });

      if (existingMembership) {
        throw new Error('User is already a member of this channel');
      }

      // For project channels, verify user is a project member
      if (channel.projectId) {
        const projectMembership = await prisma.projectMember.findFirst({
          where: {
            projectId: channel.projectId,
            userId
          }
        });

        if (!projectMembership) {
          throw new Error('User must be a project member to join this channel');
        }
      }

      const membership = await prisma.chatChannelMember.create({
        data: {
          channelId,
          userId,
          role
        },
        include: {
          user: { select: { id: true, name: true, email: true } },
          channel: { select: { id: true, name: true } }
        }
      });

      // Notify channel members
      socketServer.emitToChannel(channelId, 'user_joined_channel', {
        channelId,
        user: membership.user
      });

      logger.info(`User ${userId} joined channel ${channelId}`);
      return membership;
    } catch (error) {
      logger.error('Error joining channel:', error);
      throw error;
    }
  }

  // Leave a channel
  async leaveChannel(userId, channelId) {
    try {
      const membership = await prisma.chatChannelMember.findFirst({
        where: { channelId, userId }
      });

      if (!membership) {
        throw new Error('User is not a member of this channel');
      }

      await prisma.chatChannelMember.delete({
        where: { id: membership.id }
      });

      // Notify channel members
      socketServer.emitToChannel(channelId, 'user_left_channel', {
        channelId,
        userId
      });

      logger.info(`User ${userId} left channel ${channelId}`);
    } catch (error) {
      logger.error('Error leaving channel:', error);
      throw error;
    }
  }

  // Mark messages as read
  async markAsRead(userId, channelId, messageId = null) {
    try {
      const membership = await prisma.chatChannelMember.findFirst({
        where: { channelId, userId }
      });

      if (!membership) {
        throw new Error('User is not a member of this channel');
      }

      await prisma.chatChannelMember.update({
        where: { id: membership.id },
        data: { lastRead: new Date() }
      });

      // Notify channel members
      socketServer.emitToChannel(channelId, 'messages_read', {
        channelId,
        userId,
        messageId,
        readAt: new Date()
      });

      logger.info(`User ${userId} marked messages as read in channel ${channelId}`);
    } catch (error) {
      logger.error('Error marking messages as read:', error);
      throw error;
    }
  }

  // Get direct message conversations
  async getDirectConversations(userId) {
    try {
      const conversations = await prisma.chatMessage.findMany({
        where: {
          OR: [
            { senderId: userId, recipientId: { not: null } },
            { recipientId: userId }
          ]
        },
        include: {
          sender: { select: { id: true, name: true, email: true } },
          recipient: { select: { id: true, name: true, email: true } }
        },
        orderBy: { createdAt: 'desc' },
        distinct: ['senderId', 'recipientId']
      });

      // Group conversations by participants
      const conversationMap = new Map();
      
      conversations.forEach(message => {
        const otherUserId = message.senderId === userId ? message.recipientId : message.senderId;
        const otherUser = message.senderId === userId ? message.recipient : message.sender;
        
        if (!conversationMap.has(otherUserId)) {
          conversationMap.set(otherUserId, {
            userId: otherUserId,
            user: otherUser,
            lastMessage: message,
            unreadCount: 0 // This would need to be calculated based on read status
          });
        }
      });

      return Array.from(conversationMap.values());
    } catch (error) {
      logger.error('Error getting direct conversations:', error);
      throw error;
    }
  }

  // Format channel response
  formatChannelResponse(channel) {
    return {
      id: channel.id,
      name: channel.name,
      description: channel.description,
      isPrivate: channel.isPrivate,
      channelType: channel.channelType,
      createdAt: channel.createdAt,
      updatedAt: channel.updatedAt,
      project: channel.project,
      createdBy: channel.createdBy,
      members: channel.members?.map(member => ({
        id: member.id,
        role: member.role,
        joinedAt: member.joinedAt,
        lastRead: member.lastRead,
        user: member.user
      })),
      messageCount: channel._count?.messages || 0
    };
  }

  // Format message response
  formatMessageResponse(message) {
    return {
      id: message.id,
      content: message.content,
      messageType: message.messageType,
      isEdited: message.isEdited,
      isDeleted: message.isDeleted,
      createdAt: message.createdAt,
      updatedAt: message.updatedAt,
      sender: message.sender,
      recipient: message.recipient,
      channel: message.channel,
      parentMessage: message.parentMessage,
      replies: message.replies,
      replyCount: message._count?.replies || 0,
      attachments: message.attachments || []
    };
  }
}

module.exports = new ChatService();
