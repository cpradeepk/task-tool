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

    // Get available columns to avoid selecting non-existent columns
    const columns = await knex('users').columnInfo();
    console.log('Available columns in users table:', Object.keys(columns));

    // Build select array with only existing columns
    const selectColumns = ['id', 'email']; // These should always exist

    // Add optional columns if they exist
    const optionalColumns = ['active', 'name', 'short_name', 'first_name', 'last_name',
                            'phone', 'department', 'job_title', 'avatar_url', 'created_at', 'updated_at'];

    optionalColumns.forEach(col => {
      if (columns[col]) {
        selectColumns.push(col);
      }
    });

    console.log('Selecting columns:', selectColumns);

    let q = knex('users').select(selectColumns);

    if (email) {
      q = q.whereILike('email', `%${email}%`);
    }

    // Only return active users if active column exists
    if (columns.active) {
      q = q.where('active', true);
    }

    const rows = await q.limit(50);
    console.log(`Found ${rows.length} users`);

    // Format the response to include display name
    const formattedRows = rows.map(user => ({
      ...user,
      display_name: user.name || `${(user.first_name || '')} ${(user.last_name || '')}`.trim() || user.email
    }));

    // If no users found, create a test user for development
    if (formattedRows.length === 0 && !email) {
      console.log('No users found, creating test users...');

      // Check if test users already exist
      const existingTestUser = await knex('users').where('email', 'test@swargfood.com').first();

      if (!existingTestUser) {
        // Create test users with only columns that exist
        const baseUserData = {
          email: 'test@swargfood.com'
        };

        // Add optional fields if columns exist
        if (columns.name) baseUserData.name = 'Test User';
        if (columns.first_name) baseUserData.first_name = 'Test';
        if (columns.last_name) baseUserData.last_name = 'User';
        if (columns.active) baseUserData.active = true;
        if (columns.created_at) baseUserData.created_at = new Date();
        if (columns.updated_at) baseUserData.updated_at = new Date();

        const testUsers = [
          { ...baseUserData },
          {
            ...baseUserData,
            email: 'admin@swargfood.com',
            ...(columns.name && { name: 'Admin User' }),
            ...(columns.first_name && { first_name: 'Admin' }),
            ...(columns.last_name && { last_name: 'User' })
          },
          {
            ...baseUserData,
            email: 'developer@swargfood.com',
            ...(columns.name && { name: 'Developer' }),
            ...(columns.first_name && { first_name: 'Dev' }),
            ...(columns.last_name && { last_name: 'User' })
          }
        ];

        await knex('users').insert(testUsers);
        console.log('Created test users');

        // Return the newly created users using the same column selection logic
        const newUsers = await knex('users').select(selectColumns).limit(50);

        const newFormattedRows = newUsers.map(user => ({
          ...user,
          display_name: user.name || `${(user.first_name || '')} ${(user.last_name || '')}`.trim() || user.email
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

