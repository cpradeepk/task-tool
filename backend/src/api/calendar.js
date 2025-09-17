import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';
import { createEvents } from 'ics';

const router = express.Router();
router.use(requireAuth);

// Get calendar events for a specific date range
router.get('/', async (req, res) => {
  try {
    const userId = req.user.id;
    const { start, end, view = 'month' } = req.query;

    // Default date range if not provided
    const startDate = start ? new Date(start) : new Date();
    const endDate = end ? new Date(end) : new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // 30 days from now

    // Get tasks assigned to user within date range
    let tasksQuery = knex('tasks')
      .select(
        'tasks.id',
        'tasks.title',
        'tasks.description',
        'tasks.status',
        'tasks.priority',
        'tasks.start_date',
        'tasks.planned_end_date',
        'tasks.due_date',
        'tasks.estimated_hours',
        'projects.name as project_name',
        'modules.name as module_name',
        'users.email as assigned_to_email'
      )
      .leftJoin('modules', 'tasks.module_id', 'modules.id')
      .leftJoin('projects', 'modules.project_id', 'projects.id')
      .leftJoin('users', 'tasks.assigned_to', 'users.id')
      .where('tasks.assigned_to', userId)
      .whereNotIn('tasks.status', ['Completed', 'Cancelled']);

    // Filter by date range based on start_date, planned_end_date, or due_date
    tasksQuery = tasksQuery.where(function() {
      this.whereBetween('tasks.start_date', [startDate, endDate])
        .orWhereBetween('tasks.planned_end_date', [startDate, endDate])
        .orWhereBetween('tasks.due_date', [startDate, endDate]);
    });

    const tasks = await tasksQuery.catch(() => []);

    // Transform tasks into calendar events
    const events = tasks.map(task => ({
      id: task.id,
      title: task.title,
      description: task.description || '',
      start: task.start_date || task.due_date,
      end: task.planned_end_date || task.due_date,
      allDay: false,
      status: task.status,
      priority: task.priority,
      project_name: task.project_name,
      module_name: task.module_name,
      estimated_hours: task.estimated_hours,
      type: 'task',
      backgroundColor: getPriorityColor(task.priority),
      borderColor: getStatusColor(task.status),
    })).filter(event => event.start || event.end);

    // Get calendar-specific events (if calendar_events table exists)
    let calendarEvents = [];
    try {
      calendarEvents = await knex('calendar_events')
        .select('*')
        .where('user_id', userId)
        .whereBetween('start_date', [startDate, endDate])
        .catch(() => []);

      calendarEvents = calendarEvents.map(event => ({
        id: `event_${event.id}`,
        title: event.title,
        description: event.description || '',
        start: event.start_date,
        end: event.end_date,
        allDay: event.all_day || false,
        type: 'event',
        backgroundColor: event.color || '#3788d8',
        borderColor: event.color || '#3788d8',
      }));
    } catch (err) {
      // Calendar events table doesn't exist, skip
    }

    // Combine all events
    const allEvents = [...events, ...calendarEvents];

    res.json({
      events: allEvents,
      view,
      start: startDate,
      end: endDate,
      total_events: allEvents.length,
    });
  } catch (err) {
    console.error('Error fetching calendar events:', err);
    res.status(500).json({ error: 'Failed to fetch calendar events' });
  }
});

// Helper functions for colors
function getPriorityColor(priority) {
  switch (priority?.toLowerCase()) {
    case 'high': return '#dc3545';
    case 'medium': return '#fd7e14';
    case 'low': return '#28a745';
    default: return '#6c757d';
  }
}

function getStatusColor(status) {
  switch (status?.toLowerCase()) {
    case 'completed': return '#28a745';
    case 'in progress': return '#007bff';
    case 'delayed': return '#dc3545';
    case 'on hold': return '#ffc107';
    default: return '#6c757d';
  }
}

