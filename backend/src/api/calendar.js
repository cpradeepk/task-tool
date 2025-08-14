import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';
import { createEvents } from 'ics';

const router = express.Router();
router.use(requireAuth);

router.get('/user.ics', async (req, res) => {
  const tasks = await knex('tasks')
    .join('task_assignments','task_assignments.task_id','tasks.id')
    .where('task_assignments.user_id', req.user.id)
    .select('tasks.*')
    .limit(500);

  const events = tasks.map(t => ({
    title: t.title,
    start: t.start_date ? [t.start_date.getUTCFullYear(), t.start_date.getUTCMonth()+1, t.start_date.getUTCDate(), 9, 0] : undefined,
    end: t.planned_end_date ? [t.planned_end_date.getUTCFullYear(), t.planned_end_date.getUTCMonth()+1, t.planned_end_date.getUTCDate(), 18, 0] : undefined,
    description: t.description || ''
  })).filter(e => !!e.start && !!e.end);

  const { error, value } = createEvents(events);
  if (error) return res.status(500).send('ICS error');
  res.setHeader('Content-Type', 'text/calendar; charset=utf-8');
  res.setHeader('Content-Disposition', 'attachment; filename=user-tasks.ics');
  res.send(value);
});

export default router;

