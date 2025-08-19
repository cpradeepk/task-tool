import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';

const router = express.Router();
router.use(requireAuth);

router.get('/profile', async (req, res) => {
  try {
    // Get available columns to avoid selecting non-existent columns
    const columns = await knex('users').columnInfo();
    console.log('Available columns in users table for profile:', Object.keys(columns));

    // Build select array with only existing columns
    const selectColumns = ['id', 'email']; // These should always exist

    // Add optional columns if they exist
    const optionalColumns = ['name', 'short_name', 'phone', 'telegram', 'whatsapp',
                            'theme', 'accent_color', 'font', 'avatar_url', 'first_name', 'last_name',
                            'department', 'job_title', 'bio', 'timezone', 'language',
                            'email_notifications', 'push_notifications', 'created_at', 'updated_at'];

    optionalColumns.forEach(col => {
      if (columns[col]) {
        selectColumns.push(col);
      }
    });

    const row = await knex('users')
      .select(selectColumns)
      .where({ id: req.user.id })
      .first();

    res.json(row || {});
  } catch (error) {
    console.error('Error fetching user profile:', error);
    res.status(500).json({ error: 'Failed to fetch profile', details: error.message });
  }
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
    // Also allow updating other user fields
    first_name: req.body.first_name,
    last_name: req.body.last_name,
    department: req.body.department,
    job_title: req.body.job_title,
    bio: req.body.bio,
    timezone: req.body.timezone,
    language: req.body.language,
    email_notifications: req.body.email_notifications,
    push_notifications: req.body.push_notifications,
    updated_at: knex.fn.now()
  };

  // Remove undefined values to avoid overwriting with null
  Object.keys(data).forEach(key => {
    if (data[key] === undefined) {
      delete data[key];
    }
  });

  const [row] = await knex('users')
    .where({ id: req.user.id })
    .update(data)
    .returning('*');

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

