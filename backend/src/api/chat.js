import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';

const router = express.Router();
router.use(requireAuth);

router.post('/threads', async (req, res) => {
  const { scope, scope_id } = req.body;
  const exists = await knex('threads').where({ scope, scope_id }).first();
  if (exists) return res.json(exists);
  const [row] = await knex('threads').insert({ scope, scope_id }).returning('*');
  res.status(201).json(row);
});

router.get('/threads/:id/messages', async (req, res) => {
  const threadId = Number(req.params.id);
  const rows = await knex('messages').where({ thread_id: threadId }).orderBy('id', 'asc');
  res.json(rows);
});

router.post('/threads/:id/messages', async (req, res) => {
  const threadId = Number(req.params.id);
  const { kind, body } = req.body;
  const [row] = await knex('messages').insert({ thread_id: threadId, user_id: req.user.id, kind: kind || 'text', body }).returning('*');
  try { const { emitMessageCreated } = await import('../events.js'); emitMessageCreated(row); } catch {}
  res.status(201).json(row);
});

export default router;

