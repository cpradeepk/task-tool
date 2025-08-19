import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';
import { requireAnyRole } from '../middleware/rbac.js';

const router = express.Router();

router.use(requireAuth);

// Get all roles
router.get('/', async (req, res) => {
  try {
    console.log('Fetching all roles');
    
    // Check if roles table exists
    const tableExists = await knex.schema.hasTable('roles');
    if (!tableExists) {
      console.error('Roles table does not exist');
      return res.status(500).json({ error: 'Roles table not found. Please run database migrations.' });
    }
    
    // Get roles with user count
    const roles = await knex('roles')
      .leftJoin('user_roles', 'roles.id', 'user_roles.role_id')
      .select(
        'roles.*',
        knex.raw('COUNT(user_roles.user_id) as user_count')
      )
      .groupBy('roles.id')
      .orderBy('roles.id', 'asc');
    
    // Parse permissions JSON and format response
    const formattedRoles = roles.map(role => ({
      ...role,
      permissions: role.permissions ? JSON.parse(role.permissions) : [],
      userCount: parseInt(role.user_count) || 0,
      isSystem: ['Admin', 'Manager', 'User'].includes(role.name), // Mark default roles as system
    }));
    
    console.log(`Found ${formattedRoles.length} roles`);
    res.json(formattedRoles);
  } catch (err) {
    console.error('Error fetching roles:', err);
    res.status(500).json({ error: 'Failed to fetch roles', details: err.message });
  }
});

// Create new role
router.post('/', requireAnyRole(['Admin']), async (req, res) => {
  try {
    const { name, description, permissions } = req.body;
    
    console.log('Creating role:', { name, description, permissions });
    
    if (!name) {
      return res.status(400).json({ error: 'Role name is required' });
    }
    
    // Check if role name already exists
    const existingRole = await knex('roles').where({ name }).first();
    if (existingRole) {
      return res.status(409).json({ error: 'Role name already exists' });
    }
    
    const [newRole] = await knex('roles')
      .insert({
        name: name.trim(),
        description: description?.trim() || '',
        permissions: JSON.stringify(permissions || []),
      })
      .returning('*');
    
    const formattedRole = {
      ...newRole,
      permissions: newRole.permissions ? JSON.parse(newRole.permissions) : [],
      userCount: 0,
      isSystem: false,
    };
    
    console.log('Role created successfully:', formattedRole);
    res.status(201).json(formattedRole);
  } catch (err) {
    console.error('Error creating role:', err);
    res.status(500).json({ error: 'Failed to create role', details: err.message });
  }
});

// Update role
router.put('/:roleId', requireAnyRole(['Admin']), async (req, res) => {
  try {
    const roleId = Number(req.params.roleId);
    const { name, description, permissions } = req.body;
    
    console.log('Updating role:', roleId, { name, description, permissions });
    
    if (!name) {
      return res.status(400).json({ error: 'Role name is required' });
    }
    
    // Check if role exists
    const existingRole = await knex('roles').where({ id: roleId }).first();
    if (!existingRole) {
      return res.status(404).json({ error: 'Role not found' });
    }
    
    // Check if new name conflicts with another role
    const nameConflict = await knex('roles')
      .where({ name })
      .whereNot({ id: roleId })
      .first();
    if (nameConflict) {
      return res.status(409).json({ error: 'Role name already exists' });
    }
    
    const [updatedRole] = await knex('roles')
      .where({ id: roleId })
      .update({
        name: name.trim(),
        description: description?.trim() || '',
        permissions: JSON.stringify(permissions || []),
        updated_at: new Date(),
      })
      .returning('*');
    
    const formattedRole = {
      ...updatedRole,
      permissions: updatedRole.permissions ? JSON.parse(updatedRole.permissions) : [],
      userCount: 0, // Will be calculated if needed
      isSystem: ['Admin', 'Manager', 'User'].includes(updatedRole.name),
    };
    
    console.log('Role updated successfully:', formattedRole);
    res.json(formattedRole);
  } catch (err) {
    console.error('Error updating role:', err);
    res.status(500).json({ error: 'Failed to update role', details: err.message });
  }
});

// Delete role
router.delete('/:roleId', requireAnyRole(['Admin']), async (req, res) => {
  try {
    const roleId = Number(req.params.roleId);
    
    console.log('Deleting role:', roleId);
    
    // Check if role exists
    const existingRole = await knex('roles').where({ id: roleId }).first();
    if (!existingRole) {
      return res.status(404).json({ error: 'Role not found' });
    }
    
    // Prevent deletion of system roles
    if (['Admin', 'Manager', 'User'].includes(existingRole.name)) {
      return res.status(400).json({ error: 'Cannot delete system roles' });
    }
    
    // Check if role is assigned to any users
    const assignedUsers = await knex('user_roles').where({ role_id: roleId }).count('* as count').first();
    if (parseInt(assignedUsers.count) > 0) {
      return res.status(400).json({ error: 'Cannot delete role that is assigned to users' });
    }
    
    await knex('roles').where({ id: roleId }).del();
    
    console.log('Role deleted successfully');
    res.json({ message: 'Role deleted successfully' });
  } catch (err) {
    console.error('Error deleting role:', err);
    res.status(500).json({ error: 'Failed to delete role', details: err.message });
  }
});

export default router;
