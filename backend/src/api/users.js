import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { requireAnyRole } from '../middleware/rbac.js';
import { knex } from '../db/index.js';

const router = express.Router();
router.use(requireAuth);

router.get('/', async (req, res) => {
  try {
    const { email } = req.query;
    console.log('Users API called with query:', req.query);

    let q = knex('users').select(
      'id', 'email', 'active', 'name', 'short_name', 'first_name', 'last_name',
      'phone', 'department', 'job_title', 'avatar_url', 'created_at', 'updated_at'
    );

    if (email) {
      q = q.whereILike('email', `%${email}%`);
    }

    // Only return active users
    q = q.where('active', true);

    const rows = await q.limit(50);
    console.log(`Found ${rows.length} users`);

    // Format the response to include display name
    const formattedRows = rows.map(user => ({
      ...user,
      display_name: user.name || `${user.first_name || ''} ${user.last_name || ''}`.trim() || user.email
    }));

    // If no users found, create a test user for development
    if (formattedRows.length === 0 && !email) {
      console.log('No users found, creating test users...');

      // Check if test users already exist
      const existingTestUser = await knex('users').where('email', 'test@swargfood.com').first();

      if (!existingTestUser) {
        // Create test users
        const testUsers = [
          {
            email: 'test@swargfood.com',
            name: 'Test User',
            first_name: 'Test',
            last_name: 'User',
            active: true,
            created_at: new Date(),
            updated_at: new Date()
          },
          {
            email: 'admin@swargfood.com',
            name: 'Admin User',
            first_name: 'Admin',
            last_name: 'User',
            active: true,
            created_at: new Date(),
            updated_at: new Date()
          },
          {
            email: 'developer@swargfood.com',
            name: 'Developer',
            first_name: 'Dev',
            last_name: 'User',
            active: true,
            created_at: new Date(),
            updated_at: new Date()
          }
        ];

        await knex('users').insert(testUsers);
        console.log('Created test users');

        // Return the newly created users
        const newUsers = await knex('users')
          .select('id', 'email', 'active', 'name', 'short_name', 'first_name', 'last_name',
                  'phone', 'department', 'job_title', 'avatar_url', 'created_at', 'updated_at')
          .where('active', true)
          .limit(50);

        const newFormattedRows = newUsers.map(user => ({
          ...user,
          display_name: user.name || `${user.first_name || ''} ${user.last_name || ''}`.trim() || user.email
        }));

        return res.json(newFormattedRows);
      }
    }

    res.json(formattedRows);
  } catch (error) {
    console.error('Error fetching users:', error);
    res.status(500).json({ error: 'Failed to fetch users', details: error.message });
  }
});

export default router;

