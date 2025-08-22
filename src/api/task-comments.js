import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';
import { requireAnyRole, userHasRole } from '../middleware/rbac.js';

const router = express.Router({ mergeParams: true });
router.use(requireAuth);

// Get task comments
router.get('/:taskId/comments', async (req, res) => {
  try {
    const taskId = parseInt(req.params.taskId);
    const userId = req.user.id;
    
    // Verify task exists and user has access
    const task = await knex('tasks').where('id', taskId).first();
    if (!task) {
      return res.status(404).json({ error: 'Task not found' });
    }
    
    // Check if user has access to this task
    const hasAccess = task.assigned_to === userId || 
                     await userHasRole(userId, ['Admin', 'Project Manager', 'Team Lead']) ||
                     await knex('task_support')
                       .where({ task_id: taskId, employee_id: userId, is_active: true })
                       .first();
    
    if (!hasAccess) {
      return res.status(403).json({ error: 'Access denied' });
    }
    
    const comments = await knex('task_comments')
      .select(
        'task_comments.*',
        'users.email as author_email',
        'users.name as author_name'
      )
      .leftJoin('users', 'task_comments.author_id', 'users.id')
      .where('task_comments.task_id', taskId)
      .whereNull('task_comments.deleted_at')
      .orderBy('task_comments.created_at', 'asc');
    
    res.json(comments);
  } catch (err) {
    console.error('Error fetching task comments:', err);
    res.status(500).json({ error: 'Failed to fetch task comments' });
  }
});

// Add task comment
router.post('/:taskId/comments', async (req, res) => {
  try {
    const taskId = parseInt(req.params.taskId);
    const userId = req.user.id;
    const { content, is_internal, attachments } = req.body;
    
    if (!content || content.trim().length === 0) {
      return res.status(400).json({ error: 'Comment content is required' });
    }
    
    // Verify task exists and user has access
    const task = await knex('tasks').where('id', taskId).first();
    if (!task) {
      return res.status(404).json({ error: 'Task not found' });
    }
    
    // Check if user has access to this task
    const hasAccess = task.assigned_to === userId || 
                     await userHasRole(userId, ['Admin', 'Project Manager', 'Team Lead']) ||
                     await knex('task_support')
                       .where({ task_id: taskId, employee_id: userId, is_active: true })
                       .first();
    
    if (!hasAccess) {
      return res.status(403).json({ error: 'Access denied' });
    }
    
    const [commentId] = await knex('task_comments').insert({
      task_id: taskId,
      author_id: userId,
      content: content.trim(),
      is_internal: is_internal || false,
      attachments: attachments ? JSON.stringify(attachments) : null,
    }).returning('id');
    
    // Log the comment in task history
    await knex('task_history').insert({
      task_id: taskId,
      changed_by: userId,
      change_type: 'comment_added',
      comment: `Added ${is_internal ? 'internal ' : ''}comment`
    });
    
    // Get the created comment with author info
    const newComment = await knex('task_comments')
      .select(
        'task_comments.*',
        'users.email as author_email',
        'users.name as author_name'
      )
      .leftJoin('users', 'task_comments.author_id', 'users.id')
      .where('task_comments.id', commentId)
      .first();
    
    res.status(201).json(newComment);
  } catch (err) {
    console.error('Error adding task comment:', err);
    res.status(500).json({ error: 'Failed to add task comment' });
  }
});

// Update task comment
router.put('/:taskId/comments/:commentId', async (req, res) => {
  try {
    const taskId = parseInt(req.params.taskId);
    const commentId = parseInt(req.params.commentId);
    const userId = req.user.id;
    const { content } = req.body;
    
    if (!content || content.trim().length === 0) {
      return res.status(400).json({ error: 'Comment content is required' });
    }
    
    // Verify comment exists and user is the author or has admin access
    const comment = await knex('task_comments')
      .where({ id: commentId, task_id: taskId })
      .whereNull('deleted_at')
      .first();
    
    if (!comment) {
      return res.status(404).json({ error: 'Comment not found' });
    }
    
    const canEdit = comment.author_id === userId || 
                   await userHasRole(userId, ['Admin', 'Project Manager']);
    
    if (!canEdit) {
      return res.status(403).json({ error: 'Access denied' });
    }
    
    await knex('task_comments')
      .where('id', commentId)
      .update({
        content: content.trim(),
        updated_at: knex.fn.now()
      });
    
    // Log the update
    await knex('task_history').insert({
      task_id: taskId,
      changed_by: userId,
      change_type: 'comment_updated',
      comment: 'Updated comment'
    });
    
    res.json({ success: true, message: 'Comment updated successfully' });
  } catch (err) {
    console.error('Error updating task comment:', err);
    res.status(500).json({ error: 'Failed to update task comment' });
  }
});

