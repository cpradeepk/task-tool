import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { requireAnyRole } from '../middleware/rbac.js';
import { knex } from '../db/index.js';

const router = express.Router();
router.use(requireAuth);

router.get('/', async (req, res) => {
  const { email } = req.query;
  let q = knex('users').select(
    'id', 'email', 'active', 'name', 'short_name', 'first_name', 'last_name',
    'phone', 'department', 'job_title', 'avatar_url', 'created_at', 'updated_at'
  );
  if (email) q = q.whereILike('email', `%${email}%`);
  const rows = await q.limit(50);

  // Format the response to include display name
  const formattedRows = rows.map(user => ({
    ...user,
    display_name: user.name || `${user.first_name || ''} ${user.last_name || ''}`.trim() || user.email
  }));

  res.json(formattedRows);
});

export default router;

