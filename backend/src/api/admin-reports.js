import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';

const router = express.Router();

// All admin report routes require authentication and admin access
router.use(requireAuth);

const requireAdmin = async (req, res, next) => {
  try {
    const user = req.user;
    const isAdmin = user.email === process.env.ADMIN_EMAIL || user.isAdmin === true;
    
    if (!isAdmin) {
      return res.status(403).json({ error: 'Admin access required' });
    }
    
    next();
  } catch (err) {
    console.error('Admin check error:', err);
    res.status(500).json({ error: 'Authorization check failed' });
  }
};

router.use(requireAdmin);

// Daily Summary Report
router.get('/daily-summary', async (req, res) => {
  try {
    const { date } = req.query;
    const reportDate = date || new Date().toISOString().substring(0, 10);
    
    console.log('Generating daily summary report for date:', reportDate);
    
    // For now, return mock data since database schema is being fixed
    const mockReport = {
      date: reportDate,
      summary: {
        total_users: 12,
        active_users: 8,
        total_tasks: 45,
        tasks_completed: 12,
        tasks_in_progress: 18,
        tasks_delayed: 3,
        total_hours_logged: 64,
        projects_active: 5,
      },
      user_details: [
        {
          user_id: 1,
          name: 'John Doe (EL-0001)',
          tasks_in_progress: 3,
          tasks_delayed: 0,
          tasks_completed: 2,
          hours_worked: 8,
          tasks_completed_mtd: 15,
          mtd_hours: 120,
        },
        {
          user_id: 2,
          name: 'Jane Smith (EL-0002)',
          tasks_in_progress: 2,
          tasks_delayed: 1,
          tasks_completed: 3,
          hours_worked: 7,
          tasks_completed_mtd: 18,
          mtd_hours: 140,
        },
        {
          user_id: 3,
          name: 'Mike Johnson (EL-0003)',
          tasks_in_progress: 1,
          tasks_delayed: 0,
          tasks_completed: 1,
          hours_worked: 6,
          tasks_completed_mtd: 12,
          mtd_hours: 96,
        },
      ],
      task_details: [
        {
          task_id: 'TSK-001',
          title: 'Complete user authentication module',
          project: 'Task Tool',
          due_date: reportDate,
          priority: 'High',
          status: 'In Progress',
          estimated_hours: 8,
          hours_spent: 6,
          assignee: 'John Doe',
        },
        {
          task_id: 'TSK-002',
          title: 'Database optimization',
          project: 'Backend Development',
          due_date: reportDate,
          priority: 'Medium',
          status: 'Completed',
          estimated_hours: 4,
          hours_spent: 4,
          assignee: 'Jane Smith',
        },
      ],
    };
    
    res.json(mockReport);
  } catch (err) {
    console.error('Error generating daily summary report:', err);
    res.status(500).json({ error: 'Failed to generate daily summary report' });
  }
});

// JSR Planned Tasks Report
router.get('/jsr/planned', async (req, res) => {
  try {
    const { date } = req.query;
    const reportDate = date || new Date().toISOString().substring(0, 10);
    
    const mockPlannedTasks = [
      {
        id: 'JSR-001',
        title: 'Implement calendar task creation',
        project: 'Task Tool',
        assignee: 'john@example.com',
        priority: 'High',
        estimated_hours: 6,
        due_date: reportDate,
        status: 'Open',
        progress: 0,
        dependencies: [],
      },
      {
        id: 'JSR-002',
        title: 'Fix dashboard interactivity',
        project: 'Frontend Development',
        assignee: 'jane@example.com',
        priority: 'Medium',
        estimated_hours: 4,
        due_date: reportDate,
        status: 'In Progress',
        progress: 25,
        dependencies: ['JSR-001'],
      },
    ];
    
    res.json(mockPlannedTasks);
  } catch (err) {
    console.error('Error fetching JSR planned tasks:', err);
    res.status(500).json({ error: 'Failed to fetch JSR planned tasks' });
  }
});

// JSR Completed Tasks Report
router.get('/jsr/completed', async (req, res) => {
  try {
    const { date } = req.query;
    const reportDate = date || new Date().toISOString().substring(0, 10);
    
    const mockCompletedTasks = [
      {
        id: 'JSR-C001',
        title: 'Setup project repository',
        project: 'Task Tool',
        assignee: 'john@example.com',
        priority: 'High',
        estimated_hours: 2,
        actual_hours: 2.5,
        completed_date: reportDate,
        quality_score: 95,
        notes: 'Repository setup with CI/CD pipeline configured',
      },
      {
        id: 'JSR-C002',
        title: 'Database schema design',
        project: 'Backend Development',
        assignee: 'jane@example.com',
        priority: 'Medium',
        estimated_hours: 6,
        actual_hours: 7,
        completed_date: reportDate,
        quality_score: 88,
        notes: 'Schema designed with proper indexing and relationships',
      },
    ];
    
    res.json(mockCompletedTasks);
  } catch (err) {
    console.error('Error fetching JSR completed tasks:', err);
    res.status(500).json({ error: 'Failed to fetch JSR completed tasks' });
  }
});

export default router;
