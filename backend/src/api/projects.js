import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';
import { requireAnyRole } from '../middleware/rbac.js';

const router = express.Router();

router.use(requireAuth);

router.get('/', async (req, res) => {
  const rows = await knex('projects').select('*').orderBy('id', 'desc');
  res.json(rows);
});

router.post('/', requireAnyRole(['Admin','Project Manager']), async (req, res) => {
  const { name, start_date } = req.body;
  if (!name) return res.status(400).json({ error: 'name required' });
  const [row] = await knex('projects').insert({ name, start_date }).returning('*');
  res.status(201).json(row);
});

router.put('/:id', requireAnyRole(['Admin','Project Manager']), async (req, res) => {
  const id = Number(req.params.id);
  const { name, start_date } = req.body;
  const [row] = await knex('projects').where({ id }).update({ name, start_date }).returning('*');
  res.json(row);
});

router.delete('/:id', requireAnyRole(['Admin','Project Manager']), async (req, res) => {
  const id = Number(req.params.id);
  await knex('projects').where({ id }).del();
  res.json({ ok: true });
});

export default router;

