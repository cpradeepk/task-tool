import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';
import { requireAnyRole } from '../middleware/rbac.js';

const router = express.Router({ mergeParams: true });
router.use(requireAuth);

router.get('/', async (req, res) => {
  const projectId = Number(req.params.projectId);
  const rows = await knex('tasks').where({ project_id: projectId }).orderBy('id', 'desc');
  res.json(rows);
});

router.post('/', requireAnyRole(['Admin','Project Manager']), async (req, res) => {
  const projectId = Number(req.params.projectId);
  const { title, description, module_id, status_id, priority_id, task_type_id, planned_end_date, start_date, end_date } = req.body;

  // Enforce hierarchy: Tasks must belong to a module
  if (!title) return res.status(400).json({ error: 'title required' });
  if (!module_id) return res.status(400).json({ error: 'module_id required - tasks must be created within a module' });

  // Verify module belongs to the project
  const module = await knex('modules').where({ id: module_id, project_id: projectId }).first();
  if (!module) return res.status(400).json({ error: 'invalid module_id for this project' });

  const [row] = await knex('tasks').insert({ project_id: projectId, module_id, title, description, status_id, priority_id, task_type_id, planned_end_date, start_date, end_date }).returning('*');
  try { const { emitTaskCreated } = await import('../events.js'); emitTaskCreated(row); } catch {}
  res.status(201).json(row);
});

router.put('/:taskId', requireAnyRole(['Admin','Project Manager']), async (req, res) => {
  const taskId = Number(req.params.taskId);
  const [row] = await knex('tasks').where({ id: taskId }).update(req.body).returning('*');
  res.json(row);
});

router.delete('/:taskId', requireAnyRole(['Admin','Project Manager']), async (req, res) => {
  const taskId = Number(req.params.taskId);
  await knex('tasks').where({ id: taskId }).del();
  res.json({ ok: true });
});

export default router;

