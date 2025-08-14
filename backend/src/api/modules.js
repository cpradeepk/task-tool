import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';
import { requireAnyRole } from '../middleware/rbac.js';

const router = express.Router({ mergeParams: true });
router.use(requireAuth);

router.get('/', async (req, res) => {
  const projectId = Number(req.params.projectId);
  const rows = await knex('modules').where({ project_id: projectId }).orderBy('id', 'desc');
  res.json(rows);
});

router.post('/', requireAnyRole(['Admin','Project Manager']), async (req, res) => {
  const projectId = Number(req.params.projectId);
  const { name } = req.body;
  if (!name) return res.status(400).json({ error: 'name required' });
  const [row] = await knex('modules').insert({ project_id: projectId, name }).returning('*');
  res.status(201).json(row);
});

router.put('/:moduleId', requireAnyRole(['Admin','Project Manager']), async (req, res) => {
  const moduleId = Number(req.params.moduleId);
  const { name } = req.body;
  const [row] = await knex('modules').where({ id: moduleId }).update({ name }).returning('*');
  res.json(row);
});

router.delete('/:moduleId', requireAnyRole(['Admin','Project Manager']), async (req, res) => {
  const moduleId = Number(req.params.moduleId);
  await knex('modules').where({ id: moduleId }).del();
  res.json({ ok: true });
});

export default router;

