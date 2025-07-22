const express = require('express');
const { authenticateToken, requireAdmin } = require('../middleware/auth');
const chatController = require('../controllers/chatController');

const router = express.Router();

// Channel routes
router.get('/channels', authenticateToken, chatController.getChannels);
router.post('/channels', authenticateToken, chatController.createChannel);
router.get('/channels/:channelId', authenticateToken, chatController.getChannel);
router.put('/channels/:channelId', authenticateToken, chatController.updateChannel);
router.delete('/channels/:channelId', authenticateToken, chatController.deleteChannel);

// Channel membership routes
router.post('/channels/:channelId/join', authenticateToken, chatController.joinChannel);
router.post('/channels/:channelId/leave', authenticateToken, chatController.leaveChannel);
router.post('/channels/:channelId/read', authenticateToken, chatController.markAsRead);

// Message routes
router.get('/messages', authenticateToken, chatController.getMessages);
router.post('/messages', authenticateToken, chatController.sendMessage);
router.put('/messages/:messageId', authenticateToken, chatController.updateMessage);
router.delete('/messages/:messageId', authenticateToken, chatController.deleteMessage);

// Direct message routes
router.get('/conversations', authenticateToken, chatController.getDirectConversations);

module.exports = router;
