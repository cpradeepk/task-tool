import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { requireAnyRole } from '../middleware/rbac.js';
import { knex } from '../db/index.js';

const router = express.Router({ mergeParams: true });
router.use(requireAuth);

// Dependencies
router.get('/:taskId/dependencies', async (req, res) => {
  const taskId = Number(req.params.taskId);
  const rows = await knex('task_dependencies').where({ task_id: taskId }).select('*');
  res.json(rows);
});

router.post('/:taskId/dependencies', requireAnyRole(['Admin','Project Manager']), async (req, res) => {
  const taskId = Number(req.params.taskId);
  const { depends_on_task_id, type } = req.body;
  const [row] = await knex('task_dependencies').insert({ task_id: taskId, depends_on_task_id, type: type || 'PRE' }).returning('*');
  res.status(201).json(row);
});

router.delete('/:taskId/dependencies/:depId', requireAnyRole(['Admin','Project Manager']), async (req, res) => {
  const depId = Number(req.params.depId);
  await knex('task_dependencies').where({ id: depId }).del();
  res.json({ ok: true });
});

// PERT
router.get('/:taskId/pert', async (req, res) => {
  const taskId = Number(req.params.taskId);
  const row = await knex('pert_estimates').where({ task_id: taskId }).first();
  res.json(row || {});
});

router.post('/:taskId/pert', requireAnyRole(['Admin','Project Manager']), async (req, res) => {
  const taskId = Number(req.params.taskId);
  const { optimistic, most_likely, pessimistic } = req.body;
  const exists = await knex('pert_estimates').where({ task_id: taskId }).first();
  let row;
  if (exists) {
    [row] = await knex('pert_estimates').where({ task_id: taskId }).update({ optimistic, most_likely, pessimistic }).returning('*');
  } else {
    [row] = await knex('pert_estimates').insert({ task_id: taskId, optimistic, most_likely, pessimistic }).returning('*');
  }
  res.json(row);
});

// Critical path (simplified expected time = (O + 4M + P)/6)
router.get('/project/:projectId/critical-path', async (req, res) => {
  const projectId = Number(req.params.projectId);
  const tasks = await knex('tasks').where({ project_id: projectId }).select('id','title');
  // NOTE: For brevity we return tasks and dependencies; client can render. Full CP calc to be extended.
  const deps = await knex('task_dependencies').join('tasks','task_dependencies.task_id','tasks.id').where('tasks.project_id', projectId).select('task_dependencies.*');
  res.json({ tasks, dependencies: deps });
});

export default router;

