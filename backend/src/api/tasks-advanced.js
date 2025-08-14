import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { requireAnyRole } from '../middleware/rbac.js';
import { knex } from '../db/index.js';

const router = express.Router({ mergeParams: true });
router.use(requireAuth);

// Update task with status rules
router.put('/:taskId', requireAnyRole(['Admin','Project Manager']), async (req, res) => {
  const taskId = Number(req.params.taskId);
  const patch = { ...req.body };

  // Auto set dates based on status changes
  if (patch.status_id) {
    const status = await knex('statuses').where({ id: patch.status_id }).first();
    if (status?.name === 'In Progress') {
      patch.start_date = patch.start_date || new Date();
    }
    if (status?.name === 'Completed') {
      patch.end_date = patch.end_date || new Date();
    }
  }

  const [row] = await knex('tasks').where({ id: taskId }).update(patch).returning('*');
  try { const { emitTaskUpdated } = await import('../events.js'); emitTaskUpdated(row); } catch {}
  res.json(row);
});

// Assign/unassign users to task
router.post('/:taskId/assignments', requireAnyRole(['Admin','Project Manager']), async (req, res) => {
  const taskId = Number(req.params.taskId);
  const { user_id, is_owner, role } = req.body;
  const [row] = await knex('task_assignments')
    .insert({ task_id: taskId, user_id, is_owner: !!is_owner, role })
    .onConflict(['task_id','user_id']).merge(['is_owner','role'])
    .returning('*');
  res.status(201).json(row);
});

router.delete('/:taskId/assignments/:userId', requireAnyRole(['Admin','Project Manager']), async (req, res) => {
  const taskId = Number(req.params.taskId);
  const userId = Number(req.params.userId);
  await knex('task_assignments').where({ task_id: taskId, user_id: userId }).del();
  res.json({ ok: true });
});

// Time entries
router.get('/:taskId/time-entries', async (req, res) => {
  const taskId = Number(req.params.taskId);
  const rows = await knex('time_entries').where({ task_id: taskId }).orderBy('id', 'desc');
  res.json(rows);
});

router.post('/:taskId/time-entries', async (req, res) => {
  const taskId = Number(req.params.taskId);
  const { start, end, minutes, notes } = req.body;
  const [row] = await knex('time_entries').insert({ task_id: taskId, user_id: req.user.id, start, end, minutes, notes }).returning('*');
  res.status(201).json(row);
});

export default router;

