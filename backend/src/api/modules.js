import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';
import { requireAnyRole } from '../middleware/rbac.js';

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

    const rows = await knex('modules').where({ project_id: projectId }).orderBy('id', 'desc');

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

    const [row] = await knex('modules').insert({ project_id: projectId, name }).returning('*');

    console.log('Module created successfully:', row);
    res.status(201).json(row);
  } catch (err) {
    console.error('Error creating module:', err);
    res.status(500).json({ error: 'Failed to create module', details: err.message });
  }
});

router.put('/:moduleId', requireAnyRole(['Admin','Project Manager']), async (req, res) => {
  const moduleId = Number(req.params.moduleId);
  const { name } = req.body;
  const [row] = await knex('modules').where({ id: moduleId }).update({ name }).returning('*');
  res.json(row);
});

router.delete('/:moduleId', requireAnyRole(['Admin','Project Manager']), async (req, res) => {
  const moduleId = Number(req.params.moduleId);
  await knex('modules').where({ id: moduleId }).del();
  res.json({ ok: true });
});

export default router;

