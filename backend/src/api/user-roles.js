import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';
import { requireAnyRole } from '../middleware/rbac.js';

const router = express.Router();

router.use(requireAuth);

// Get all user role assignments
router.get('/', requireAnyRole(['Admin']), async (req, res) => {
  try {
    console.log('Fetching all user role assignments');
    
    // Check if required tables exist
    const userRolesExists = await knex.schema.hasTable('user_roles');
    const usersExists = await knex.schema.hasTable('users');
    const rolesExists = await knex.schema.hasTable('roles');
    
    if (!userRolesExists || !usersExists || !rolesExists) {
      console.error('Required tables do not exist');
      return res.status(500).json({ error: 'Required tables not found. Please run database migrations.' });
    }
    
    // Get user role assignments with user and role details
    const userRoles = await knex('user_roles')
      .join('users', 'user_roles.user_id', 'users.id')
      .join('roles', 'user_roles.role_id', 'roles.id')
      .select(
        'user_roles.*',
        'users.email as user_email',
        'users.name as user_name',
        'roles.name as role_name',
        'roles.description as role_description'
      )
      .orderBy('user_roles.assigned_at', 'desc');
    
    console.log(`Found ${userRoles.length} user role assignments`);
    res.json(userRoles);
  } catch (err) {
    console.error('Error fetching user role assignments:', err);
    res.status(500).json({ error: 'Failed to fetch user role assignments', details: err.message });
  }
});

// Assign role to user
router.post('/', requireAnyRole(['Admin']), async (req, res) => {
  try {
    const { user_id, role_id } = req.body;
    
    console.log('Assigning role to user:', { user_id, role_id });
    
    if (!user_id || !role_id) {
      return res.status(400).json({ error: 'User ID and Role ID are required' });
    }
    
    // Check if user exists
    const user = await knex('users').where({ id: user_id }).first();
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Check if role exists
    const role = await knex('roles').where({ id: role_id }).first();
    if (!role) {
      return res.status(404).json({ error: 'Role not found' });
    }
    
    // Check if assignment already exists
    const existingAssignment = await knex('user_roles')
      .where({ user_id, role_id })
      .first();
    if (existingAssignment) {
      return res.status(409).json({ error: 'User already has this role' });
    }

    // Get table columns to ensure compatibility
    const columns = await knex('user_roles').columnInfo();
    console.log('Available columns in user_roles table:', Object.keys(columns));

    const assignmentData = {
      user_id,
      role_id,
    };

    // Add optional columns if they exist
    if (columns.assigned_at) assignmentData.assigned_at = new Date();
    if (columns.created_at) assignmentData.created_at = new Date();

    console.log('Inserting user role assignment:', assignmentData);

    const [newAssignment] = await knex('user_roles')
      .insert(assignmentData)
      .returning('*');
    
    // Get the full assignment details for response
    const fullAssignment = await knex('user_roles')
      .join('users', 'user_roles.user_id', 'users.id')
      .join('roles', 'user_roles.role_id', 'roles.id')
      .select(
        'user_roles.*',
        'users.email as user_email',
        'users.name as user_name',
        'roles.name as role_name',
        'roles.description as role_description'
      )
      .where('user_roles.id', newAssignment.id)
      .first();
    
    console.log('Role assigned successfully:', fullAssignment);
    res.status(201).json(fullAssignment);
  } catch (err) {
    console.error('Error assigning role to user:', err);
    res.status(500).json({ error: 'Failed to assign role to user', details: err.message });
  }
});

// Remove role from user
router.delete('/:userId/:roleId', requireAnyRole(['Admin']), async (req, res) => {
  try {
    const userId = Number(req.params.userId);
    const roleId = Number(req.params.roleId);
    
    console.log('Removing role from user:', { userId, roleId });
    
    // Check if assignment exists
    const existingAssignment = await knex('user_roles')
      .where({ user_id: userId, role_id: roleId })
      .first();
    if (!existingAssignment) {
      return res.status(404).json({ error: 'Role assignment not found' });
    }
    
    // Prevent removing Admin role from the last admin user
    const role = await knex('roles').where({ id: roleId }).first();
    if (role && role.name === 'Admin') {
      const adminCount = await knex('user_roles')
        .join('roles', 'user_roles.role_id', 'roles.id')
        .where('roles.name', 'Admin')
        .count('* as count')
        .first();
      
      if (parseInt(adminCount.count) <= 1) {
        return res.status(400).json({ error: 'Cannot remove the last admin user' });
      }
    }
    
    await knex('user_roles')
      .where({ user_id: userId, role_id: roleId })
      .del();
    
    console.log('Role removed from user successfully');
    res.json({ message: 'Role removed from user successfully' });
  } catch (err) {
    console.error('Error removing role from user:', err);
    res.status(500).json({ error: 'Failed to remove role from user', details: err.message });
  }
});

// Get roles for a specific user
router.get('/user/:userId', async (req, res) => {
  try {
    const userId = Number(req.params.userId);
    
    console.log('Fetching roles for user:', userId);
    
    // Check if user exists
    const user = await knex('users').where({ id: userId }).first();
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const userRoles = await knex('user_roles')
      .join('roles', 'user_roles.role_id', 'roles.id')
      .select(
        'roles.*',
        'user_roles.assigned_at'
      )
      .where('user_roles.user_id', userId)
      .orderBy('user_roles.assigned_at', 'desc');
    
    // Parse permissions JSON
    const formattedRoles = userRoles.map(role => ({
      ...role,
      permissions: role.permissions ? JSON.parse(role.permissions) : [],
    }));
    
    console.log(`Found ${formattedRoles.length} roles for user ${userId}`);
    res.json(formattedRoles);
  } catch (err) {
    console.error('Error fetching user roles:', err);
    res.status(500).json({ error: 'Failed to fetch user roles', details: err.message });
  }
});

export default router;
