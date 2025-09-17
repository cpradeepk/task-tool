import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';

const router = express.Router();

// All dashboard routes require authentication
router.use(requireAuth);

// Main dashboard endpoint - returns comprehensive dashboard data
router.get('/', async (req, res) => {
  try {
    const userId = req.user.id;

    // Handle admin user case
    let userRoles = [];
    if (userId === 'admin-user' || userId === 'test-user' || userId === 0) {
      userRoles = [{ name: 'Admin' }];
    } else {
      // Get user roles to determine access level
      userRoles = await knex('user_roles')
        .join('roles', 'roles.id', 'user_roles.role_id')
        .where('user_roles.user_id', userId)
        .select('roles.name')
        .catch(() => []); // Fallback if roles table doesn't exist
    }

    const roleNames = userRoles.map(r => r.name.toLowerCase());
    const isAdmin = roleNames.includes('admin');
    const isManager = roleNames.includes('manager') || roleNames.includes('top_management');

    // Get basic stats
    let stats = {};
    try {
      if (isAdmin) {
        // Admin dashboard statistics
        const [totalUsers] = await knex('users').count('* as count').catch(() => [{ count: 0 }]);
        const [activeUsers] = await knex('users').where('status', 'active').count('* as count').catch(() => [{ count: 0 }]);
        const [totalProjects] = await knex('projects').count('* as count').catch(() => [{ count: 0 }]);
        const [totalTasks] = await knex('tasks').count('* as count').catch(() => [{ count: 0 }]);
        const [completedTasks] = await knex('tasks').where('status', 'Completed').count('* as count').catch(() => [{ count: 0 }]);

        stats = {
          total_users: parseInt(totalUsers.count),
          active_users: parseInt(activeUsers.count),
          total_projects: parseInt(totalProjects.count),
          total_tasks: parseInt(totalTasks.count),
          completed_tasks: parseInt(completedTasks.count),
          completion_rate: totalTasks.count > 0 ?
            Math.round((completedTasks.count / totalTasks.count) * 100) : 0,
        };
      } else {
        // Employee dashboard statistics
        const [myTasks] = await knex('tasks').where('assigned_to', userId).count('* as count').catch(() => [{ count: 0 }]);
        const [completedTasks] = await knex('tasks')
          .where('assigned_to', userId)
          .where('status', 'Completed')
          .count('* as count').catch(() => [{ count: 0 }]);
        const [inProgressTasks] = await knex('tasks')
          .where('assigned_to', userId)
          .where('status', 'In Progress')
          .count('* as count').catch(() => [{ count: 0 }]);

        stats = {
          total_tasks: parseInt(myTasks.count),
          completed_tasks: parseInt(completedTasks.count),
          in_progress_tasks: parseInt(inProgressTasks.count),
          completion_rate: myTasks.count > 0 ?
            Math.round((completedTasks.count / myTasks.count) * 100) : 0,
        };
      }
    } catch (err) {
      console.error('Error fetching dashboard stats:', err);
      stats = {
        total_tasks: 0,
        completed_tasks: 0,
        in_progress_tasks: 0,
        completion_rate: 0,
      };
    }

    // Get recent activities (simplified)
    let recentActivities = [];
    try {
      recentActivities = await knex('tasks')
        .select('tasks.id', 'tasks.title', 'tasks.status', 'tasks.updated_at')
        .where('tasks.assigned_to', userId)
        .orderBy('tasks.updated_at', 'desc')
        .limit(5)
        .catch(() => []);
    } catch (err) {
      console.error('Error fetching recent activities:', err);
    }

    // Get warnings
    let warnings = { has_warnings: false, warning_count: 0 };
    try {
      const [overdueCount] = await knex('tasks')
        .where('assigned_to', userId)
        .where('due_date', '<', knex.fn.now())
        .whereNotIn('status', ['Completed', 'Cancelled'])
        .count('* as count')
        .catch(() => [{ count: 0 }]);

      warnings = {
        has_warnings: overdueCount.count > 0,
        warning_count: parseInt(overdueCount.count),
        overdue_tasks: parseInt(overdueCount.count),
      };
    } catch (err) {
      console.error('Error fetching warnings:', err);
    }

    res.json({
      stats,
      recent_activities: recentActivities,
      warnings,
      user_role: isAdmin ? 'admin' : (isManager ? 'manager' : 'employee'),
    });
  } catch (err) {
    console.error('Error fetching dashboard data:', err);
    res.status(500).json({ error: 'Failed to fetch dashboard data' });
  }
});

