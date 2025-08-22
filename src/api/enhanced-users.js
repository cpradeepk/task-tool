import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';
import { requireAnyRole, userHasRole } from '../middleware/rbac.js';
import bcrypt from 'bcrypt';

const router = express.Router();
router.use(requireAuth);

// Import users from CSV
router.post('/import', requireAnyRole(['Admin']), async (req, res) => {
  try {
    const { users } = req.body; // Array of user objects
    const userId = req.user.id;
    
    if (!users || !Array.isArray(users) || users.length === 0) {
      return res.status(400).json({ error: 'Users array is required' });
    }
    
    const results = {
      success: [],
      errors: [],
      total: users.length
    };
    
    for (let i = 0; i < users.length; i++) {
      const userData = users[i];
      
      try {
        // Validate required fields
        if (!userData.email) {
          results.errors.push({
            row: i + 1,
            error: 'Email is required',
            data: userData
          });
          continue;
        }
        
        // Check if user already exists
        const existingUser = await knex('users').where('email', userData.email).first();
        if (existingUser) {
          results.errors.push({
            row: i + 1,
            error: 'User with this email already exists',
            data: userData
          });
          continue;
        }
        
        // Hash password if provided, otherwise generate a default one
        const password = userData.password || 'TempPass123!';
        const hashedPassword = await bcrypt.hash(password, 10);
        
        // Create user
        const [newUserId] = await knex('users').insert({
          email: userData.email,
          name: userData.name || userData.email.split('@')[0],
          password: hashedPassword,
          status: userData.status || 'active',
          manager_id: userData.manager_id || null,
          hire_date: userData.hire_date || null,
          employee_photo: userData.employee_photo || null,
          created_at: knex.fn.now(),
          updated_at: knex.fn.now()
        }).returning('id');
        
        // Assign default role if specified
        if (userData.role) {
          const role = await knex('roles').where('name', userData.role).first();
          if (role) {
            await knex('user_roles').insert({
              user_id: newUserId,
              role_id: role.id
            });
          }
        }
        
        results.success.push({
          row: i + 1,
          user_id: newUserId,
          email: userData.email,
          name: userData.name
        });
        
      } catch (error) {
        results.errors.push({
          row: i + 1,
          error: error.message,
          data: userData
        });
      }
    }
    
    res.json(results);
  } catch (err) {
    console.error('Error importing users:', err);
    res.status(500).json({ error: 'Failed to import users' });
  }
});

// Export users to CSV format
router.get('/export', requireAnyRole(['Admin']), async (req, res) => {
  try {
    const { format = 'json' } = req.query;
    
    const users = await knex('users')
      .select(
        'users.id',
        'users.email',
        'users.name',
        'users.status',
        'users.manager_id',
        'users.hire_date',
        'users.warning_count',
        'users.last_warning_date',
        'users.created_at',
        'manager.email as manager_email',
        'manager.name as manager_name'
      )
      .leftJoin('users as manager', 'users.manager_id', 'manager.id')
      .whereNull('users.deleted_at')
      .orderBy('users.created_at', 'desc');
    
    // Get roles for each user
    const userRoles = await knex('user_roles')
      .select('user_roles.user_id', 'roles.name as role_name')
      .join('roles', 'user_roles.role_id', 'roles.id')
      .whereIn('user_roles.user_id', users.map(u => u.id));
    
    const roleMap = userRoles.reduce((acc, ur) => {
      if (!acc[ur.user_id]) acc[ur.user_id] = [];
      acc[ur.user_id].push(ur.role_name);
      return acc;
    }, {});
    
    // Enrich users with roles
    const enrichedUsers = users.map(user => ({
      ...user,
      roles: roleMap[user.id] || [],
      roles_string: (roleMap[user.id] || []).join(', ')
    }));
    
    if (format === 'csv') {
      // Generate CSV
      const csvHeaders = [
        'ID', 'Email', 'Name', 'Status', 'Roles', 'Manager Email', 
        'Hire Date', 'Warning Count', 'Created At'
      ];
      
      const csvRows = enrichedUsers.map(user => [
        user.id,
        user.email,
        user.name || '',
        user.status,
        user.roles_string,
        user.manager_email || '',
        user.hire_date || '',
        user.warning_count || 0,
        user.created_at
      ]);
      
      const csvContent = [csvHeaders, ...csvRows]
        .map(row => row.map(field => `"${field}"`).join(','))
        .join('\n');
      
      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition', 'attachment; filename="users_export.csv"');
      res.send(csvContent);
    } else {
      res.json(enrichedUsers);
    }
  } catch (err) {
    console.error('Error exporting users:', err);
    res.status(500).json({ error: 'Failed to export users' });
  }
});

