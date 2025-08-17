import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';

const router = express.Router();

// All dashboard routes require authentication
router.use(requireAuth);

// Get dashboard statistics
router.get('/stats', async (req, res) => {
  try {
    const userId = req.user.id;
    
    // Get basic counts
    const [projectCount] = await knex('projects').count('* as count');
    const [taskCount] = await knex('tasks').count('* as count');
    const [userTaskCount] = await knex('tasks').where('assigned_to', userId).count('* as count');
    const [completedTaskCount] = await knex('tasks')
      .where('assigned_to', userId)
      .where('status', 'Completed')
      .count('* as count');

    res.json({
      total_projects: parseInt(projectCount.count),
      total_tasks: parseInt(taskCount.count),
      my_tasks: parseInt(userTaskCount.count),
      completed_tasks: parseInt(completedTaskCount.count),
    });
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

export default router;