// Get tasks for a specific date
router.get('/tasks/:date', async (req, res) => {
  try {
    const userId = req.user.id;
    const date = new Date(req.params.date);
    const startOfDay = new Date(date.setHours(0, 0, 0, 0));
    const endOfDay = new Date(date.setHours(23, 59, 59, 999));

    const tasks = await knex('tasks')
      .select(
        'tasks.*',
        'projects.name as project_name',
        'modules.name as module_name'
      )
      .leftJoin('modules', 'tasks.module_id', 'modules.id')
      .leftJoin('projects', 'modules.project_id', 'projects.id')
      .where('tasks.assigned_to', userId)
      .where(function() {
        this.whereBetween('tasks.start_date', [startOfDay, endOfDay])
          .orWhereBetween('tasks.planned_end_date', [startOfDay, endOfDay])
          .orWhereBetween('tasks.due_date', [startOfDay, endOfDay]);
      })
      .orderBy('tasks.start_date', 'asc')
      .catch(() => []);

    res.json({
      date: req.params.date,
      tasks,
      total_tasks: tasks.length,
    });
  } catch (err) {
    console.error('Error fetching tasks for date:', err);
    res.status(500).json({ error: 'Failed to fetch tasks for date' });
  }
});

// Get upcoming deadlines
router.get('/deadlines', async (req, res) => {
  try {
    const userId = req.user.id;
    const { days = 7 } = req.query;
    const today = new Date();
    const futureDate = new Date();
    futureDate.setDate(today.getDate() + parseInt(days));

    const deadlines = await knex('tasks')
      .select(
        'tasks.*',
        'projects.name as project_name',
        'modules.name as module_name'
      )
      .leftJoin('modules', 'tasks.module_id', 'modules.id')
      .leftJoin('projects', 'modules.project_id', 'projects.id')
      .where('tasks.assigned_to', userId)
      .whereNotIn('tasks.status', ['Completed', 'Cancelled'])
      .whereBetween('tasks.due_date', [today, futureDate])
      .orderBy('tasks.due_date', 'asc')
      .catch(() => []);

    res.json({
      deadlines,
      period_days: parseInt(days),
      total_deadlines: deadlines.length,
    });
  } catch (err) {
    console.error('Error fetching deadlines:', err);
    res.status(500).json({ error: 'Failed to fetch deadlines' });
  }
});

// Create a calendar event
router.post('/events', async (req, res) => {
  try {
    const userId = req.user.id;
    const { title, description, start_date, end_date, all_day = false, color = '#3788d8' } = req.body;

    if (!title || !start_date) {
      return res.status(400).json({ error: 'Title and start_date are required' });
    }

    // Try to create calendar event (if table exists)
    try {
      const [eventId] = await knex('calendar_events').insert({
        user_id: userId,
        title,
        description,
        start_date: new Date(start_date),
        end_date: end_date ? new Date(end_date) : new Date(start_date),
        all_day,
        color,
        created_at: new Date(),
        updated_at: new Date(),
      }).returning('id');

      res.status(201).json({
        id: eventId,
        message: 'Calendar event created successfully',
      });
    } catch (err) {
      // Calendar events table doesn't exist, return error
      res.status(501).json({
        error: 'Calendar events feature not implemented',
        message: 'Calendar events table not found in database'
      });
    }
  } catch (err) {
    console.error('Error creating calendar event:', err);
    res.status(500).json({ error: 'Failed to create calendar event' });
  }
});

// Export calendar as ICS
router.get('/user.ics', async (req, res) => {
  try {
    const userId = req.user.id;

    const tasks = await knex('tasks')
      .select('tasks.*')
      .where('tasks.assigned_to', userId)
      .whereNotIn('tasks.status', ['Completed', 'Cancelled'])
      .limit(500)
      .catch(() => []);

    const events = tasks.map(t => ({
      title: t.title,
      start: t.start_date ? [t.start_date.getUTCFullYear(), t.start_date.getUTCMonth()+1, t.start_date.getUTCDate(), 9, 0] : undefined,
      end: t.planned_end_date ? [t.planned_end_date.getUTCFullYear(), t.planned_end_date.getUTCMonth()+1, t.planned_end_date.getUTCDate(), 18, 0] : undefined,
      description: t.description || ''
    })).filter(e => !!e.start && !!e.end);

    const { error, value } = createEvents(events);
    if (error) return res.status(500).send('ICS error');

    res.setHeader('Content-Type', 'text/calendar; charset=utf-8');
    res.setHeader('Content-Disposition', 'attachment; filename=user-tasks.ics');
    res.send(value);
  } catch (err) {
    console.error('Error generating ICS:', err);
    res.status(500).send('Failed to generate calendar file');
  }
});

export default router;