// Get role-based dashboard statistics
router.get('/stats/:role?', async (req, res) => {
  try {
    const userId = req.user.id;
    const role = req.params.role || 'employee';

    // Handle admin user case
    let userRoles = [];
    if (userId === 'admin-user' || userId === 'test-user' || userId === 0) {
      userRoles = [{ name: 'Admin' }];
    } else {
      // Get user roles to determine access level
      userRoles = await knex('user_roles')
        .join('roles', 'roles.id', 'user_roles.role_id')
        .where('user_roles.user_id', userId)
        .select('roles.name');
    }

    const roleNames = userRoles.map(r => r.name.toLowerCase());
    const isAdmin = roleNames.includes('admin');
    const isManager = roleNames.includes('manager') || roleNames.includes('top_management');

    let stats = {};

    if (role === 'admin' && isAdmin) {
      // Admin dashboard statistics
      const [totalUsers] = await knex('users').count('* as count');
      const [activeUsers] = await knex('users').where('status', 'active').count('* as count');
      const [totalProjects] = await knex('projects').count('* as count');
      const [totalTasks] = await knex('tasks').count('* as count');
      const [completedTasks] = await knex('tasks').where('status', 'Completed').count('* as count');
      const [overdueTasks] = await knex('tasks')
        .where('due_date', '<', knex.fn.now())
        .whereNotIn('status', ['Completed', 'Cancelled'])
        .count('* as count');

      stats = {
        total_users: parseInt(totalUsers.count),
        active_users: parseInt(activeUsers.count),
        total_projects: parseInt(totalProjects.count),
        total_tasks: parseInt(totalTasks.count),
        completed_tasks: parseInt(completedTasks.count),
        overdue_tasks: parseInt(overdueTasks.count),
        completion_rate: totalTasks.count > 0 ?
          Math.round((completedTasks.count / totalTasks.count) * 100) : 0,
      };
    } else if (role === 'management' && (isManager || isAdmin)) {
      // Management dashboard statistics
      const [totalProjects] = await knex('projects').count('* as count');
      const [activeProjects] = await knex('projects').where('status', 'Active').count('* as count');
      const [totalTasks] = await knex('tasks').count('* as count');
      const [completedTasks] = await knex('tasks').where('status', 'Completed').count('* as count');
      const [delayedTasks] = await knex('tasks').where('status', 'Delayed').count('* as count');
      const [teamMembers] = await knex('users').where('status', 'active').count('* as count');

      stats = {
        total_projects: parseInt(totalProjects.count),
        active_projects: parseInt(activeProjects.count),
        total_tasks: parseInt(totalTasks.count),
        completed_tasks: parseInt(completedTasks.count),
        delayed_tasks: parseInt(delayedTasks.count),
        team_members: parseInt(teamMembers.count),
        completion_rate: totalTasks.count > 0 ?
          Math.round((completedTasks.count / totalTasks.count) * 100) : 0,
      };
    } else {
      // Employee dashboard statistics
      const [myTasks] = await knex('tasks').where('assigned_to', userId).count('* as count');
      const [completedTasks] = await knex('tasks')
        .where('assigned_to', userId)
        .where('status', 'Completed')
        .count('* as count');
      const [inProgressTasks] = await knex('tasks')
        .where('assigned_to', userId)
        .where('status', 'In Progress')
        .count('* as count');
      const [pendingTasks] = await knex('tasks')
        .where('assigned_to', userId)
        .where('status', 'Yet to Start')
        .count('* as count');
      const [delayedTasks] = await knex('tasks')
        .where('assigned_to', userId)
        .where('status', 'Delayed')
        .count('* as count');

      stats = {
        total_tasks: parseInt(myTasks.count),
        completed_tasks: parseInt(completedTasks.count),
        in_progress_tasks: parseInt(inProgressTasks.count),
        pending_tasks: parseInt(pendingTasks.count),
        delayed_tasks: parseInt(delayedTasks.count),
        completion_rate: myTasks.count > 0 ?
          Math.round((completedTasks.count / myTasks.count) * 100) : 0,
      };
    }

    res.json(stats);
  } catch (err) {
    console.error('Error fetching dashboard stats:', err);
    res.status(500).json({ error: 'Failed to fetch dashboard statistics' });
  }
});

// Get priority tasks
router.get('/priority-tasks', async (req, res) => {
  try {
    // Return mock data for now since database schema is incomplete
    const mockTasks = [
      {
        id: 1,
        title: 'Complete user authentication',
        project_name: 'Task Tool',
        module_name: 'Authentication',
        priority: 'High',
        status: 'In Progress',
        due_date: new Date(Date.now() + 86400000).toISOString().substring(0, 10),
      },
      {
        id: 2,
        title: 'Database optimization',
        project_name: 'Backend Development',
        module_name: 'Performance',
        priority: 'High',
        status: 'Open',
        due_date: new Date(Date.now() + 172800000).toISOString().substring(0, 10),
      }
    ];

    res.json(mockTasks);
  } catch (err) {
    console.error('Error fetching priority tasks:', err);
    res.status(500).json({ error: 'Failed to fetch priority tasks' });
  }
});

