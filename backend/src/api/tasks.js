import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';
import { requireAnyRole, userHasRole } from '../middleware/rbac.js';

const router = express.Router({ mergeParams: true });
router.use(requireAuth);

router.get('/', async (req, res) => {
  const projectId = Number(req.params.projectId);

  // Check if is_deleted column exists
  const hasIsDeletedColumn = await knex.schema.hasColumn('tasks', 'is_deleted');

  let query = knex('tasks').where({ project_id: projectId });

  // Filter out deleted tasks if column exists
  if (hasIsDeletedColumn) {
    query = query.where(function() {
      this.where('is_deleted', false).orWhereNull('is_deleted');
    });
  }

  const rows = await query.orderBy('id', 'desc');
  res.json(rows);
});

router.post('/', requireAnyRole(['Admin','Project Manager','Team Member']), async (req, res) => {
  try {
    const projectId = Number(req.params.projectId);
    const { title, description, module_id, status_id, priority_id, task_type_id, planned_end_date, start_date, end_date, assigned_to, task_id } = req.body;

    console.log('Creating task with data:', req.body);
    console.log('User:', req.user);

    // Input validation and sanitization
    if (!title || typeof title !== 'string' || title.trim().length === 0) {
      return res.status(400).json({ error: 'Valid title is required' });
    }

    if (title.length > 255) {
      return res.status(400).json({ error: 'Title must be less than 255 characters' });
    }

    if (description && typeof description !== 'string') {
      return res.status(400).json({ error: 'Description must be a string' });
    }

    if (description && description.length > 5000) {
      return res.status(400).json({ error: 'Description must be less than 5000 characters' });
    }

    if (isNaN(projectId) || projectId <= 0) {
      return res.status(400).json({ error: 'Valid project ID is required' });
    }

    // Validate numeric IDs if provided
    const numericFields = { module_id, status_id, priority_id, task_type_id, assigned_to };
    for (const [field, value] of Object.entries(numericFields)) {
      if (value !== undefined && value !== null && (isNaN(Number(value)) || Number(value) <= 0)) {
        return res.status(400).json({ error: `Valid ${field} is required` });
      }
    }

    // Validate dates if provided
    const dateFields = { planned_end_date, start_date, end_date };
    for (const [field, value] of Object.entries(dateFields)) {
      if (value && isNaN(Date.parse(value))) {
        return res.status(400).json({ error: `Valid ${field} is required` });
      }
    }

    // Verify module belongs to the project (if module_id is provided)
    if (module_id) {
      const module = await knex('modules').where({ id: module_id, project_id: projectId }).first();
      if (!module) return res.status(400).json({ error: 'invalid module_id for this project' });
    }

    // Prepare task data
    const taskData = {
      project_id: projectId,
      module_id,
      title,
      description,
      status_id,
      priority_id,
      task_type_id,
      planned_end_date,
      start_date,
      end_date,
      assigned_to,
      task_id,
      created_by: (req.user.id === 'test-user' || req.user.id === 'admin-user' || req.user.id === 0) ? 1 : req.user.id
    };

    // Remove undefined values
    Object.keys(taskData).forEach(key => taskData[key] === undefined && delete taskData[key]);

    const [row] = await knex('tasks').insert(taskData).returning('*');
    console.log('Task created successfully:', row);

    try { const { emitTaskCreated } = await import('../events.js'); emitTaskCreated(row); } catch {}
    res.status(201).json(row);
  } catch (error) {
    console.error('Error creating task:', error);
    res.status(500).json({ error: 'Failed to create task', details: error.message });
  }
});

