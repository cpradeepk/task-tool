import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { requireAnyRole } from '../middleware/rbac.js';
import { knex } from '../db/index.js';

const router = express.Router({ mergeParams: true });
router.use(requireAuth);

// Update task with status rules
async function userHasRole(userId, roles) {
  const rows = await knex('user_roles')
    .join('roles','roles.id','user_roles.role_id')
    .where('user_roles.user_id', userId)
    .whereIn('roles.name', roles)
    .select('roles.name');
  return rows.length > 0;
}

router.put('/:taskId', requireAnyRole(['Admin','Project Manager','Team Member']), async (req, res) => {
  try {
    const taskId = Number(req.params.taskId);
    const patch = { ...req.body };

    console.log('Advanced task update:', taskId, 'with data:', patch);
    console.log('User:', req.user);

    // Check if statuses table exists for status_id handling
    const statusesExists = await knex.schema.hasTable('statuses');
    const prioritiesExists = await knex.schema.hasTable('priorities');

    // Auto set dates based on status changes
    if (patch.status_id && statusesExists) {
      const status = await knex('statuses').where({ id: patch.status_id }).first();
      if (status?.name === 'In Progress') {
        patch.start_date = patch.start_date || new Date();
      }
      if (status?.name === 'Completed') {
        patch.end_date = patch.end_date || new Date();
      }
    }

    // Handle legacy status field if status_id is not available
    if (patch.status_id && !statusesExists) {
      // Map status_id to legacy status string
      const statusMap = {
        1: 'Open',
        2: 'In Progress',
        3: 'Completed',
        4: 'Cancelled',
        5: 'Hold',
        6: 'Delayed'
      };
      patch.status = statusMap[patch.status_id] || 'Open';
      delete patch.status_id; // Remove status_id if table doesn't exist
    }

    // Handle legacy priority field if priority_id is not available
    if (patch.priority_id && !prioritiesExists) {
      // Map priority_id to legacy priority string
      const priorityMap = {
        1: 'High',        // Important & Urgent
        2: 'Medium',      // Important & Not Urgent
        3: 'Low',         // Not Important & Urgent
        4: 'Low'          // Not Important & Not Urgent
      };
      patch.priority = priorityMap[patch.priority_id] || 'Medium';
      delete patch.priority_id; // Remove priority_id if table doesn't exist
    }

    const [row] = await knex('tasks').where({ id: taskId }).update(patch).returning('*');
    console.log('Advanced task updated successfully:', row);

    try { const { emitTaskUpdated } = await import('../events.js'); emitTaskUpdated(row); } catch {}

    // Email notify assignees on status change
    if (patch.status_id || patch.status) {
      try {
        const taskAssignmentsExists = await knex.schema.hasTable('task_assignments');
        if (taskAssignmentsExists) {
          const emails = await knex('task_assignments').join('users','users.id','task_assignments.user_id').where('task_assignments.task_id', taskId).select('users.email');
          const { emailQueue } = await import('../queue/index.js');
          for (const e of emails) {
            await emailQueue.add('send', { to: e.email, subject: 'Task status updated', html: `<p>Task #${taskId} status changed.</p>` }, { removeOnComplete: true });
          }
        }
      } catch (emailError) {
        console.log('Email notification failed:', emailError);
      }
    }

    res.json(row);
  } catch (error) {
    console.error('Error in advanced task update:', error);
    res.status(500).json({ error: 'Failed to update task', details: error.message });
  }
});

// Assignments
router.get('/:taskId/assignments', async (req, res) => {
  const taskId = Number(req.params.taskId);
  const rows = await knex('task_assignments').join('users','users.id','task_assignments.user_id').where('task_id', taskId).select('task_assignments.*','users.email');
  res.json(rows);
});

// Assign/unassign users to task
router.post('/:taskId/assignments', requireAnyRole(['Admin','Project Manager','Team Member']), async (req, res) => {
  const taskId = Number(req.params.taskId);
  const { user_id, is_owner, role } = req.body;
  // Only one owner at a time: if setting is_owner true, clear others
  if (is_owner) {
    await knex('task_assignments').where({ task_id: taskId, is_owner: true }).update({ is_owner: false });
  }
  const [row] = await knex('task_assignments')
    .insert({ task_id: taskId, user_id, is_owner: !!is_owner, role })
    .onConflict(['task_id','user_id']).merge(['is_owner','role'])
    .returning('*');

  // Email notify assigned user
  try {
    const assignee = await knex('users').where({ id: user_id }).first();
    const { emailQueue } = await import('../queue/index.js');
    await emailQueue.add('send', { to: assignee.email, subject: 'You were assigned to a task', html: `<p>You were assigned to Task #${taskId}.</p>` }, { removeOnComplete: true });
  } catch {}

  res.status(201).json(row);
});

router.delete('/:taskId/assignments/:userId', requireAnyRole(['Admin','Project Manager','Team Member']), async (req, res) => {
  const taskId = Number(req.params.taskId);
  const userId = Number(req.params.userId);
  await knex('task_assignments').where({ task_id: taskId, user_id: userId }).del();
  res.json({ ok: true });
});

// Time entries
router.get('/:taskId/time-entries', async (req, res) => {
  const taskId = Number(req.params.taskId);
  const rows = await knex('time_entries')
    .leftJoin('users','users.id','time_entries.user_id')
    .where({ task_id: taskId })
    .orderBy('time_entries.id', 'desc')
    .select('time_entries.*','users.email');
  res.json(rows);
});

router.post('/:taskId/time-entries', async (req, res) => {
  const taskId = Number(req.params.taskId);
  const { start, end, minutes, notes } = req.body;
  const [row] = await knex('time_entries').insert({ task_id: taskId, user_id: req.user.id, start: start || new Date(), end, minutes, notes }).returning('*');
  res.status(201).json(row);
});

router.put('/:taskId/time-entries/:id', async (req, res) => {
  const taskId = Number(req.params.taskId);
  const id = Number(req.params.id);
  const patch = req.body;
  // Allow owner of entry or Admin/PM
  const entry = await knex('time_entries').where({ id, task_id: taskId }).first();
  if (!entry) return res.status(404).json({ error: 'Not found' });
  if (entry.user_id !== req.user.id && !(await userHasRole(req.user.id, ['Admin','Project Manager']))) return res.status(403).json({ error: 'Forbidden' });
  const [row] = await knex('time_entries').where({ id }).update(patch).returning('*');
  res.json(row);
});

router.delete('/:taskId/time-entries/:id', async (req, res) => {
  const taskId = Number(req.params.taskId);
  const id = Number(req.params.id);
  const entry = await knex('time_entries').where({ id, task_id: taskId }).first();
  if (!entry) return res.status(404).json({ error: 'Not found' });
  if (entry.user_id !== req.user.id && !(await userHasRole(req.user.id, ['Admin','Project Manager']))) return res.status(403).json({ error: 'Forbidden' });
  await knex('time_entries').where({ id }).del();
  res.json({ ok: true });
});

router.put('/:taskId/time-entries/stop', async (req, res) => {
  const taskId = Number(req.params.taskId);
  // Find the latest open entry (no end) by this user
  const last = await knex('time_entries').where({ task_id: taskId, user_id: req.user.id }).whereNull('end').orderBy('id','desc').first();
  if (!last) return res.status(404).json({ error: 'No running timer' });
  const end = new Date();
  const start = new Date(last.start);
  const minutes = Math.max(1, Math.round((end.getTime() - start.getTime())/60000));
  const [row] = await knex('time_entries').where({ id: last.id }).update({ end, minutes }).returning('*');
  res.json(row);
});

export default router;

