import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';
import { requireAnyRole } from '../middleware/rbac.js';

const router = express.Router({ mergeParams: true });
router.use(requireAuth);

router.get('/', async (req, res) => {
  const projectId = Number(req.params.projectId);
  const rows = await knex('tasks').where({ project_id: projectId }).orderBy('id', 'desc');
  res.json(rows);
});

router.post('/', requireAnyRole(['Admin','Project Manager','Team Member']), async (req, res) => {
  try {
    const projectId = Number(req.params.projectId);
    const { title, description, module_id, status_id, priority_id, task_type_id, planned_end_date, start_date, end_date, assigned_to, task_id } = req.body;

    console.log('Creating task with data:', req.body);
    console.log('User:', req.user);

    // Enforce hierarchy: Tasks must belong to a module
    if (!title) return res.status(400).json({ error: 'title required' });
    if (!module_id) return res.status(400).json({ error: 'module_id required - tasks must be created within a module' });

    // Verify module belongs to the project
    const module = await knex('modules').where({ id: module_id, project_id: projectId }).first();
    if (!module) return res.status(400).json({ error: 'invalid module_id for this project' });

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
      created_by: req.user.id === 'test-user' ? 1 : req.user.id
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
    console.log('Updating task:', taskId, 'with data:', req.body);
    console.log('User:', req.user);

    // Remove undefined values
    const updateData = { ...req.body };
    Object.keys(updateData).forEach(key => updateData[key] === undefined && delete updateData[key]);

    const [row] = await knex('tasks').where({ id: taskId }).update(updateData).returning('*');
    console.log('Task updated successfully:', row);
    res.json(row);
  } catch (error) {
    console.error('Error updating task:', error);
    res.status(500).json({ error: 'Failed to update task', details: error.message });
  }
});

router.delete('/:taskId', requireAnyRole(['Admin','Project Manager']), async (req, res) => {
  const taskId = Number(req.params.taskId);
  await knex('tasks').where({ id: taskId }).del();
  res.json({ ok: true });
});

export default router;