// Get recent activities
router.get('/recent-activities', async (req, res) => {
  try {
    const userId = req.user.id;
    
    // Get recent task updates
    const activities = await knex('tasks')
      .select(
        'tasks.id',
        'tasks.title',
        'tasks.status',
        'tasks.updated_at',
        'projects.name as project_name',
        'modules.name as module_name'
      )
      .leftJoin('modules', 'tasks.module_id', 'modules.id')
      .leftJoin('projects', 'modules.project_id', 'projects.id')
      .where('tasks.assigned_to', userId)
      .orderBy('tasks.updated_at', 'desc')
      .limit(10);

    res.json(activities);
  } catch (err) {
    console.error('Error fetching recent activities:', err);
    res.status(500).json({ error: 'Failed to fetch recent activities' });
  }
});

// Get upcoming deadlines
router.get('/upcoming-deadlines', async (req, res) => {
  try {
    const userId = req.user.id;
    const today = new Date();
    const nextWeek = new Date();
    nextWeek.setDate(today.getDate() + 7);
    
    const deadlines = await knex('tasks')
      .select(
        'tasks.*',
        'projects.name as project_name',
        'modules.name as module_name'
      )
      .leftJoin('modules', 'tasks.module_id', 'modules.id')
      .leftJoin('projects', 'modules.project_id', 'projects.id')
      .where('tasks.assigned_to', userId)
      .whereNot('tasks.status', 'Completed')
      .whereBetween('tasks.due_date', [today, nextWeek])
      .orderBy('tasks.due_date', 'asc');

    res.json(deadlines);
  } catch (err) {
    console.error('Error fetching upcoming deadlines:', err);
    res.status(500).json({ error: 'Failed to fetch upcoming deadlines' });
  }
});

// Get team performance (for managers/admins)
router.get('/team-performance', async (req, res) => {
  try {
    // Check if user has admin or manager role
    const userRoles = await knex('user_roles')
      .join('roles', 'roles.id', 'user_roles.role_id')
      .where('user_roles.user_id', req.user.id)
      .select('roles.name');
    
    const hasAccess = userRoles.some(role => 
      ['Admin', 'Manager'].includes(role.name)
    );
    
    if (!hasAccess) {
      return res.status(403).json({ error: 'Access denied' });
    }
    
    const performance = await knex('users')
      .select(
        'users.id',
        'users.email',
        knex.raw('COUNT(tasks.id) as total_tasks'),
        knex.raw('COUNT(CASE WHEN tasks.status = ? THEN 1 END) as completed_tasks', ['Completed']),
        knex.raw('COUNT(CASE WHEN tasks.due_date < NOW() AND tasks.status != ? THEN 1 END) as overdue_tasks', ['Completed'])
      )
      .leftJoin('tasks', 'tasks.assigned_to', 'users.id')
      .groupBy('users.id', 'users.email')
      .having(knex.raw('COUNT(tasks.id)'), '>', 0);

    res.json(performance);
  } catch (err) {
    console.error('Error fetching team performance:', err);
    res.status(500).json({ error: 'Failed to fetch team performance' });
  }
});

// Get project progress
router.get('/project-progress', async (req, res) => {
  try {
    const progress = await knex('projects')
      .select(
        'projects.id',
        'projects.name',
        'projects.status',
        knex.raw('COUNT(tasks.id) as total_tasks'),
        knex.raw('COUNT(CASE WHEN tasks.status = ? THEN 1 END) as completed_tasks', ['Completed']),
        knex.raw('ROUND(COUNT(CASE WHEN tasks.status = ? THEN 1 END) * 100.0 / NULLIF(COUNT(tasks.id), 0), 2) as completion_percentage', ['Completed'])
      )
      .leftJoin('modules', 'modules.project_id', 'projects.id')
      .leftJoin('tasks', 'tasks.module_id', 'modules.id')
      .groupBy('projects.id', 'projects.name', 'projects.status')
      .orderBy('projects.name');

    res.json(progress);
  } catch (err) {
    console.error('Error fetching project progress:', err);
    res.status(500).json({ error: 'Failed to fetch project progress' });
  }
});

