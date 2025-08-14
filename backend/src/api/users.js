import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { requireAnyRole } from '../middleware/rbac.js';
import { knex } from '../db/index.js';

const router = express.Router();
router.use(requireAuth);

router.get('/', requireAnyRole(['Admin','Project Manager']), async (req, res) => {
  const { email } = req.query;
  let q = knex('users').select('id','email','active');
  if (email) q = q.whereILike('email', `%${email}%`);
  const rows = await q.limit(50);
  res.json(rows);
});

export default router;