// Get team members for a manager
router.get('/team/:managerId', async (req, res) => {
  try {
    const managerId = req.params.managerId;
    const userId = req.user.id;
    
    // Check if user can access team data
    if (managerId !== userId) {
      const hasAccess = await userHasRole(userId, ['Admin', 'Manager', 'Team Lead']);
      if (!hasAccess) {
        return res.status(403).json({ error: 'Access denied' });
      }
    }
    
    const teamMembers = await knex('users')
      .select(
        'users.*',
        knex.raw('COUNT(tasks.id) as total_tasks'),
        knex.raw('COUNT(CASE WHEN tasks.status = ? THEN 1 END) as completed_tasks', ['Completed']),
        knex.raw('COUNT(CASE WHEN tasks.due_date < NOW() AND tasks.status != ? THEN 1 END) as overdue_tasks', ['Completed'])
      )
      .leftJoin('tasks', 'users.id', 'tasks.assigned_to')
      .where('users.manager_id', managerId)
      .whereNull('users.deleted_at')
      .groupBy('users.id')
      .orderBy('users.name');
    
    res.json(teamMembers);
  } catch (err) {
    console.error('Error fetching team members:', err);
    res.status(500).json({ error: 'Failed to fetch team members' });
  }
});

// Add warning to user
router.put('/:id/warning', requireAnyRole(['Admin', 'Manager', 'Team Lead']), async (req, res) => {
  try {
    const targetUserId = req.params.id;
    const userId = req.user.id;
    const { warning_type, description } = req.body;
    
    if (!warning_type) {
      return res.status(400).json({ error: 'Warning type is required' });
    }
    
    // Check if target user exists
    const targetUser = await knex('users').where('id', targetUserId).first();
    if (!targetUser) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Add warning record
    await knex('user_warnings').insert({
      employee_id: targetUserId,
      warning_type,
      description,
      issued_by: userId
    });
    
    // Update user warning count
    await knex('users')
      .where('id', targetUserId)
      .increment('warning_count', 1)
      .update({ last_warning_date: knex.fn.now() });
    
    const updatedUser = await knex('users')
      .select('id', 'email', 'name', 'warning_count', 'last_warning_date')
      .where('id', targetUserId)
      .first();
    
    res.json({
      success: true,
      message: 'Warning added successfully',
      user: updatedUser
    });
  } catch (err) {
    console.error('Error adding warning:', err);
    res.status(500).json({ error: 'Failed to add warning' });
  }
});

// Generate employee ID card
router.get('/:id/id-card', async (req, res) => {
  try {
    const targetUserId = req.params.id;
    const userId = req.user.id;
    
    // Check if user can access ID card
    if (targetUserId !== userId) {
      const hasAccess = await userHasRole(userId, ['Admin', 'Manager', 'Team Lead']);
      if (!hasAccess) {
        return res.status(403).json({ error: 'Access denied' });
      }
    }
    
    const user = await knex('users')
      .select(
        'users.*',
        'manager.name as manager_name',
        'manager.email as manager_email'
      )
      .leftJoin('users as manager', 'users.manager_id', 'manager.id')
      .where('users.id', targetUserId)
      .first();
    
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Get user roles
    const userRoles = await knex('user_roles')
      .select('roles.name')
      .join('roles', 'user_roles.role_id', 'roles.id')
      .where('user_roles.user_id', targetUserId);
    
    const idCardData = {
      employee_id: user.id,
      name: user.name || user.email,
      email: user.email,
      roles: userRoles.map(r => r.name),
      hire_date: user.hire_date,
      manager: user.manager_name || user.manager_email,
      photo: user.employee_photo,
      status: user.status,
      generated_at: new Date().toISOString(),
      company: 'Margadarshi', // Replace with your company name
    };
    
    res.json(idCardData);
  } catch (err) {
    console.error('Error generating ID card:', err);
    res.status(500).json({ error: 'Failed to generate ID card' });
  }
});

// Update user photo for ID card
router.put('/:id/photo', async (req, res) => {
  try {
    const targetUserId = req.params.id;
    const userId = req.user.id;
    const { photo } = req.body; // Base64 encoded photo
    
    // Check if user can update photo
    if (targetUserId !== userId) {
      const hasAccess = await userHasRole(userId, ['Admin']);
      if (!hasAccess) {
        return res.status(403).json({ error: 'Access denied' });
      }
    }
    
    if (!photo) {
      return res.status(400).json({ error: 'Photo data is required' });
    }
    
    await knex('users')
      .where('id', targetUserId)
      .update({ 
        employee_photo: photo,
        updated_at: knex.fn.now()
      });
    
    res.json({ success: true, message: 'Photo updated successfully' });
  } catch (err) {
    console.error('Error updating user photo:', err);
    res.status(500).json({ error: 'Failed to update user photo' });
  }
});

