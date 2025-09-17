import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';

const router = express.Router();

// All notes routes require authentication
router.use(requireAuth);

// Get user's notes with filtering and search
router.get('/', async (req, res) => {
  try {
    const userId = req.user.id;
    const { category, search, limit = 50, offset = 0 } = req.query;

    let query = knex('notes').where('user_id', userId);

    // Filter by category
    if (category) {
      query = query.where('category', category);
    }

    // Search in title and content
    if (search) {
      query = query.where(function() {
        this.where('title', 'ilike', `%${search}%`)
          .orWhere('content', 'ilike', `%${search}%`);
      });
    }

    // Get total count for pagination
    const totalQuery = query.clone();
    const [{ count: totalCount }] = await totalQuery.count('* as count').catch(() => [{ count: 0 }]);

    // Apply pagination and ordering
    const notes = await query
      .orderBy('updated_at', 'desc')
      .limit(parseInt(limit))
      .offset(parseInt(offset))
      .catch(() => []);

    // Parse tags from JSON strings
    const notesWithParsedTags = notes.map(note => ({
      ...note,
      tags: note.tags ? JSON.parse(note.tags) : []
    }));

    res.json({
      notes: notesWithParsedTags,
      pagination: {
        total: parseInt(totalCount),
        limit: parseInt(limit),
        offset: parseInt(offset),
        has_more: parseInt(offset) + parseInt(limit) < parseInt(totalCount)
      }
    });
  } catch (err) {
    console.error('Error fetching notes:', err);
    res.status(500).json({ error: 'Failed to fetch notes' });
  }
});

// Create new note
router.post('/', async (req, res) => {
  try {
    const userId = req.user.id;
    const { title, content, category, tags } = req.body;
    
    if (!title || !content) {
      return res.status(400).json({ error: 'Title and content are required' });
    }
    
    const [note] = await knex('notes')
      .insert({
        user_id: userId,
        title: title.trim(),
        content: content.trim(),
        category: category || 'Work',
        tags: JSON.stringify(tags || []),
        created_at: new Date(),
        updated_at: new Date()
      })
      .returning('*');
    
    res.status(201).json(note);
  } catch (err) {
    console.error('Error creating note:', err);
    res.status(500).json({ error: 'Failed to create note' });
  }
});

// Update note
router.put('/:noteId', async (req, res) => {
  try {
    const userId = req.user.id;
    const noteId = Number(req.params.noteId);
    const { title, content, category, tags } = req.body;
    
    if (!title || !content) {
      return res.status(400).json({ error: 'Title and content are required' });
    }
    
    const [note] = await knex('notes')
      .where({ id: noteId, user_id: userId })
      .update({
        title: title.trim(),
        content: content.trim(),
        category: category || 'Work',
        tags: JSON.stringify(tags || []),
        updated_at: new Date()
      })
      .returning('*');
    
    if (!note) {
      return res.status(404).json({ error: 'Note not found' });
    }
    
    res.json(note);
  } catch (err) {
    console.error('Error updating note:', err);
    res.status(500).json({ error: 'Failed to update note' });
  }
});

// Get single note
router.get('/:noteId', async (req, res) => {
  try {
    const userId = req.user.id;
    const noteId = Number(req.params.noteId);

    const note = await knex('notes')
      .where({ id: noteId, user_id: userId })
      .first()
      .catch(() => null);

    if (!note) {
      return res.status(404).json({ error: 'Note not found' });
    }

    // Parse tags from JSON string
    note.tags = note.tags ? JSON.parse(note.tags) : [];

    res.json(note);
  } catch (err) {
    console.error('Error fetching note:', err);
    res.status(500).json({ error: 'Failed to fetch note' });
  }
});

// Get note categories
router.get('/categories/list', async (req, res) => {
  try {
    const userId = req.user.id;

    const categories = await knex('notes')
      .where('user_id', userId)
      .distinct('category')
      .whereNotNull('category')
      .pluck('category')
      .catch(() => []);

    // Add default categories if none exist
    const defaultCategories = ['Work', 'Personal', 'Ideas', 'Meeting Notes'];
    const allCategories = [...new Set([...categories, ...defaultCategories])];

    res.json({
      categories: allCategories,
      total: allCategories.length
    });
  } catch (err) {
    console.error('Error fetching categories:', err);
    res.status(500).json({ error: 'Failed to fetch categories' });
  }
});

// Get notes statistics
router.get('/stats/summary', async (req, res) => {
  try {
    const userId = req.user.id;

    const [totalNotes] = await knex('notes')
      .where('user_id', userId)
      .count('* as count')
      .catch(() => [{ count: 0 }]);

    const categoryCounts = await knex('notes')
      .where('user_id', userId)
      .select('category')
      .count('* as count')
      .groupBy('category')
      .catch(() => []);

    const recentNotes = await knex('notes')
      .where('user_id', userId)
      .where('created_at', '>', knex.raw("NOW() - INTERVAL '7 days'"))
      .count('* as count')
      .first()
      .catch(() => ({ count: 0 }));

    res.json({
      total_notes: parseInt(totalNotes.count),
      recent_notes: parseInt(recentNotes.count),
      categories: categoryCounts.map(cat => ({
        category: cat.category,
        count: parseInt(cat.count)
      }))
    });
  } catch (err) {
    console.error('Error fetching notes stats:', err);
    res.status(500).json({ error: 'Failed to fetch notes statistics' });
  }
});

// Delete note
router.delete('/:noteId', async (req, res) => {
  try {
    const userId = req.user.id;
    const noteId = Number(req.params.noteId);

    const deleted = await knex('notes')
      .where({ id: noteId, user_id: userId })
      .del();

    if (deleted === 0) {
      return res.status(404).json({ error: 'Note not found' });
    }

    res.json({ message: 'Note deleted successfully' });
  } catch (err) {
    console.error('Error deleting note:', err);
    res.status(500).json({ error: 'Failed to delete note' });
  }
});

export default router;
