import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';

const router = express.Router();

// All routes require authentication
router.use(requireAuth);

// Get all task templates
router.get('/', async (req, res) => {
  try {
    const templates = await knex('task_templates')
      .orderBy('name')
      .select('*');
    
    res.json(templates);
  } catch (err) {
    console.error('Get task templates error:', err);
    res.status(500).json({ error: 'Failed to fetch task templates' });
  }
});

// Get task template by ID
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const template = await knex('task_templates')
      .where('id', id)
      .first();
    
    if (!template) {
      return res.status(404).json({ error: 'Task template not found' });
    }
    
    res.json(template);
  } catch (err) {
    console.error('Get task template error:', err);
    res.status(500).json({ error: 'Failed to fetch task template' });
  }
});

// Create task template
router.post('/', async (req, res) => {
  try {
    const { name, description, default_assignee, estimated_hours, tags } = req.body;
    const userId = req.user.id;
    
    if (!name) {
      return res.status(400).json({ error: 'Template name is required' });
    }
    
    const [template] = await knex('task_templates')
      .insert({
        name,
        description,
        default_assignee,
        estimated_hours,
        tags: JSON.stringify(tags || []),
        created_by: userId,
        created_at: new Date()
      })
      .returning('*');
    
    res.status(201).json(template);
  } catch (err) {
    console.error('Create task template error:', err);
    res.status(500).json({ error: 'Failed to create task template' });
  }
});

// Update task template
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { name, description, default_assignee, estimated_hours, tags } = req.body;
    
    const [template] = await knex('task_templates')
      .where('id', id)
      .update({
        name,
        description,
        default_assignee,
        estimated_hours,
        tags: JSON.stringify(tags || []),
        updated_at: new Date()
      })
      .returning('*');
    
    if (!template) {
      return res.status(404).json({ error: 'Task template not found' });
    }
    
    res.json(template);
  } catch (err) {
    console.error('Update task template error:', err);
    res.status(500).json({ error: 'Failed to update task template' });
  }
});

// Delete task template
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const deleted = await knex('task_templates')
      .where('id', id)
      .del();
    
    if (!deleted) {
      return res.status(404).json({ error: 'Task template not found' });
    }
    
    res.json({ message: 'Task template deleted successfully' });
  } catch (err) {
    console.error('Delete task template error:', err);
    res.status(500).json({ error: 'Failed to delete task template' });
  }
});

export default router;
