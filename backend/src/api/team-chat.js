import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { requireAnyRole } from '../middleware/rbac.js';
import { knex } from '../db/index.js';
import { asyncHandler, ValidationError, NotFoundError } from '../middleware/errorHandler.js';

const router = express.Router();
router.use(requireAuth);

// Get all channels user has access to
router.get('/channels', asyncHandler(async (req, res) => {
  const userId = req.user.id;
  
  // Get public channels and private channels user is member of
  const channels = await knex('chat_channels')
    .leftJoin('channel_members', function() {
      this.on('chat_channels.id', '=', 'channel_members.channel_id')
          .andOn('channel_members.user_id', '=', userId);
    })
    .where(function() {
      this.where('chat_channels.type', 'public')
          .orWhere('channel_members.user_id', userId);
    })
    .where('chat_channels.is_archived', false)
    .select(
      'chat_channels.*',
      knex.raw('CASE WHEN channel_members.user_id IS NOT NULL THEN true ELSE false END as is_member')
    )
    .orderBy('chat_channels.name');

  // Get member counts for each channel
  for (const channel of channels) {
    const memberCount = await knex('channel_members')
      .where('channel_id', channel.id)
      .count('* as count')
      .first();
    channel.member_count = parseInt(memberCount.count);
  }

  res.json(channels);
}));

// Create new channel (Admin/Project Manager only)
router.post('/channels', requireAnyRole(['Admin', 'Project Manager']), asyncHandler(async (req, res) => {
  const { name, description, type = 'public' } = req.body;
  
  if (!name || name.trim().length === 0) {
    throw new ValidationError('Channel name is required');
  }

  if (!['public', 'private'].includes(type)) {
    throw new ValidationError('Channel type must be public or private');
  }

  // Check if channel name already exists
  const existing = await knex('chat_channels')
    .where('name', name.trim())
    .first();
  
  if (existing) {
    throw new ValidationError('Channel name already exists');
  }

  const [channel] = await knex('chat_channels')
    .insert({
      name: name.trim(),
      description: description?.trim() || '',
      type,
      created_by: req.user.id,
      created_at: new Date(),
      updated_at: new Date(),
    })
    .returning('*');

  // Add creator as member
  await knex('channel_members').insert({
    channel_id: channel.id,
    user_id: req.user.id,
    role: 'admin',
    joined_at: new Date(),
  });

  res.status(201).json(channel);
}));

// Join a public channel
router.post('/channels/:channelId/join', asyncHandler(async (req, res) => {
  const channelId = parseInt(req.params.channelId);
  const userId = req.user.id;

  // Check if channel exists and is public
  const channel = await knex('chat_channels')
    .where('id', channelId)
    .first();

  if (!channel) {
    throw new NotFoundError('Channel');
  }

  if (channel.type === 'private') {
    throw new ValidationError('Cannot join private channel without invitation');
  }

  // Check if already a member
  const existing = await knex('channel_members')
    .where({ channel_id: channelId, user_id: userId })
    .first();

  if (existing) {
    return res.json({ message: 'Already a member of this channel' });
  }

  await knex('channel_members').insert({
    channel_id: channelId,
    user_id: userId,
    role: 'member',
    joined_at: new Date(),
  });

  res.json({ message: 'Successfully joined channel' });
}));

// Leave a channel
router.post('/channels/:channelId/leave', asyncHandler(async (req, res) => {
  const channelId = parseInt(req.params.channelId);
  const userId = req.user.id;

  const deleted = await knex('channel_members')
    .where({ channel_id: channelId, user_id: userId })
    .del();

  if (deleted === 0) {
    throw new NotFoundError('Channel membership');
  }

  res.json({ message: 'Successfully left channel' });
}));

