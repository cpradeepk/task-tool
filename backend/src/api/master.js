import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { requireAnyRole } from '../middleware/rbac.js';
import { knex } from '../db/index.js';

const router = express.Router();
router.use(requireAuth);

router.get('/:table', async (req, res) => {
  try {
    const table = req.params.table;
    if (!['statuses','priorities','task_types','project_types'].includes(table)) {
      return res.status(400).json({ error: 'invalid table' });
    }

    console.log(`Fetching master data for table: ${table}`);

    // Check if table exists
    const tableExists = await knex.schema.hasTable(table);
    if (!tableExists) {
      console.log(`Table ${table} does not exist, returning default data`);

      // Return default data based on table type
      if (table === 'statuses') {
        return res.json([
          { id: 1, name: 'Open', color: '#ffffff' },
          { id: 2, name: 'In Progress', color: '#ffeb3b' },
          { id: 3, name: 'Completed', color: '#4caf50' },
          { id: 4, name: 'Cancelled', color: '#9e9e9e' },
          { id: 5, name: 'Hold', color: '#795548' },
          { id: 6, name: 'Delayed', color: '#f44336' }
        ]);
      } else if (table === 'priorities') {
        return res.json([
          { id: 1, name: 'Important & Urgent', order: 1, color: '#ff9800', matrix_quadrant: 'IU' },
          { id: 2, name: 'Important & Not Urgent', order: 2, color: '#ffeb3b', matrix_quadrant: 'IN' },
          { id: 3, name: 'Not Important & Urgent', order: 3, color: '#ffffff', matrix_quadrant: 'NU' },
          { id: 4, name: 'Not Important & Not Urgent', order: 4, color: '#ffffff', matrix_quadrant: 'NN' }
        ]);
      } else if (table === 'task_types') {
        return res.json([
          { id: 1, name: 'Requirement' },
          { id: 2, name: 'Design' },
          { id: 3, name: 'Coding' },
          { id: 4, name: 'Testing' },
          { id: 5, name: 'Learning' },
          { id: 6, name: 'Documentation' }
        ]);
      } else {
        return res.json([]);
      }
    }

    const rows = await knex(table).select('*').orderBy('id', 'asc');
    console.log(`Found ${rows.length} rows in ${table}`);
    res.json(rows);
  } catch (error) {
    console.error(`Error fetching master data for ${req.params.table}:`, error);
    res.status(500).json({ error: 'Failed to fetch master data', details: error.message });
  }
});

router.post('/:table', requireAnyRole(['Admin']), async (req, res) => {
  const table = req.params.table;
  if (!['statuses','priorities','task_types','project_types'].includes(table)) return res.status(400).json({ error: 'invalid table' });
  const [row] = await knex(table).insert(req.body).returning('*');
  res.status(201).json(row);
});

router.put('/:table/:id', requireAnyRole(['Admin']), async (req, res) => {
  const table = req.params.table;
  const id = Number(req.params.id);
  if (!['statuses','priorities','task_types','project_types'].includes(table)) return res.status(400).json({ error: 'invalid table' });
  const [row] = await knex(table).where({ id }).update(req.body).returning('*');
  res.json(row);
});

router.delete('/:table/:id', requireAnyRole(['Admin']), async (req, res) => {
  const table = req.params.table;
  const id = Number(req.params.id);
  if (!['statuses','priorities','task_types','project_types'].includes(table)) return res.status(400).json({ error: 'invalid table' });
  await knex(table).where({ id }).del();
  res.json({ ok: true });
});

export default router;

