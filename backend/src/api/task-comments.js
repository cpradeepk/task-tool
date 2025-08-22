import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';

const router = express.Router();

// All routes require authentication
router.use(requireAuth);

// Get task comments
router.get('/:taskId/comments', async (req, res) => {
  try {
    const { taskId } = req.params;
    
    const comments = await knex('task_comments')
      .where('task_id', taskId)
      .orderBy('created_at', 'desc')
      .select('*');
    
    res.json(comments);
  } catch (err) {
    console.error('Get task comments error:', err);
    res.status(500).json({ error: 'Failed to fetch task comments' });
  }
});

// Add task comment
router.post('/:taskId/comments', async (req, res) => {
  try {
    const { taskId } = req.params;
    const { comment } = req.body;
    const userId = req.user.id;
    
    if (!comment) {
      return res.status(400).json({ error: 'Comment is required' });
    }
    
    const [newComment] = await knex('task_comments')
      .insert({
        task_id: taskId,
        user_id: userId,
        comment,
        created_at: new Date()
      })
      .returning('*');
    
    res.status(201).json(newComment);
  } catch (err) {
    console.error('Add task comment error:', err);
    res.status(500).json({ error: 'Failed to add task comment' });
  }
});

// Get task history
router.get('/:taskId/history', async (req, res) => {
  try {
    const { taskId } = req.params;
    
    const history = await knex('task_history')
      .where('task_id', taskId)
      .orderBy('created_at', 'desc')
      .select('*');
    
    res.json(history);
  } catch (err) {
    console.error('Get task history error:', err);
    res.status(500).json({ error: 'Failed to fetch task history' });
  }
});

export default router;
