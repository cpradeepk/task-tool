const { PrismaClient } = require('@prisma/client');
const logger = require('../config/logger');
const chatService = require('../services/chatService');

const prisma = new PrismaClient();

class ChatController {
  // Create a new chat channel
  async createChannel(req, res) {
    try {
      const channelData = req.body;
      const channel = await chatService.createChannel(req.user.id, channelData);
      
      logger.info(`Channel created: ${channel.name} by ${req.user.email}`);
      res.status(201).json(channel);
    } catch (error) {
      logger.error('Error creating channel:', error);
      res.status(400).json({ error: error.message });
    }
  }

  // Get channels for the authenticated user
  async getChannels(req, res) {
    try {
      const { projectId } = req.query;
      const channels = await chatService.getUserChannels(req.user.id, projectId);
      
      res.json(channels);
    } catch (error) {
      logger.error('Error getting channels:', error);
      res.status(500).json({ error: 'Failed to get channels' });
    }
  }

  // Get channel details
  async getChannel(req, res) {
    try {
      const { channelId } = req.params;
      
      // Verify user has access to channel
      const membership = await prisma.chatChannelMember.findFirst({
        where: {
          channelId,
          userId: req.user.id
        }
      });

      if (!membership) {
        return res.status(403).json({ error: 'Access denied to this channel' });
      }

      const channel = await prisma.chatChannel.findUnique({
        where: { id: channelId },
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

      if (!channel) {
        return res.status(404).json({ error: 'Channel not found' });
      }

      res.json(chatService.formatChannelResponse(channel));
    } catch (error) {
      logger.error('Error getting channel:', error);
      res.status(500).json({ error: 'Failed to get channel' });
    }
  }

  // Update channel
  async updateChannel(req, res) {
    try {
      const { channelId } = req.params;
      const { name, description, isPrivate } = req.body;

      // Verify user is channel admin
      const membership = await prisma.chatChannelMember.findFirst({
        where: {
          channelId,
          userId: req.user.id,
          role: 'ADMIN'
        }
      });

      if (!membership) {
        return res.status(403).json({ error: 'Only channel admins can update channels' });
      }

      const updateData = {};
      if (name !== undefined) updateData.name = name;
      if (description !== undefined) updateData.description = description;
      if (isPrivate !== undefined) updateData.isPrivate = isPrivate;

      const channel = await prisma.chatChannel.update({
        where: { id: channelId },
        data: updateData,
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

      logger.info(`Channel updated: ${channelId} by ${req.user.email}`);
      res.json(chatService.formatChannelResponse(channel));
    } catch (error) {
      logger.error('Error updating channel:', error);
      res.status(500).json({ error: 'Failed to update channel' });
    }
  }

  // Delete channel
  async deleteChannel(req, res) {
    try {
      const { channelId } = req.params;

      // Verify user is channel admin
      const membership = await prisma.chatChannelMember.findFirst({
        where: {
          channelId,
          userId: req.user.id,
          role: 'ADMIN'
        }
      });

      if (!membership) {
        return res.status(403).json({ error: 'Only channel admins can delete channels' });
      }

      await prisma.chatChannel.delete({
        where: { id: channelId }
      });

      logger.info(`Channel deleted: ${channelId} by ${req.user.email}`);
      res.status(204).send();
    } catch (error) {
      logger.error('Error deleting channel:', error);
      res.status(500).json({ error: 'Failed to delete channel' });
    }
  }

  // Send a message
  async sendMessage(req, res) {
    try {
      const messageData = req.body;
      const message = await chatService.sendMessage(req.user.id, messageData);
      
      logger.info(`Message sent by ${req.user.email}`);
      res.status(201).json(message);
    } catch (error) {
      logger.error('Error sending message:', error);
      res.status(400).json({ error: error.message });
    }
  }

  // Get messages
  async getMessages(req, res) {
    try {
      const { channelId, recipientId, page, limit, before, after } = req.query;
      
      const options = {
        channelId,
        recipientId,
        page: page ? parseInt(page) : 1,
        limit: limit ? parseInt(limit) : 50,
        before,
        after
      };

      const result = await chatService.getMessages(req.user.id, options);
      res.json(result);
    } catch (error) {
      logger.error('Error getting messages:', error);
      res.status(400).json({ error: error.message });
    }
  }

  // Update message
  async updateMessage(req, res) {
    try {
      const { messageId } = req.params;
      const { content } = req.body;

      // Verify user owns the message
      const message = await prisma.chatMessage.findFirst({
        where: {
          id: messageId,
          senderId: req.user.id
        }
      });

      if (!message) {
        return res.status(404).json({ error: 'Message not found or access denied' });
      }

      const updatedMessage = await prisma.chatMessage.update({
        where: { id: messageId },
        data: {
          content,
          isEdited: true
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

      const formattedMessage = chatService.formatMessageResponse(updatedMessage);

      // Emit update via socket
      if (message.channelId) {
        socketServer.emitToChannel(message.channelId, 'message_updated', formattedMessage);
      } else if (message.recipientId) {
        socketServer.emitToUser(message.recipientId, 'message_updated', formattedMessage);
        socketServer.emitToUser(req.user.id, 'message_updated', formattedMessage);
      }

      logger.info(`Message updated: ${messageId} by ${req.user.email}`);
      res.json(formattedMessage);
    } catch (error) {
      logger.error('Error updating message:', error);
      res.status(500).json({ error: 'Failed to update message' });
    }
  }

  // Delete message
  async deleteMessage(req, res) {
    try {
      const { messageId } = req.params;

      // Verify user owns the message
      const message = await prisma.chatMessage.findFirst({
        where: {
          id: messageId,
          senderId: req.user.id
        }
      });

      if (!message) {
        return res.status(404).json({ error: 'Message not found or access denied' });
      }

      await prisma.chatMessage.update({
        where: { id: messageId },
        data: { isDeleted: true }
      });

      // Emit deletion via socket
      if (message.channelId) {
        socketServer.emitToChannel(message.channelId, 'message_deleted', { messageId });
      } else if (message.recipientId) {
        socketServer.emitToUser(message.recipientId, 'message_deleted', { messageId });
        socketServer.emitToUser(req.user.id, 'message_deleted', { messageId });
      }

      logger.info(`Message deleted: ${messageId} by ${req.user.email}`);
      res.status(204).send();
    } catch (error) {
      logger.error('Error deleting message:', error);
      res.status(500).json({ error: 'Failed to delete message' });
    }
  }

  // Join channel
  async joinChannel(req, res) {
    try {
      const { channelId } = req.params;
      const membership = await chatService.joinChannel(req.user.id, channelId);
      
      logger.info(`User ${req.user.email} joined channel ${channelId}`);
      res.status(201).json(membership);
    } catch (error) {
      logger.error('Error joining channel:', error);
      res.status(400).json({ error: error.message });
    }
  }

  // Leave channel
  async leaveChannel(req, res) {
    try {
      const { channelId } = req.params;
      await chatService.leaveChannel(req.user.id, channelId);
      
      logger.info(`User ${req.user.email} left channel ${channelId}`);
      res.status(204).send();
    } catch (error) {
      logger.error('Error leaving channel:', error);
      res.status(400).json({ error: error.message });
    }
  }

  // Mark messages as read
  async markAsRead(req, res) {
    try {
      const { channelId } = req.params;
      const { messageId } = req.body;
      
      await chatService.markAsRead(req.user.id, channelId, messageId);
      
      res.status(204).send();
    } catch (error) {
      logger.error('Error marking messages as read:', error);
      res.status(400).json({ error: error.message });
    }
  }

  // Get direct conversations
  async getDirectConversations(req, res) {
    try {
      const conversations = await chatService.getDirectConversations(req.user.id);
      res.json(conversations);
    } catch (error) {
      logger.error('Error getting direct conversations:', error);
      res.status(500).json({ error: 'Failed to get conversations' });
    }
  }
}

module.exports = new ChatController();