// Get channel messages
router.get('/channels/:channelId/messages', asyncHandler(async (req, res) => {
  const channelId = parseInt(req.params.channelId);
  const userId = req.user.id;
  const limit = parseInt(req.query.limit) || 50;
  const offset = parseInt(req.query.offset) || 0;

  // Check if user has access to channel
  const channel = await knex('chat_channels')
    .where('id', channelId)
    .first();

  if (!channel) {
    throw new NotFoundError('Channel');
  }

  if (channel.type === 'private') {
    const membership = await knex('channel_members')
      .where({ channel_id: channelId, user_id: userId })
      .first();
    
    if (!membership) {
      throw new ValidationError('Access denied to private channel');
    }
  }

  const messages = await knex('chat_messages')
    .join('users', 'users.id', 'chat_messages.user_id')
    .where('chat_messages.channel_id', channelId)
    .orderBy('chat_messages.created_at', 'desc')
    .limit(limit)
    .offset(offset)
    .select(
      'chat_messages.*',
      'users.email',
      'users.name as user_name'
    );

  // Reverse to show oldest first
  messages.reverse();

  res.json(messages);
}));

// Send message to channel
router.post('/channels/:channelId/messages', asyncHandler(async (req, res) => {
  const channelId = parseInt(req.params.channelId);
  const userId = req.user.id;
  const { content, type = 'text' } = req.body;

  if (!content || content.trim().length === 0) {
    throw new ValidationError('Message content is required');
  }

  // Check if user has access to channel
  const channel = await knex('chat_channels')
    .where('id', channelId)
    .first();

  if (!channel) {
    throw new NotFoundError('Channel');
  }

  if (channel.type === 'private') {
    const membership = await knex('channel_members')
      .where({ channel_id: channelId, user_id: userId })
      .first();
    
    if (!membership) {
      throw new ValidationError('Access denied to private channel');
    }
  }

  const [message] = await knex('chat_messages')
    .insert({
      channel_id: channelId,
      user_id: userId,
      content: content.trim(),
      type,
      created_at: new Date(),
    })
    .returning('*');

  // Get user info for response
  const user = await knex('users')
    .where('id', userId)
    .select('email', 'name')
    .first();

  const messageWithUser = {
    ...message,
    email: user.email,
    user_name: user.name,
  };

  // TODO: Emit socket event for real-time updates
  try {
    const { emitChatMessage } = await import('../events.js');
    emitChatMessage(messageWithUser);
  } catch (e) {
    console.log('Socket emission failed:', e.message);
  }

  res.status(201).json(messageWithUser);
}));

// Get channel members
router.get('/channels/:channelId/members', asyncHandler(async (req, res) => {
  const channelId = parseInt(req.params.channelId);
  const userId = req.user.id;

  // Check if user has access to channel
  const channel = await knex('chat_channels')
    .where('id', channelId)
    .first();

  if (!channel) {
    throw new NotFoundError('Channel');
  }

  if (channel.type === 'private') {
    const membership = await knex('channel_members')
      .where({ channel_id: channelId, user_id: userId })
      .first();
    
    if (!membership) {
      throw new ValidationError('Access denied to private channel');
    }
  }

  const members = await knex('channel_members')
    .join('users', 'users.id', 'channel_members.user_id')
    .where('channel_members.channel_id', channelId)
    .select(
      'users.id',
      'users.email',
      'users.name',
      'channel_members.role',
      'channel_members.joined_at'
    )
    .orderBy('channel_members.joined_at');

  res.json(members);
}));

// Add member to private channel (Admin/Channel Admin only)
router.post('/channels/:channelId/members', asyncHandler(async (req, res) => {
  const channelId = parseInt(req.params.channelId);
  const { user_id } = req.body;
  const requesterId = req.user.id;

  if (!user_id) {
    throw new ValidationError('User ID is required');
  }

  // Check if channel exists
  const channel = await knex('chat_channels')
    .where('id', channelId)
    .first();

  if (!channel) {
    throw new NotFoundError('Channel');
  }

  // Check if requester has permission (Admin or channel admin)
  const isAdmin = req.user.roles?.includes('Admin');
  const isChannelAdmin = await knex('channel_members')
    .where({ channel_id: channelId, user_id: requesterId, role: 'admin' })
    .first();

  if (!isAdmin && !isChannelAdmin) {
    throw new ValidationError('Insufficient permissions to add members');
  }

  // Check if user already a member
  const existing = await knex('channel_members')
    .where({ channel_id: channelId, user_id })
    .first();

  if (existing) {
    return res.json({ message: 'User is already a member' });
  }

  await knex('channel_members').insert({
    channel_id: channelId,
    user_id,
    role: 'member',
    joined_at: new Date(),
  });

  res.json({ message: 'Member added successfully' });
}));

export default router;
