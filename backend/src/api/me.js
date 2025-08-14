import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';

const router = express.Router();
router.use(requireAuth);

router.get('/profile', async (req, res) => {
  const row = await knex('user_profiles').where({ user_id: req.user.id }).first();
  res.json(row || {});
});

router.put('/profile', async (req, res) => {
  const data = {
    name: req.body.name,
    short_name: req.body.short_name,
    phone: req.body.phone,
    telegram: req.body.telegram,
    whatsapp: req.body.whatsapp,
    theme: req.body.theme,
    accent_color: req.body.accent_color,
    font: req.body.font,
    avatar_url: req.body.avatar_url,
  };
  const exists = await knex('user_profiles').where({ user_id: req.user.id }).first();
  let row;
  if (exists) {
    [row] = await knex('user_profiles').where({ user_id: req.user.id }).update(data).returning('*');
  } else {
    [row] = await knex('user_profiles').insert({ user_id: req.user.id, ...data }).returning('*');
  }
  res.json(row);
});

router.get('/roles', async (req, res) => {
  const rows = await knex('user_roles')
    .join('roles','user_roles.role_id','roles.id')
    .where('user_roles.user_id', req.user.id)
    .select('roles.name');
  res.json(rows.map(r=>r.name));
});

export default router;

