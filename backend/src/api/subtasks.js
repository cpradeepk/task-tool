import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';
import { requireAnyRole } from '../middleware/rbac.js';

const router = express.Router({ mergeParams: true });
router.use(requireAuth);

// Get all subtasks for a task
router.get('/', async (req, res) => {
  const taskId = Number(req.params.taskId);
  const rows = await knex('subtasks')
    .where({ task_id: taskId })
    .orderBy('id', 'asc');
  res.json(rows);
});

// Create a new subtask
router.post('/', requireAnyRole(['Admin', 'Project Manager', 'Team Lead']), async (req, res) => {
  const taskId = Number(req.params.taskId);
  const { title, status } = req.body;

  if (!title) {
    return res.status(400).json({ error: 'title required' });
  }

  // Verify the parent task exists
  const parentTask = await knex('tasks').where({ id: taskId }).first();
  if (!parentTask) {
    return res.status(404).json({ error: 'parent task not found' });
  }

  const [row] = await knex('subtasks')
    .insert({
      task_id: taskId,
      title: title.trim(),
      status: status || 'Open'
    })
    .returning('*');

  res.status(201).json(row);
});

// Update a subtask
router.put('/:subtaskId', requireAnyRole(['Admin', 'Project Manager', 'Team Lead']), async (req, res) => {
  const subtaskId = Number(req.params.subtaskId);
  const { title, status } = req.body;

  const updateData = {};
  if (title !== undefined) updateData.title = title.trim();
  if (status !== undefined) updateData.status = status;

  const [row] = await knex('subtasks')
    .where({ id: subtaskId })
    .update(updateData)
    .returning('*');

  if (!row) {
    return res.status(404).json({ error: 'subtask not found' });
  }

  res.json(row);
});

// Delete a subtask
router.delete('/:subtaskId', requireAnyRole(['Admin', 'Project Manager']), async (req, res) => {
  const subtaskId = Number(req.params.subtaskId);
  
  const deleted = await knex('subtasks').where({ id: subtaskId }).del();
  
  if (deleted === 0) {
    return res.status(404).json({ error: 'subtask not found' });
  }

  res.json({ ok: true });
});

export default router;
