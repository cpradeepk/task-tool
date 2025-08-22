import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';
import { requireAnyRole, userHasRole } from '../middleware/rbac.js';

const router = express.Router();
router.use(requireAuth);

// Get all task templates
router.get('/', async (req, res) => {
  try {
    const userId = req.user.id;
    const { category, search } = req.query;
    
    let query = knex('task_templates')
      .select(
        'task_templates.*',
        'users.email as created_by_email',
        'users.name as created_by_name'
      )
      .leftJoin('users', 'task_templates.created_by', 'users.id')
      .whereNull('task_templates.deleted_at')
      .where(function() {
        // Show public templates or user's own templates
        this.where('task_templates.is_public', true)
            .orWhere('task_templates.created_by', userId);
      });
    
    if (category) {
      query = query.where('task_templates.category', category);
    }
    
    if (search) {
      query = query.where(function() {
        this.where('task_templates.name', 'ilike', `%${search}%`)
            .orWhere('task_templates.description', 'ilike', `%${search}%`);
      });
    }
    
    const templates = await query.orderBy('task_templates.created_at', 'desc');
    
    res.json(templates);
  } catch (err) {
    console.error('Error fetching task templates:', err);
    res.status(500).json({ error: 'Failed to fetch task templates' });
  }
});

// Get template categories
router.get('/categories', async (req, res) => {
  try {
    const userId = req.user.id;
    
    const categories = await knex('task_templates')
      .distinct('category')
      .whereNotNull('category')
      .whereNull('deleted_at')
      .where(function() {
        this.where('is_public', true)
            .orWhere('created_by', userId);
      })
      .orderBy('category');
    
    res.json(categories.map(c => c.category));
  } catch (err) {
    console.error('Error fetching template categories:', err);
    res.status(500).json({ error: 'Failed to fetch template categories' });
  }
});

// Get specific task template
router.get('/:id', async (req, res) => {
  try {
    const templateId = parseInt(req.params.id);
    const userId = req.user.id;
    
    const template = await knex('task_templates')
      .select(
        'task_templates.*',
        'users.email as created_by_email',
        'users.name as created_by_name'
      )
      .leftJoin('users', 'task_templates.created_by', 'users.id')
      .where('task_templates.id', templateId)
      .whereNull('task_templates.deleted_at')
      .where(function() {
        // Show public templates or user's own templates
        this.where('task_templates.is_public', true)
            .orWhere('task_templates.created_by', userId);
      })
      .first();
    
    if (!template) {
      return res.status(404).json({ error: 'Template not found' });
    }
    
    res.json(template);
  } catch (err) {
    console.error('Error fetching task template:', err);
    res.status(500).json({ error: 'Failed to fetch task template' });
  }
});

// Create task template
router.post('/', requireAnyRole(['Admin', 'Project Manager', 'Team Lead']), async (req, res) => {
  try {
    const userId = req.user.id;
    const { name, description, template_data, category, is_public } = req.body;
    
    if (!name || !template_data) {
      return res.status(400).json({ error: 'Name and template_data are required' });
    }
    
    // Only admins can create public templates
    const canCreatePublic = await userHasRole(userId, ['Admin']);
    const templateIsPublic = is_public && canCreatePublic;
    
    const [templateId] = await knex('task_templates').insert({
      name,
      description,
      template_data: JSON.stringify(template_data),
      category,
      created_by: userId,
      is_public: templateIsPublic
    }).returning('id');
    
    const newTemplate = await knex('task_templates')
      .select(
        'task_templates.*',
        'users.email as created_by_email',
        'users.name as created_by_name'
      )
      .leftJoin('users', 'task_templates.created_by', 'users.id')
      .where('task_templates.id', templateId)
      .first();
    
    res.status(201).json(newTemplate);
  } catch (err) {
    console.error('Error creating task template:', err);
    res.status(500).json({ error: 'Failed to create task template' });
  }
});