router.put('/:taskId', requireAnyRole(['Admin','Project Manager','Team Member']), async (req, res) => {
  try {
    const taskId = Number(req.params.taskId);
    console.log('Basic task update:', taskId, 'with data:', req.body);
    console.log('User:', req.user);

    // Remove undefined values
    const updateData = { ...req.body };
    Object.keys(updateData).forEach(key => updateData[key] === undefined && delete updateData[key]);

    // Check if statuses table exists for status_id handling
    const statusesExists = await knex.schema.hasTable('statuses');
    const prioritiesExists = await knex.schema.hasTable('priorities');

    // Handle legacy status field if status_id is provided but statuses table doesn't exist
    if (updateData.status_id && !statusesExists) {
      // Map status_id to legacy status string
      const statusMap = {
        1: 'Open',
        2: 'In Progress',
        3: 'Completed',
        4: 'Cancelled',
        5: 'Hold',
        6: 'Delayed'
      };
      updateData.status = statusMap[updateData.status_id] || 'Open';
      delete updateData.status_id; // Remove status_id if table doesn't exist
      console.log('Mapped status_id to legacy status:', updateData.status);
    }

    // Handle legacy priority field if priority_id is provided but priorities table doesn't exist
    if (updateData.priority_id && !prioritiesExists) {
      // Map priority_id to legacy priority string
      const priorityMap = {
        1: 'High',        // Important & Urgent
        2: 'Medium',      // Important & Not Urgent
        3: 'Low',         // Not Important & Urgent
        4: 'Low'          // Not Important & Not Urgent
      };
      updateData.priority = priorityMap[updateData.priority_id] || 'Medium';
      delete updateData.priority_id; // Remove priority_id if table doesn't exist
      console.log('Mapped priority_id to legacy priority:', updateData.priority);
    }

    const [row] = await knex('tasks').where({ id: taskId }).update(updateData).returning('*');
    console.log('Basic task updated successfully:', row);
    res.json(row);
  } catch (error) {
    console.error('Error updating task:', error);
    res.status(500).json({ error: 'Failed to update task', details: error.message });
  }
});

router.delete('/:taskId', requireAnyRole(['Admin','Project Manager','Team Member']), async (req, res) => {
  try {
    const taskId = Number(req.params.taskId);
    const projectId = Number(req.params.projectId);

    console.log('Soft deleting task:', taskId, 'by user:', req.user);

    // Check if user is a team member of this project
    const isTeamMember = await knex('project_team')
      .where({ project_id: projectId, user_id: req.user.id })
      .first();

    if (!isTeamMember && !await userHasRole(req.user.id, ['Admin', 'Project Manager'])) {
      return res.status(403).json({ error: 'Only team members of this project can delete tasks' });
    }

    // Check if soft delete columns exist, if not add them
    const hasIsDeletedColumn = await knex.schema.hasColumn('tasks', 'is_deleted');
    const hasDeletedAtColumn = await knex.schema.hasColumn('tasks', 'deleted_at');
    const hasDeletedByColumn = await knex.schema.hasColumn('tasks', 'deleted_by');

    if (!hasIsDeletedColumn || !hasDeletedAtColumn || !hasDeletedByColumn) {
      await knex.schema.alterTable('tasks', (table) => {
        if (!hasIsDeletedColumn) {
          table.boolean('is_deleted').defaultTo(false);
        }
        if (!hasDeletedAtColumn) {
          table.timestamp('deleted_at');
        }
        if (!hasDeletedByColumn) {
          table.integer('deleted_by').references('id').inTable('users');
        }
      });
      console.log('Added soft delete columns to tasks table');
    }

    // Soft delete the task
    const [row] = await knex('tasks')
      .where({ id: taskId })
      .update({
        is_deleted: true,
        deleted_at: new Date(),
        deleted_by: req.user.id
      })
      .returning('*');

    if (!row) {
      return res.status(404).json({ error: 'Task not found' });
    }

    console.log('Task soft deleted successfully:', row);
    res.json({ ok: true, message: 'Task deleted successfully' });
  } catch (error) {
    console.error('Error deleting task:', error);
    res.status(500).json({ error: 'Failed to delete task', details: error.message });
  }
});

// Get tasks where user is support team member
router.get('/support/:employeeId', async (req, res) => {
  try {
    const employeeId = req.params.employeeId;
    const userId = req.user.id;

    // Check if user can access other user's support tasks
    if (employeeId !== userId) {
      const hasAccess = await userHasRole(userId, ['Admin', 'Project Manager', 'Team Lead']);
      if (!hasAccess) {
        return res.status(403).json({ error: 'Access denied' });
      }
    }

    // Get tasks where user is in support team
    const supportTasks = await knex('tasks')
      .select(
        'tasks.*',
        'projects.name as project_name',
        'modules.name as module_name',
        'users.email as assigned_to_email'
      )
      .leftJoin('modules', 'tasks.module_id', 'modules.id')
      .leftJoin('projects', 'modules.project_id', 'projects.id')
      .leftJoin('users', 'tasks.assigned_to', 'users.id')
      .whereRaw("JSON_CONTAINS(tasks.support_team, ?)", [`"${employeeId}"`])
      .orWhereExists(function() {
        this.select('*')
          .from('task_support')
          .whereRaw('task_support.task_id = tasks.id')
          .where('task_support.employee_id', employeeId)
          .where('task_support.is_active', true);
      })
      .orderBy('tasks.due_date', 'asc');

    res.json(supportTasks);
  } catch (err) {
    console.error('Error fetching support tasks:', err);
    res.status(500).json({ error: 'Failed to fetch support tasks' });
  }
});

