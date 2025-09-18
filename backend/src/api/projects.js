import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';
import { requireAnyRole } from '../middleware/rbac.js';
import { softDelete, getQueryWithSoftDelete, ensureSoftDeleteColumns } from '../utils/softDelete.js';

const router = express.Router();

router.use(requireAuth);

router.get('/', async (req, res) => {
  try {
    // Ensure soft delete columns exist
    await ensureSoftDeleteColumns('projects');

    // Get projects excluding soft deleted ones
    const rows = await getQueryWithSoftDelete('projects')
      .select('*')
      .orderBy('id', 'desc');
    res.json(rows);
  } catch (error) {
    console.error('Error fetching projects:', error);
    res.status(500).json({ error: 'Failed to fetch projects' });
  }
});

router.get('/:id', async (req, res) => {
  try {
    const id = Number(req.params.id);
    if (isNaN(id)) {
      return res.status(400).json({ error: 'Invalid project ID' });
    }

    // Ensure soft delete columns exist
    await ensureSoftDeleteColumns('projects');

    // Get single project excluding soft deleted ones
    const project = await getQueryWithSoftDelete('projects')
      .select('*')
      .where('id', id)
      .first();

    if (!project) {
      return res.status(404).json({ error: 'Project not found' });
    }

    res.json(project);
  } catch (error) {
    console.error('Error fetching project:', error);
    res.status(500).json({ error: 'Failed to fetch project' });
  }
});

router.post('/', requireAnyRole(['Admin','Project Manager']), async (req, res) => {
  try {
    const { name, start_date } = req.body;
    if (!name) return res.status(400).json({ error: 'name required' });

    // Ensure soft delete columns exist
    await ensureSoftDeleteColumns('projects');

    const [row] = await knex('projects').insert({
      name,
      start_date,
      created_by: req.user.id
    }).returning('*');
    res.status(201).json(row);
  } catch (error) {
    console.error('Error creating project:', error);
    res.status(500).json({ error: 'Failed to create project' });
  }
});

router.put('/:id', requireAnyRole(['Admin','Project Manager']), async (req, res) => {
  try {
    const id = Number(req.params.id);
    const { name, start_date } = req.body;

    // Update only non-deleted projects
    const [row] = await getQueryWithSoftDelete('projects')
      .where({ id })
      .update({
        name,
        start_date,
        updated_at: knex.fn.now()
      })
      .returning('*');

    if (!row) {
      return res.status(404).json({ error: 'Project not found' });
    }

    res.json(row);
  } catch (error) {
    console.error('Error updating project:', error);
    res.status(500).json({ error: 'Failed to update project' });
  }
});

router.delete('/:id', requireAnyRole(['Admin','Project Manager']), async (req, res) => {
  try {
    const id = Number(req.params.id);

    // Ensure soft delete columns exist
    await ensureSoftDeleteColumns('projects');

    // Perform soft delete
    const success = await softDelete('projects', id, req.user.id);

    if (!success) {
      return res.status(404).json({ error: 'Project not found or already deleted' });
    }

    res.json({ ok: true, message: 'Project deleted successfully' });
  } catch (error) {
    console.error('Error deleting project:', error);
    res.status(500).json({ error: 'Failed to delete project' });
  }
});

export default router;