// Update task template
router.put('/:id', async (req, res) => {
  try {
    const templateId = parseInt(req.params.id);
    const userId = req.user.id;
    const { name, description, template_data, category, is_public } = req.body;
    
    // Check if template exists and user has permission
    const template = await knex('task_templates')
      .where('id', templateId)
      .whereNull('deleted_at')
      .first();
    
    if (!template) {
      return res.status(404).json({ error: 'Template not found' });
    }
    
    // Check permissions
    const canEdit = template.created_by === userId || 
                   await userHasRole(userId, ['Admin']);
    
    if (!canEdit) {
      return res.status(403).json({ error: 'Access denied' });
    }
    
    // Only admins can make templates public
    const canMakePublic = await userHasRole(userId, ['Admin']);
    const updateData = {
      name: name || template.name,
      description: description !== undefined ? description : template.description,
      template_data: template_data ? JSON.stringify(template_data) : template.template_data,
      category: category !== undefined ? category : template.category,
      updated_at: knex.fn.now()
    };
    
    if (is_public !== undefined && canMakePublic) {
      updateData.is_public = is_public;
    }
    
    await knex('task_templates')
      .where('id', templateId)
      .update(updateData);
    
    const updatedTemplate = await knex('task_templates')
      .select(
        'task_templates.*',
        'users.email as created_by_email',
        'users.name as created_by_name'
      )
      .leftJoin('users', 'task_templates.created_by', 'users.id')
      .where('task_templates.id', templateId)
      .first();
    
    res.json(updatedTemplate);
  } catch (err) {
    console.error('Error updating task template:', err);
    res.status(500).json({ error: 'Failed to update task template' });
  }
});

// Delete task template (soft delete)
router.delete('/:id', async (req, res) => {
  try {
    const templateId = parseInt(req.params.id);
    const userId = req.user.id;
    
    // Check if template exists and user has permission
    const template = await knex('task_templates')
      .where('id', templateId)
      .whereNull('deleted_at')
      .first();
    
    if (!template) {
      return res.status(404).json({ error: 'Template not found' });
    }
    
    // Check permissions
    const canDelete = template.created_by === userId || 
                     await userHasRole(userId, ['Admin']);
    
    if (!canDelete) {
      return res.status(403).json({ error: 'Access denied' });
    }
    
    await knex('task_templates')
      .where('id', templateId)
      .update({ deleted_at: knex.fn.now() });
    
    res.json({ success: true, message: 'Template deleted successfully' });
  } catch (err) {
    console.error('Error deleting task template:', err);
    res.status(500).json({ error: 'Failed to delete task template' });
  }
});

// Create task from template
router.post('/:id/create-task', requireAnyRole(['Admin', 'Project Manager', 'Team Member']), async (req, res) => {
  try {
    const templateId = parseInt(req.params.id);
    const userId = req.user.id;
    const { project_id, module_id, customizations } = req.body;
    
    if (!project_id) {
      return res.status(400).json({ error: 'project_id is required' });
    }
    
    // Get template
    const template = await knex('task_templates')
      .where('id', templateId)
      .whereNull('deleted_at')
      .where(function() {
        this.where('is_public', true)
            .orWhere('created_by', userId);
      })
      .first();
    
    if (!template) {
      return res.status(404).json({ error: 'Template not found' });
    }
    
    // Parse template data
    const templateData = JSON.parse(template.template_data);
    
    // Apply customizations
    const taskData = {
      ...templateData,
      ...customizations,
      project_id,
      module_id,
      created_by: userId,
      assigned_to: customizations?.assigned_to || userId
    };
    
    // Generate formatted task ID
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const day = String(now.getDate()).padStart(2, '0');
    
    // Get next task number for today
    const todayPrefix = `JSR-${year}${month}${day}`;
    const lastTask = await knex('tasks')
      .where('task_id_formatted', 'like', `${todayPrefix}%`)
      .orderBy('task_id_formatted', 'desc')
      .first();
    
    let nextNumber = 1;
    if (lastTask) {
      const lastNumber = parseInt(lastTask.task_id_formatted.split('-')[2]);
      nextNumber = lastNumber + 1;
    }
    
    const formattedId = `${todayPrefix}-${String(nextNumber).padStart(3, '0')}`;
    taskData.task_id_formatted = formattedId;
    
    // Create task
    const [taskId] = await knex('tasks').insert(taskData).returning('id');
    
    // Log task creation
    await knex('task_history').insert({
      task_id: taskId,
      changed_by: userId,
      change_type: 'created',
      comment: `Task created from template: ${template.name}`
    });
    
    const newTask = await knex('tasks')
      .select(
        'tasks.*',
        'projects.name as project_name',
        'modules.name as module_name'
      )
      .leftJoin('modules', 'tasks.module_id', 'modules.id')
      .leftJoin('projects', 'modules.project_id', 'projects.id')
      .where('tasks.id', taskId)
      .first();
    
    res.status(201).json(newTask);
  } catch (err) {
    console.error('Error creating task from template:', err);
    res.status(500).json({ error: 'Failed to create task from template' });
  }
});

export default router;