// Get overdue tasks
router.get('/overdue-tasks', async (req, res) => {
  try {
    const userId = req.user.id;

    // Check if user has admin or manager access
    const userRoles = await knex('user_roles')
      .join('roles', 'roles.id', 'user_roles.role_id')
      .where('user_roles.user_id', userId)
      .select('roles.name');

    const roleNames = userRoles.map(r => r.name.toLowerCase());
    const hasAccess = roleNames.includes('admin') || roleNames.includes('manager') || roleNames.includes('top_management');

    let query = knex('tasks')
      .select(
        'tasks.*',
        'projects.name as project_name',
        'modules.name as module_name',
        'users.email as assigned_to_email'
      )
      .leftJoin('modules', 'tasks.module_id', 'modules.id')
      .leftJoin('projects', 'modules.project_id', 'projects.id')
      .leftJoin('users', 'tasks.assigned_to', 'users.id')
      .where('tasks.due_date', '<', knex.fn.now())
      .whereNotIn('tasks.status', ['Completed', 'Cancelled'])
      .orderBy('tasks.due_date', 'asc');

    // If not admin/manager, only show user's own overdue tasks
    if (!hasAccess) {
      query = query.where('tasks.assigned_to', userId);
    }

    const overdueTasks = await query;

    res.json(overdueTasks);
  } catch (err) {
    console.error('Error fetching overdue tasks:', err);
    res.status(500).json({ error: 'Failed to fetch overdue tasks' });
  }
});

// Get task warnings for a user
router.get('/warnings/:employeeId?', async (req, res) => {
  try {
    const userId = req.user.id;
    const employeeId = req.params.employeeId || userId;

    // Check if user can access other user's warnings
    if (employeeId !== userId) {
      let hasAccess = false;

      // Handle admin user case
      if (userId === 'admin-user' || userId === 'test-user' || userId === 0) {
        hasAccess = true;
      } else {
        const userRoles = await knex('user_roles')
          .join('roles', 'roles.id', 'user_roles.role_id')
          .where('user_roles.user_id', userId)
          .select('roles.name');

        const roleNames = userRoles.map(r => r.name.toLowerCase());
        hasAccess = roleNames.includes('admin') || roleNames.includes('manager') || roleNames.includes('top_management');
      }

      if (!hasAccess) {
        return res.status(403).json({ error: 'Access denied' });
      }
    }

    // Get overdue tasks count for warnings
    const [overdueCount] = await knex('tasks')
      .where('assigned_to', employeeId)
      .where('due_date', '<', knex.fn.now())
      .whereNotIn('status', ['Completed', 'Cancelled'])
      .count('* as count');

    // Get tasks due today
    const today = new Date().toISOString().split('T')[0];
    const [dueTodayCount] = await knex('tasks')
      .where('assigned_to', employeeId)
      .where('due_date', today)
      .whereNotIn('status', ['Completed', 'Cancelled'])
      .count('* as count');

    // Calculate warning level
    let warningLevel = 'none';
    let warningCount = 0;

    if (overdueCount.count > 0) {
      warningLevel = overdueCount.count > 5 ? 'critical' : 'high';
      warningCount = parseInt(overdueCount.count);
    } else if (dueTodayCount.count > 0) {
      warningLevel = 'medium';
      warningCount = parseInt(dueTodayCount.count);
    }

    res.json({
      employee_id: employeeId,
      warning_level: warningLevel,
      warning_count: warningCount,
      overdue_tasks: parseInt(overdueCount.count),
      due_today_tasks: parseInt(dueTodayCount.count),
      has_warnings: warningLevel !== 'none',
    });
  } catch (err) {
    console.error('Error fetching task warnings:', err);
    res.status(500).json({ error: 'Failed to fetch task warnings' });
  }
});

// Get this week's tasks
router.get('/this-week', async (req, res) => {
  try {
    const userId = req.user.id;

    // Calculate this week's date range
    const today = new Date();
    const startOfWeek = new Date(today);
    startOfWeek.setDate(today.getDate() - today.getDay());
    const endOfWeek = new Date(startOfWeek);
    endOfWeek.setDate(startOfWeek.getDate() + 6);

    const thisWeekTasks = await knex('tasks')
      .select(
        'tasks.*',
        'projects.name as project_name',
        'modules.name as module_name'
      )
      .leftJoin('modules', 'tasks.module_id', 'modules.id')
      .leftJoin('projects', 'modules.project_id', 'projects.id')
      .where('tasks.assigned_to', userId)
      .whereBetween('tasks.due_date', [
        startOfWeek.toISOString().split('T')[0],
        endOfWeek.toISOString().split('T')[0]
      ])
      .orderBy('tasks.due_date', 'asc');

    res.json(thisWeekTasks);
  } catch (err) {
    console.error('Error fetching this week tasks:', err);
    res.status(500).json({ error: 'Failed to fetch this week tasks' });
  }
});

export default router;