// Delete task comment (soft delete)
router.delete('/:taskId/comments/:commentId', async (req, res) => {
  try {
    const taskId = parseInt(req.params.taskId);
    const commentId = parseInt(req.params.commentId);
    const userId = req.user.id;
    
    // Verify comment exists and user is the author or has admin access
    const comment = await knex('task_comments')
      .where({ id: commentId, task_id: taskId })
      .whereNull('deleted_at')
      .first();
    
    if (!comment) {
      return res.status(404).json({ error: 'Comment not found' });
    }
    
    const canDelete = comment.author_id === userId || 
                     await userHasRole(userId, ['Admin', 'Project Manager']);
    
    if (!canDelete) {
      return res.status(403).json({ error: 'Access denied' });
    }
    
    await knex('task_comments')
      .where('id', commentId)
      .update({ deleted_at: knex.fn.now() });
    
    // Log the deletion
    await knex('task_history').insert({
      task_id: taskId,
      changed_by: userId,
      change_type: 'comment_deleted',
      comment: 'Deleted comment'
    });
    
    res.json({ success: true, message: 'Comment deleted successfully' });
  } catch (err) {
    console.error('Error deleting task comment:', err);
    res.status(500).json({ error: 'Failed to delete task comment' });
  }
});

// Get task history
router.get('/:taskId/history', async (req, res) => {
  try {
    const taskId = parseInt(req.params.taskId);
    const userId = req.user.id;
    
    // Verify task exists and user has access
    const task = await knex('tasks').where('id', taskId).first();
    if (!task) {
      return res.status(404).json({ error: 'Task not found' });
    }
    
    // Check if user has access to this task
    const hasAccess = task.assigned_to === userId || 
                     await userHasRole(userId, ['Admin', 'Project Manager', 'Team Lead']) ||
                     await knex('task_support')
                       .where({ task_id: taskId, employee_id: userId, is_active: true })
                       .first();
    
    if (!hasAccess) {
      return res.status(403).json({ error: 'Access denied' });
    }
    
    const history = await knex('task_history')
      .select(
        'task_history.*',
        'users.email as changed_by_email',
        'users.name as changed_by_name'
      )
      .leftJoin('users', 'task_history.changed_by', 'users.id')
      .where('task_history.task_id', taskId)
      .orderBy('task_history.changed_at', 'desc');
    
    res.json(history);
  } catch (err) {
    console.error('Error fetching task history:', err);
    res.status(500).json({ error: 'Failed to fetch task history' });
  }
});

// Get task activity feed (comments + history combined)
router.get('/:taskId/activity', async (req, res) => {
  try {
    const taskId = parseInt(req.params.taskId);
    const userId = req.user.id;
    
    // Verify task exists and user has access
    const task = await knex('tasks').where('id', taskId).first();
    if (!task) {
      return res.status(404).json({ error: 'Task not found' });
    }
    
    // Check if user has access to this task
    const hasAccess = task.assigned_to === userId || 
                     await userHasRole(userId, ['Admin', 'Project Manager', 'Team Lead']) ||
                     await knex('task_support')
                       .where({ task_id: taskId, employee_id: userId, is_active: true })
                       .first();
    
    if (!hasAccess) {
      return res.status(403).json({ error: 'Access denied' });
    }
    
    // Get comments
    const comments = await knex('task_comments')
      .select(
        knex.raw("'comment' as type"),
        'id',
        'content as description',
        'author_id as user_id',
        'created_at as timestamp',
        'is_internal'
      )
      .where('task_id', taskId)
      .whereNull('deleted_at');
    
    // Get history
    const history = await knex('task_history')
      .select(
        knex.raw("'history' as type"),
        'id',
        'comment as description',
        'changed_by as user_id',
        'changed_at as timestamp',
        'change_type',
        'old_values',
        'new_values'
      )
      .where('task_id', taskId);
    
    // Combine and sort by timestamp
    const activity = [...comments, ...history]
      .sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
    
    // Get user info for all activities
    const userIds = [...new Set(activity.map(a => a.user_id))];
    const users = await knex('users')
      .select('id', 'email', 'name')
      .whereIn('id', userIds);
    
    const userMap = users.reduce((acc, user) => {
      acc[user.id] = user;
      return acc;
    }, {});
    
    // Enrich activity with user info
    const enrichedActivity = activity.map(item => ({
      ...item,
      user: userMap[item.user_id] || { email: 'Unknown', name: 'Unknown User' }
    }));
    
    res.json(enrichedActivity);
  } catch (err) {
    console.error('Error fetching task activity:', err);
    res.status(500).json({ error: 'Failed to fetch task activity' });
  }
});

export default router;
