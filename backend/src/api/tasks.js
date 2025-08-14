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
  const { title, description } = req.body;
  if (!title) return res.status(400).json({ error: 'title required' });
  const [row] = await knex('tasks').insert({ project_id: projectId, title, description }).returning('*');
  res.status(201).json(row);
});

export default router;