// Get user warnings
router.get('/:id/warnings', async (req, res) => {
  try {
    const targetUserId = req.params.id;
    const userId = req.user.id;
    
    // Check if user can access warnings
    if (targetUserId !== userId) {
      const hasAccess = await userHasRole(userId, ['Admin', 'Manager', 'Team Lead']);
      if (!hasAccess) {
        return res.status(403).json({ error: 'Access denied' });
      }
    }
    
    const warnings = await knex('user_warnings')
      .select(
        'user_warnings.*',
        'issuer.name as issued_by_name',
        'issuer.email as issued_by_email',
        'resolver.name as resolved_by_name',
        'resolver.email as resolved_by_email'
      )
      .leftJoin('users as issuer', 'user_warnings.issued_by', 'issuer.id')
      .leftJoin('users as resolver', 'user_warnings.resolved_by', 'resolver.id')
      .where('user_warnings.employee_id', targetUserId)
      .orderBy('user_warnings.issued_at', 'desc');
    
    res.json(warnings);
  } catch (err) {
    console.error('Error fetching user warnings:', err);
    res.status(500).json({ error: 'Failed to fetch user warnings' });
  }
});

// Resolve user warning
router.put('/warnings/:warningId/resolve', requireAnyRole(['Admin', 'Manager', 'Team Lead']), async (req, res) => {
  try {
    const warningId = parseInt(req.params.warningId);
    const userId = req.user.id;
    const { resolution_notes } = req.body;
    
    const warning = await knex('user_warnings').where('id', warningId).first();
    if (!warning) {
      return res.status(404).json({ error: 'Warning not found' });
    }
    
    if (warning.resolved) {
      return res.status(400).json({ error: 'Warning is already resolved' });
    }
    
    await knex('user_warnings')
      .where('id', warningId)
      .update({
        resolved: true,
        resolved_by: userId,
        resolved_at: knex.fn.now(),
        resolution_notes
      });
    
    res.json({ success: true, message: 'Warning resolved successfully' });
  } catch (err) {
    console.error('Error resolving warning:', err);
    res.status(500).json({ error: 'Failed to resolve warning' });
  }
});

// Get user statistics
router.get('/:id/stats', async (req, res) => {
  try {
    const targetUserId = req.params.id;
    const userId = req.user.id;
    
    // Check if user can access stats
    if (targetUserId !== userId) {
      const hasAccess = await userHasRole(userId, ['Admin', 'Manager', 'Team Lead']);
      if (!hasAccess) {
        return res.status(403).json({ error: 'Access denied' });
      }
    }
    
    // Get task statistics
    const [taskStats] = await knex('tasks')
      .select(
        knex.raw('COUNT(*) as total_tasks'),
        knex.raw('COUNT(CASE WHEN status = ? THEN 1 END) as completed_tasks', ['Completed']),
        knex.raw('COUNT(CASE WHEN status = ? THEN 1 END) as in_progress_tasks', ['In Progress']),
        knex.raw('COUNT(CASE WHEN due_date < NOW() AND status != ? THEN 1 END) as overdue_tasks', ['Completed'])
      )
      .where('assigned_to', targetUserId);
    
    // Get leave statistics
    const [leaveStats] = await knex('leaves')
      .select(
        knex.raw('COUNT(*) as total_leaves'),
        knex.raw('COUNT(CASE WHEN status = ? THEN 1 END) as approved_leaves', ['approved']),
        knex.raw('COUNT(CASE WHEN status = ? THEN 1 END) as pending_leaves', ['pending'])
      )
      .where('employee_id', targetUserId)
      .whereRaw('EXTRACT(YEAR FROM start_date) = ?', [new Date().getFullYear()]);
    
    // Get WFH statistics
    const [wfhStats] = await knex('wfh_requests')
      .select(
        knex.raw('COUNT(*) as total_wfh'),
        knex.raw('COUNT(CASE WHEN status = ? THEN 1 END) as approved_wfh', ['approved']),
        knex.raw('COUNT(CASE WHEN status = ? THEN 1 END) as pending_wfh', ['pending'])
      )
      .where('employee_id', targetUserId)
      .whereRaw('EXTRACT(YEAR FROM date) = ?', [new Date().getFullYear()]);
    
    // Get warning count
    const user = await knex('users')
      .select('warning_count', 'last_warning_date')
      .where('id', targetUserId)
      .first();
    
    res.json({
      tasks: {
        total: parseInt(taskStats.total_tasks),
        completed: parseInt(taskStats.completed_tasks),
        in_progress: parseInt(taskStats.in_progress_tasks),
        overdue: parseInt(taskStats.overdue_tasks),
        completion_rate: taskStats.total_tasks > 0 
          ? Math.round((taskStats.completed_tasks / taskStats.total_tasks) * 100)
          : 0
      },
      leaves: {
        total: parseInt(leaveStats.total_leaves),
        approved: parseInt(leaveStats.approved_leaves),
        pending: parseInt(leaveStats.pending_leaves)
      },
      wfh: {
        total: parseInt(wfhStats.total_wfh),
        approved: parseInt(wfhStats.approved_wfh),
        pending: parseInt(wfhStats.pending_wfh)
      },
      warnings: {
        count: user?.warning_count || 0,
        last_warning: user?.last_warning_date
      }
    });
  } catch (err) {
    console.error('Error fetching user statistics:', err);
    res.status(500).json({ error: 'Failed to fetch user statistics' });
  }
});

export default router;
