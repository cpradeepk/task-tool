import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';
import { requireAnyRole } from '../middleware/rbac.js';
import { softDelete, getQueryWithSoftDelete, ensureSoftDeleteColumns } from '../utils/softDelete.js';

const router = express.Router({ mergeParams: true });
router.use(requireAuth);

router.get('/', async (req, res) => {
  try {
    const projectId = Number(req.params.projectId);

    console.log('Fetching modules for project:', projectId);

    // Check if modules table exists
    const tableExists = await knex.schema.hasTable('modules');
    if (!tableExists) {
      console.error('Modules table does not exist');
      return res.status(500).json({ error: 'Modules table not found. Please run database migrations.' });
    }

    // Ensure soft delete columns exist
    await ensureSoftDeleteColumns('modules');

    const rows = await getQueryWithSoftDelete('modules')
      .where({ project_id: projectId })
      .orderBy('id', 'desc');

    console.log(`Found ${rows.length} modules for project ${projectId}`);
    res.json(rows);
  } catch (err) {
    console.error('Error fetching modules:', err);
    res.status(500).json({ error: 'Failed to fetch modules', details: err.message });
  }
});

router.post('/', requireAnyRole(['Admin','Project Manager']), async (req, res) => {
  try {
    const projectId = Number(req.params.projectId);
    const { name } = req.body;

    console.log('Creating module for project:', projectId, 'with name:', name);

    if (!name) return res.status(400).json({ error: 'name required' });

    // Check if modules table exists
    const tableExists = await knex.schema.hasTable('modules');
    if (!tableExists) {
      console.error('Modules table does not exist');
      return res.status(500).json({ error: 'Modules table not found. Please run database migrations.' });
    }

    // Get table columns to ensure compatibility
    const columns = await knex('modules').columnInfo();
    console.log('Available columns in modules table:', Object.keys(columns));

    const moduleData = {
      project_id: projectId,
      name: name.trim(),
    };

    // Ensure soft delete columns exist
    await ensureSoftDeleteColumns('modules');

    // Add optional columns if they exist
    if (columns.description) moduleData.description = req.body.description?.trim() || '';
    if (columns.order_index) moduleData.order_index = req.body.order_index || 0;
    if (columns.created_at) moduleData.created_at = new Date();
    if (columns.updated_at) moduleData.updated_at = new Date();
    if (columns.created_by) moduleData.created_by = req.user.id;

    console.log('Inserting module data:', moduleData);

    const [row] = await knex('modules').insert(moduleData).returning('*');

    console.log('Module created successfully:', row);
    res.status(201).json(row);
  } catch (err) {
    console.error('Error creating module:', err);
    res.status(500).json({ error: 'Failed to create module', details: err.message });
  }
});

router.put('/:moduleId', requireAnyRole(['Admin','Project Manager']), async (req, res) => {
  try {
    const moduleId = Number(req.params.moduleId);
    const { name, description } = req.body;

    if (!name) {
      return res.status(400).json({ error: 'Module name is required' });
    }

    // Get table columns to ensure compatibility
    const columns = await knex('modules').columnInfo();
    console.log('Available columns in modules table:', Object.keys(columns));

    const updateData = {
      name: name.trim(),
    };

    // Add optional columns if they exist
    if (columns.description) updateData.description = description?.trim() || '';
    if (columns.updated_at) updateData.updated_at = new Date();

    console.log('Updating module:', moduleId, 'with data:', updateData);

    const [row] = await getQueryWithSoftDelete('modules')
      .where({ id: moduleId })
      .update(updateData)
      .returning('*');

    if (!row) {
      return res.status(404).json({ error: 'Module not found' });
    }

    console.log('Module updated successfully:', row);
    res.json(row);
  } catch (err) {
    console.error('Error updating module:', err);
    res.status(500).json({ error: 'Failed to update module', details: err.message });
  }
});

router.delete('/:moduleId', requireAnyRole(['Admin','Project Manager']), async (req, res) => {
  try {
    const moduleId = Number(req.params.moduleId);

    // Ensure soft delete columns exist
    await ensureSoftDeleteColumns('modules');

    // Perform soft delete
    const success = await softDelete('modules', moduleId, req.user.id);

    if (!success) {
      return res.status(404).json({ error: 'Module not found or already deleted' });
    }

    res.json({ ok: true, message: 'Module deleted successfully' });
  } catch (error) {
    console.error('Error deleting module:', error);
    res.status(500).json({ error: 'Failed to delete module' });
  }
});

export default router;

