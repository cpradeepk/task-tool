import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { requireAnyRole } from '../middleware/rbac.js';
import { knex } from '../db/index.js';

const router = express.Router();
router.use(requireAuth);

router.get('/:table', async (req, res) => {
  const table = req.params.table;
  if (!['statuses','priorities','task_types','project_types'].includes(table)) return res.status(400).json({ error: 'invalid table' });
  const rows = await knex(table).select('*').orderBy('id', 'asc');
  res.json(rows);
});

router.post('/:table', requireAnyRole(['Admin']), async (req, res) => {
  const table = req.params.table;
  if (!['statuses','priorities','task_types','project_types'].includes(table)) return res.status(400).json({ error: 'invalid table' });
  const [row] = await knex(table).insert(req.body).returning('*');
  res.status(201).json(row);
});

router.put('/:table/:id', requireAnyRole(['Admin']), async (req, res) => {
  const table = req.params.table;
  const id = Number(req.params.id);
  if (!['statuses','priorities','task_types','project_types'].includes(table)) return res.status(400).json({ error: 'invalid table' });
  const [row] = await knex(table).where({ id }).update(req.body).returning('*');
  res.json(row);
});

router.delete('/:table/:id', requireAnyRole(['Admin']), async (req, res) => {
  const table = req.params.table;
  const id = Number(req.params.id);
  if (!['statuses','priorities','task_types','project_types'].includes(table)) return res.status(400).json({ error: 'invalid table' });
  await knex(table).where({ id }).del();
  res.json({ ok: true });
});

export default router;

