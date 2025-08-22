import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';

const router = express.Router();

// All routes require authentication
router.use(requireAuth);

// Get all users with enhanced information
router.get('/', async (req, res) => {
  try {
    const { search, role, status } = req.query;
    
    let query = knex('users')
      .leftJoin('user_roles', 'users.id', 'user_roles.user_id')
      .leftJoin('roles', 'user_roles.role_id', 'roles.id')
      .select(
        'users.*',
        'roles.name as role_name',
        'roles.permissions as role_permissions'
      )
      .orderBy('users.name');
    
    if (search) {
      query = query.where(function() {
        this.where('users.name', 'ilike', `%${search}%`)
            .orWhere('users.email', 'ilike', `%${search}%`);
      });
    }
    
    if (role) {
      query = query.where('roles.name', role);
    }
    
    if (status) {
      query = query.where('users.status', status);
    }
    
    const users = await query;
    res.json(users);
  } catch (err) {
    console.error('Get enhanced users error:', err);
    res.status(500).json({ error: 'Failed to fetch users' });
  }
});

// Get user by ID with enhanced information
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const user = await knex('users')
      .leftJoin('user_roles', 'users.id', 'user_roles.user_id')
      .leftJoin('roles', 'user_roles.role_id', 'roles.id')
      .where('users.id', id)
      .select(
        'users.*',
        'roles.name as role_name',
        'roles.permissions as role_permissions'
      )
      .first();
    
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Get user's task statistics
    const taskStats = await knex('tasks')
      .where('assignee_id', id)
      .select(
        knex.raw('COUNT(*) as total_tasks'),
        knex.raw('COUNT(CASE WHEN status = ? THEN 1 END) as completed_tasks', ['completed']),
        knex.raw('COUNT(CASE WHEN status = ? THEN 1 END) as in_progress_tasks', ['in_progress']),
        knex.raw('COUNT(CASE WHEN status = ? THEN 1 END) as pending_tasks', ['pending'])
      )
      .first();
    
    user.task_statistics = taskStats;
    
    res.json(user);
  } catch (err) {
    console.error('Get enhanced user error:', err);
    res.status(500).json({ error: 'Failed to fetch user' });
  }
});

// Update user profile
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { name, email, phone, department, position, status } = req.body;
    const currentUserId = req.user.id;
    
    // Users can only update their own profile unless they're admin
    if (parseInt(id) !== currentUserId && !req.user.isAdmin) {
      return res.status(403).json({ error: 'Not authorized to update this user' });
    }
    
    const updateData = {
      updated_at: new Date()
    };
    
    if (name) updateData.name = name;
    if (email) updateData.email = email;
    if (phone) updateData.phone = phone;
    if (department) updateData.department = department;
    if (position) updateData.position = position;
    
    // Only admins can update status
    if (status && req.user.isAdmin) {
      updateData.status = status;
    }
    
    const [user] = await knex('users')
      .where('id', id)
      .update(updateData)
      .returning('*');
    
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    res.json(user);
  } catch (err) {
    console.error('Update enhanced user error:', err);
    res.status(500).json({ error: 'Failed to update user' });
  }
});

// Get user's activity timeline
router.get('/:id/activity', async (req, res) => {
  try {
    const { id } = req.params;
    const { limit = 50 } = req.query;
    
    // Get recent task activities
    const taskActivities = await knex('task_history')
      .leftJoin('tasks', 'task_history.task_id', 'tasks.id')
      .where('task_history.user_id', id)
      .select(
        'task_history.*',
        'tasks.title as task_title',
        knex.raw("'task' as activity_type")
      )
      .orderBy('task_history.created_at', 'desc')
      .limit(limit);
    
    // Get recent comments
    const commentActivities = await knex('task_comments')
      .leftJoin('tasks', 'task_comments.task_id', 'tasks.id')
      .where('task_comments.user_id', id)
      .select(
        'task_comments.*',
        'tasks.title as task_title',
        knex.raw("'comment' as activity_type")
      )
      .orderBy('task_comments.created_at', 'desc')
      .limit(limit);
    
    // Combine and sort activities
    const allActivities = [...taskActivities, ...commentActivities]
      .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
      .slice(0, limit);
    
    res.json(allActivities);
  } catch (err) {
    console.error('Get user activity error:', err);
    res.status(500).json({ error: 'Failed to fetch user activity' });
  }
});

export default router;
