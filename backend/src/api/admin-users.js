import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { requireAnyRole } from '../middleware/rbac.js';
import { knex } from '../db/index.js';
import { createUserWithPin } from '../services/pin-auth.js';
import bcrypt from 'bcrypt';

const router = express.Router();

// All admin user management routes require admin role
router.use(requireAuth);
router.use(requireAnyRole(['Admin']));

// Get all users
router.get('/', async (req, res) => {
  try {
    const users = await knex('users')
      .select('id', 'email', 'created_at', 'updated_at', 'pin_created_at', 'pin_last_used')
      .orderBy('created_at', 'desc');
    
    res.json(users);
  } catch (err) {
    console.error('Error fetching users:', err);
    res.status(500).json({ error: 'Failed to fetch users' });
  }
});

// Create new user
router.post('/', async (req, res) => {
  try {
    const { email, auth_type, pin } = req.body;
    
    if (!email) {
      return res.status(400).json({ error: 'Email is required' });
    }
    
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return res.status(400).json({ error: 'Invalid email format' });
    }
    
    // Check if user already exists
    const existingUser = await knex('users').where({ email }).first();
    if (existingUser) {
      return res.status(409).json({ error: 'User with this email already exists' });
    }
    
    let user;
    
    if (auth_type === 'pin') {
      if (!pin || !/^\d{4,6}$/.test(pin)) {
        return res.status(400).json({ error: 'PIN must be 4-6 digits' });
      }
      
      // Create user with PIN
      user = await createUserWithPin(email, pin);
    } else if (auth_type === 'oauth') {
      // Create user for OAuth (Google)
      const [newUser] = await knex('users')
        .insert({
          email,
          created_at: new Date(),
          updated_at: new Date()
        })
        .returning('*');
      user = newUser;
    } else {
      return res.status(400).json({ error: 'Invalid authentication type' });
    }
    
    // Remove sensitive data from response
    const { pin_hash, ...safeUser } = user;
    res.status(201).json(safeUser);
    
  } catch (err) {
    console.error('Error creating user:', err);
    res.status(500).json({ error: 'Failed to create user' });
  }
});

// Update user
router.put('/:userId', async (req, res) => {
  try {
    const userId = Number(req.params.userId);
    const { email, new_pin } = req.body;
    
    const updateData = {};
    
    if (email) {
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
        return res.status(400).json({ error: 'Invalid email format' });
      }
      
      // Check if email is already taken by another user
      const existingUser = await knex('users')
        .where({ email })
        .whereNot({ id: userId })
        .first();
        
      if (existingUser) {
        return res.status(409).json({ error: 'Email already taken by another user' });
      }
      
      updateData.email = email;
    }
    
    if (new_pin) {
      if (!/^\d{4,6}$/.test(new_pin)) {
        return res.status(400).json({ error: 'PIN must be 4-6 digits' });
      }
      
      const pinHash = await bcrypt.hash(new_pin, 10);
      updateData.pin_hash = pinHash;
      updateData.pin_created_at = new Date();
      updateData.pin_attempts = 0;
      updateData.pin_locked_until = null;
    }
    
    updateData.updated_at = new Date();
    
    const [user] = await knex('users')
      .where({ id: userId })
      .update(updateData)
      .returning(['id', 'email', 'created_at', 'updated_at', 'pin_created_at', 'pin_last_used']);
    
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    res.json(user);
    
  } catch (err) {
    console.error('Error updating user:', err);
    res.status(500).json({ error: 'Failed to update user' });
  }
});

// Delete user
router.delete('/:userId', async (req, res) => {
  try {
    const userId = Number(req.params.userId);
    
    // Check if user exists
    const user = await knex('users').where({ id: userId }).first();
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Prevent deleting the current admin user
    if (userId === req.user.id) {
      return res.status(400).json({ error: 'Cannot delete your own account' });
    }
    
    // Delete user (cascade will handle related records)
    await knex('users').where({ id: userId }).del();
    
    res.json({ message: 'User deleted successfully' });
    
  } catch (err) {
    console.error('Error deleting user:', err);
    res.status(500).json({ error: 'Failed to delete user' });
  }
});

// Get user roles
router.get('/:userId/roles', async (req, res) => {
  try {
    const userId = Number(req.params.userId);
    
    const roles = await knex('user_roles')
      .join('roles', 'roles.id', 'user_roles.role_id')
      .where('user_roles.user_id', userId)
      .select('roles.id', 'roles.name', 'roles.description');
    
    res.json(roles);
    
  } catch (err) {
    console.error('Error fetching user roles:', err);
    res.status(500).json({ error: 'Failed to fetch user roles' });
  }
});

// Assign role to user
router.post('/:userId/roles', async (req, res) => {
  try {
    const userId = Number(req.params.userId);
    const { role_id } = req.body;
    
    if (!role_id) {
      return res.status(400).json({ error: 'Role ID is required' });
    }
    
    // Check if user exists
    const user = await knex('users').where({ id: userId }).first();
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
      .where({ user_id: userId, role_id })
      .first();
      
    if (existingAssignment) {
      return res.status(409).json({ error: 'User already has this role' });
    }
    
    // Create assignment
    await knex('user_roles').insert({ user_id: userId, role_id });
    
    res.status(201).json({ message: 'Role assigned successfully' });
    
  } catch (err) {
    console.error('Error assigning role:', err);
    res.status(500).json({ error: 'Failed to assign role' });
  }
});

// Remove role from user
router.delete('/:userId/roles/:roleId', async (req, res) => {
  try {
    const userId = Number(req.params.userId);
    const roleId = Number(req.params.roleId);
    
    const deleted = await knex('user_roles')
      .where({ user_id: userId, role_id: roleId })
      .del();
    
    if (deleted === 0) {
      return res.status(404).json({ error: 'Role assignment not found' });
    }
    
    res.json({ message: 'Role removed successfully' });
    
  } catch (err) {
    console.error('Error removing role:', err);
    res.status(500).json({ error: 'Failed to remove role' });
  }
});

// Reset user PIN (admin only)
router.post('/:userId/reset-pin', async (req, res) => {
  try {
    const userId = Number(req.params.userId);
    const { new_pin } = req.body;
    
    if (!new_pin || !/^\d{4,6}$/.test(new_pin)) {
      return res.status(400).json({ error: 'New PIN must be 4-6 digits' });
    }
    
    const pinHash = await bcrypt.hash(new_pin, 10);
    
    const [user] = await knex('users')
      .where({ id: userId })
      .update({
        pin_hash: pinHash,
        pin_created_at: new Date(),
        pin_attempts: 0,
        pin_locked_until: null,
        updated_at: new Date()
      })
      .returning(['id', 'email']);
    
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    res.json({ message: 'PIN reset successfully' });
    
  } catch (err) {
    console.error('Error resetting PIN:', err);
    res.status(500).json({ error: 'Failed to reset PIN' });
  }
});

export default router;
