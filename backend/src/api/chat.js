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
  const rows = await knex('messages')
    .leftJoin('users','users.id','messages.user_id')
    .where({ thread_id: threadId })
    .orderBy('messages.id', 'asc')
    .select('messages.*','users.email');
  res.json(rows);
});

router.post('/threads/:id/messages', async (req, res) => {
  const threadId = Number(req.params.id);
  const { kind, body } = req.body;
  const [row] = await knex('messages').insert({ thread_id: threadId, user_id: req.user.id, kind: kind || 'text', body }).returning('*');
  try { const { emitMessageCreated } = await import('../events.js'); emitMessageCreated(row); } catch {}

  // Mention notifications: naive parsing for @email
  const mentionMatches = (body || '').toString().match(/@[^\s@]+@[^\s@]+\.[^\s@]+/g) || [];
  if (mentionMatches.length) {
    const emails = mentionMatches.map(s => s.slice(1));
    const users = await knex('users').whereIn('email', emails).select('email');
    const { emailQueue } = await import('../queue/index.js');
    for (const u of users) {
      await emailQueue.add('send', {
        to: u.email,
        subject: 'You were mentioned in Task Tool',
        html: `<p>${req.user.email} mentioned you: ${body}</p>`
      }, { removeOnComplete: true });
    }
  }

  res.status(201).json(row);
});

export default router;

