import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';

const router = express.Router();

// All notes routes require authentication
router.use(requireAuth);

// Get user's notes
router.get('/', async (req, res) => {
  try {
    const userId = req.user.id;
    
    const notes = await knex('notes')
      .where('user_id', userId)
      .orderBy('updated_at', 'desc');
    
    res.json(notes);
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