// Add/remove support team members
router.put('/:taskId/support', requireAnyRole(['Admin', 'Project Manager', 'Team Lead']), async (req, res) => {
  try {
    const taskId = parseInt(req.params.taskId);
    const { support_team, action } = req.body; // action: 'add' or 'remove'
    const userId = req.user.id;

    // Verify task exists
    const task = await knex('tasks').where('id', taskId).first();
    if (!task) {
      return res.status(404).json({ error: 'Task not found' });
    }

    if (action === 'add') {
      // Add support team members
      for (const employeeId of support_team) {
        // Check if already exists
        const existing = await knex('task_support')
          .where({ task_id: taskId, employee_id: employeeId })
          .first();

        if (!existing) {
          await knex('task_support').insert({
            task_id: taskId,
            employee_id: employeeId,
            added_by: userId,
            role: 'support'
          });
        } else if (!existing.is_active) {
          // Reactivate if previously removed
          await knex('task_support')
            .where({ task_id: taskId, employee_id: employeeId })
            .update({ is_active: true, added_by: userId });
        }
      }

      // Update JSON column as well for backward compatibility
      const currentSupportTeam = task.support_team ? JSON.parse(task.support_team) : [];
      const updatedSupportTeam = [...new Set([...currentSupportTeam, ...support_team])];

      await knex('tasks')
        .where('id', taskId)
        .update({ support_team: JSON.stringify(updatedSupportTeam) });

      // Log the change
      await knex('task_history').insert({
        task_id: taskId,
        changed_by: userId,
        change_type: 'support_added',
        new_values: JSON.stringify({ support_team: support_team }),
        comment: `Added support team members: ${support_team.join(', ')}`
      });

    } else if (action === 'remove') {
      // Remove support team members
      for (const employeeId of support_team) {
        await knex('task_support')
          .where({ task_id: taskId, employee_id: employeeId })
          .update({ is_active: false });
      }

      // Update JSON column
      const currentSupportTeam = task.support_team ? JSON.parse(task.support_team) : [];
      const updatedSupportTeam = currentSupportTeam.filter(id => !support_team.includes(id));

      await knex('tasks')
        .where('id', taskId)
        .update({ support_team: JSON.stringify(updatedSupportTeam) });

      // Log the change
      await knex('task_history').insert({
        task_id: taskId,
        changed_by: userId,
        change_type: 'support_removed',
        old_values: JSON.stringify({ support_team: support_team }),
        comment: `Removed support team members: ${support_team.join(', ')}`
      });
    }

    res.json({ success: true, message: `Support team ${action}ed successfully` });
  } catch (err) {
    console.error('Error updating support team:', err);
    res.status(500).json({ error: 'Failed to update support team' });
  }
});

// Get overdue tasks
router.get('/overdue', async (req, res) => {
  try {
    const userId = req.user.id;

    // Check if user has admin or manager access
    const hasAccess = await userHasRole(userId, ['Admin', 'Project Manager', 'Team Lead']);

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

// Bulk update delayed tasks
router.put('/update-delayed', requireAnyRole(['Admin', 'Project Manager']), async (req, res) => {
  try {
    const { task_ids, new_status, new_due_date, reason } = req.body;
    const userId = req.user.id;

    if (!task_ids || !Array.isArray(task_ids) || task_ids.length === 0) {
      return res.status(400).json({ error: 'task_ids array is required' });
    }

    const updateData = {};
    if (new_status) updateData.status = new_status;
    if (new_due_date) updateData.due_date = new_due_date;

    // Update tasks
    await knex('tasks')
      .whereIn('id', task_ids)
      .update(updateData);

    // Log the bulk update
    for (const taskId of task_ids) {
      await knex('task_history').insert({
        task_id: taskId,
        changed_by: userId,
        change_type: 'bulk_updated',
        new_values: JSON.stringify(updateData),
        comment: reason || 'Bulk update of delayed tasks'
      });
    }

    res.json({
      success: true,
      message: `Updated ${task_ids.length} tasks successfully`,
      updated_count: task_ids.length
    });
  } catch (err) {
    console.error('Error bulk updating tasks:', err);
    res.status(500).json({ error: 'Failed to bulk update tasks' });
  }
});

// Get task warnings for user
router.get('/warnings/:employeeId', async (req, res) => {
  try {
    const employeeId = req.params.employeeId;
    const userId = req.user.id;

    // Check if user can access other user's warnings
    if (employeeId !== userId) {
      const hasAccess = await userHasRole(userId, ['Admin', 'Project Manager', 'Team Lead']);
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

export default router;

