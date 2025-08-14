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
  const tasks = await knex('tasks').where({ project_id: projectId }).select('id','title','module_id');
  const deps = await knex('task_dependencies').join('tasks','task_dependencies.task_id','tasks.id').where('tasks.project_id', projectId).select('task_dependencies.*');
  const pert = await knex('pert_estimates').whereIn('task_id', tasks.map(t=>t.id));
  const modules = await knex('modules').where({ project_id: projectId }).select('id','name');
  const assignments = await knex('task_assignments').join('users','users.id','task_assignments.user_id').join('tasks','tasks.id','task_assignments.task_id').where('tasks.project_id', projectId).select('task_assignments.task_id','users.email');
  const pertMap = new Map(pert.map(p => [p.task_id, p]));
  const withET = tasks.map(t => {
    const p = pertMap.get(t.id);
    const expected_time = p ? (p.optimistic + 4*p.most_likely + p.pessimistic) / 6 : 1;
    return { ...t, expected_time };
  });
  res.json({ tasks: withET, dependencies: deps, modules, assignments });
});

export default router;

