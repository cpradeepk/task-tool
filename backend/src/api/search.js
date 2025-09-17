import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';

const router = express.Router();
router.use(requireAuth);

// Global search endpoint
router.get('/', async (req, res) => {
  try {
    const userId = req.user.id;
    const isAdmin = req.user.isAdmin;
    const { 
      q: query, 
      type = 'all', 
      limit = 20, 
      offset = 0,
      project_id,
      date_from,
      date_to,
      status,
      priority,
      category
    } = req.query;

    if (!query || query.trim().length < 2) {
      return res.status(400).json({ error: 'Search query must be at least 2 characters' });
    }

    const searchTerm = `%${query.trim()}%`;
    const results = {
      query: query.trim(),
      total_results: 0,
      results: {
        projects: [],
        tasks: [],
        notes: [],
        chat_messages: [],
        files: []
      }
    };

    // Search Projects
    if (type === 'all' || type === 'projects') {
      let projectQuery = knex('projects')
        .select('id', 'name', 'description', 'status', 'created_at', 'updated_at')
        .where(function() {
          this.where('name', 'ilike', searchTerm)
              .orWhere('description', 'ilike', searchTerm);
        });

      if (!isAdmin) {
        projectQuery = projectQuery.where('created_by', userId);
      }

      if (status) {
        projectQuery = projectQuery.where('status', status);
      }

      if (date_from) {
        projectQuery = projectQuery.where('created_at', '>=', date_from);
      }

      if (date_to) {
        projectQuery = projectQuery.where('created_at', '<=', date_to);
      }

      const projects = await projectQuery.limit(parseInt(limit)).offset(parseInt(offset));
      results.results.projects = projects.map(project => ({
        ...project,
        type: 'project',
        relevance_score: calculateRelevance(query, project.name, project.description)
      }));
    }

    // Search Tasks
    if (type === 'all' || type === 'tasks') {
      let taskQuery = knex('tasks')
        .select('tasks.*', 'projects.name as project_name')
        .leftJoin('projects', 'tasks.project_id', 'projects.id')
        .where(function() {
          this.where('tasks.title', 'ilike', searchTerm)
              .orWhere('tasks.description', 'ilike', searchTerm);
        });

      if (!isAdmin) {
        taskQuery = taskQuery.where(function() {
          this.where('tasks.assigned_to', userId)
              .orWhere('tasks.created_by', userId);
        });
      }

      if (project_id) {
        taskQuery = taskQuery.where('tasks.project_id', parseInt(project_id));
      }

      if (status) {
        taskQuery = taskQuery.where('tasks.status', status);
      }

      if (priority) {
        taskQuery = taskQuery.where('tasks.priority', priority);
      }

      if (date_from) {
        taskQuery = taskQuery.where('tasks.created_at', '>=', date_from);
      }

      if (date_to) {
        taskQuery = taskQuery.where('tasks.created_at', '<=', date_to);
      }

      const tasks = await taskQuery.limit(parseInt(limit)).offset(parseInt(offset));
      results.results.tasks = tasks.map(task => ({
        ...task,
        type: 'task',
        relevance_score: calculateRelevance(query, task.title, task.description)
      }));
    }

    // Search Notes
    if (type === 'all' || type === 'notes') {
      let notesQuery = knex('notes')
        .select('notes.*', 'projects.name as project_name')
        .leftJoin('projects', 'notes.project_id', 'projects.id')
        .where(function() {
          this.where('notes.title', 'ilike', searchTerm)
              .orWhere('notes.content', 'ilike', searchTerm)
              .orWhere('notes.tags', 'ilike', searchTerm);
        });

      if (!isAdmin) {
        notesQuery = notesQuery.where('notes.user_id', userId);
      }

      if (project_id) {
        notesQuery = notesQuery.where('notes.project_id', parseInt(project_id));
      }

      if (category) {
        notesQuery = notesQuery.where('notes.category', category);
      }

      if (date_from) {
        notesQuery = notesQuery.where('notes.created_at', '>=', date_from);
      }

      if (date_to) {
        notesQuery = notesQuery.where('notes.created_at', '<=', date_to);
      }

      const notes = await notesQuery.limit(parseInt(limit)).offset(parseInt(offset));
      results.results.notes = notes.map(note => ({
        ...note,
        type: 'note',
        relevance_score: calculateRelevance(query, note.title, note.content, note.tags)
      }));
    }

    // Search Chat Messages
    if (type === 'all' || type === 'chat') {
      let chatQuery = knex('chat_messages')
        .select('chat_messages.*', 'chat_channels.name as channel_name', 'users.name as user_name')
        .leftJoin('chat_channels', 'chat_messages.channel_id', 'chat_channels.id')
        .leftJoin('users', 'chat_messages.user_id', 'users.id')
        .where('chat_messages.content', 'ilike', searchTerm);

      if (!isAdmin) {
        // Only show messages from channels the user is a member of
        chatQuery = chatQuery.whereExists(function() {
          this.select('*')
              .from('channel_members')
              .whereRaw('channel_members.channel_id = chat_messages.channel_id')
              .where('channel_members.user_id', userId);
        });
      }

      if (date_from) {
        chatQuery = chatQuery.where('chat_messages.created_at', '>=', date_from);
      }

      if (date_to) {
        chatQuery = chatQuery.where('chat_messages.created_at', '<=', date_to);
      }

      const chatMessages = await chatQuery.limit(parseInt(limit)).offset(parseInt(offset));
      results.results.chat_messages = chatMessages.map(message => ({
        ...message,
        type: 'chat_message',
        relevance_score: calculateRelevance(query, message.content)
      }));
    }

    // Search Files
    if (type === 'all' || type === 'files') {
      let filesQuery = knex('file_uploads')
        .select('file_uploads.*', 'projects.name as project_name')
        .leftJoin('projects', 'file_uploads.project_id', 'projects.id')
        .where(function() {
          this.where('file_uploads.original_name', 'ilike', searchTerm)
              .orWhere('file_uploads.description', 'ilike', searchTerm);
        });

      if (!isAdmin) {
        filesQuery = filesQuery.where('file_uploads.user_id', userId);
      }

      if (project_id) {
        filesQuery = filesQuery.where('file_uploads.project_id', parseInt(project_id));
      }

      if (category) {
        filesQuery = filesQuery.where('file_uploads.category', category);
      }

      if (date_from) {
        filesQuery = filesQuery.where('file_uploads.created_at', '>=', date_from);
      }

      if (date_to) {
        filesQuery = filesQuery.where('file_uploads.created_at', '<=', date_to);
      }

      const files = await filesQuery.limit(parseInt(limit)).offset(parseInt(offset));
      results.results.files = files.map(file => ({
        ...file,
        type: 'file',
        relevance_score: calculateRelevance(query, file.original_name, file.description)
      }));
    }

    // Calculate total results
    results.total_results = Object.values(results.results).reduce((sum, arr) => sum + arr.length, 0);

    // Sort all results by relevance score
    const allResults = Object.values(results.results).flat().sort((a, b) => b.relevance_score - a.relevance_score);
    
    res.json({
      ...results,
      sorted_results: allResults.slice(0, parseInt(limit))
    });

  } catch (error) {
    console.error('Search error:', error);
    res.status(500).json({ error: 'Search failed' });
  }
});

// Calculate relevance score based on query match
function calculateRelevance(query, ...fields) {
  const queryLower = query.toLowerCase();
  let score = 0;

  fields.forEach(field => {
    if (!field) return;
    
    const fieldLower = field.toString().toLowerCase();
    
    // Exact match gets highest score
    if (fieldLower === queryLower) {
      score += 100;
    }
    // Starts with query gets high score
    else if (fieldLower.startsWith(queryLower)) {
      score += 80;
    }
    // Contains query gets medium score
    else if (fieldLower.includes(queryLower)) {
      score += 50;
    }
    // Word boundary match gets lower score
    else if (new RegExp(`\\b${queryLower}`, 'i').test(fieldLower)) {
      score += 30;
    }
  });

  return score;
}

// Advanced filters endpoint
router.get('/filters', async (req, res) => {
  try {
    const userId = req.user.id;
    const isAdmin = req.user.isAdmin;

    // Get available filter options
    const filters = {
      projects: [],
      statuses: {
        projects: ['active', 'completed', 'on_hold', 'cancelled'],
        tasks: ['todo', 'in_progress', 'review', 'done', 'cancelled']
      },
      priorities: ['low', 'medium', 'high', 'urgent'],
      categories: {
        notes: [],
        files: []
      },
      users: []
    };

    // Get projects for filtering
    let projectsQuery = knex('projects').select('id', 'name', 'status');
    if (!isAdmin) {
      projectsQuery = projectsQuery.where('created_by', userId);
    }
    filters.projects = await projectsQuery.orderBy('name');

    // Get note categories
    let noteCategoriesQuery = knex('notes').distinct('category').whereNotNull('category');
    if (!isAdmin) {
      noteCategoriesQuery = noteCategoriesQuery.where('user_id', userId);
    }
    const noteCategories = await noteCategoriesQuery;
    filters.categories.notes = noteCategories.map(c => c.category).filter(Boolean);

    // Get file categories
    let fileCategoriesQuery = knex('file_uploads').distinct('category').whereNotNull('category');
    if (!isAdmin) {
      fileCategoriesQuery = fileCategoriesQuery.where('user_id', userId);
    }
    const fileCategories = await fileCategoriesQuery;
    filters.categories.files = fileCategories.map(c => c.category).filter(Boolean);

    // Get users (for admin)
    if (isAdmin) {
      filters.users = await knex('users').select('id', 'name', 'email').orderBy('name');
    }

    res.json(filters);
  } catch (error) {
    console.error('Error fetching filters:', error);
    res.status(500).json({ error: 'Failed to fetch filters' });
  }
});

// Search suggestions endpoint
router.get('/suggestions', async (req, res) => {
  try {
    const userId = req.user.id;
    const isAdmin = req.user.isAdmin;
    const { q: query, limit = 10 } = req.query;

    if (!query || query.trim().length < 1) {
      return res.json({ suggestions: [] });
    }

    const searchTerm = `%${query.trim()}%`;
    const suggestions = [];

    // Get project name suggestions
    let projectQuery = knex('projects').select('name').where('name', 'ilike', searchTerm);
    if (!isAdmin) {
      projectQuery = projectQuery.where('created_by', userId);
    }
    const projects = await projectQuery.limit(5);
    suggestions.push(...projects.map(p => ({ text: p.name, type: 'project' })));

    // Get task title suggestions
    let taskQuery = knex('tasks').select('title').where('title', 'ilike', searchTerm);
    if (!isAdmin) {
      taskQuery = taskQuery.where(function() {
        this.where('assigned_to', userId).orWhere('created_by', userId);
      });
    }
    const tasks = await taskQuery.limit(5);
    suggestions.push(...tasks.map(t => ({ text: t.title, type: 'task' })));

    // Get note title suggestions
    let noteQuery = knex('notes').select('title').where('title', 'ilike', searchTerm);
    if (!isAdmin) {
      noteQuery = noteQuery.where('user_id', userId);
    }
    const notes = await noteQuery.limit(5);
    suggestions.push(...notes.map(n => ({ text: n.title, type: 'note' })));

    // Remove duplicates and limit results
    const uniqueSuggestions = suggestions
      .filter((suggestion, index, self) =>
        index === self.findIndex(s => s.text === suggestion.text)
      )
      .slice(0, parseInt(limit));

    res.json({ suggestions: uniqueSuggestions });
  } catch (error) {
    console.error('Error fetching suggestions:', error);
    res.status(500).json({ error: 'Failed to fetch suggestions' });
  }
});

// Search statistics endpoint
router.get('/stats', async (req, res) => {
  try {
    const userId = req.user.id;
    const isAdmin = req.user.isAdmin;

    const stats = {
      total_searchable_items: 0,
      breakdown: {
        projects: 0,
        tasks: 0,
        notes: 0,
        chat_messages: 0,
        files: 0
      },
      recent_searches: []
    };

    // Count projects
    let projectCount = knex('projects').count('* as count');
    if (!isAdmin) {
      projectCount = projectCount.where('created_by', userId);
    }
    const [{ count: projects }] = await projectCount;
    stats.breakdown.projects = parseInt(projects);

    // Count tasks
    let taskCount = knex('tasks').count('* as count');
    if (!isAdmin) {
      taskCount = taskCount.where(function() {
        this.where('assigned_to', userId).orWhere('created_by', userId);
      });
    }
    const [{ count: tasks }] = await taskCount;
    stats.breakdown.tasks = parseInt(tasks);

    // Count notes
    let noteCount = knex('notes').count('* as count');
    if (!isAdmin) {
      noteCount = noteCount.where('user_id', userId);
    }
    const [{ count: notes }] = await noteCount;
    stats.breakdown.notes = parseInt(notes);

    // Count chat messages
    let chatCount = knex('chat_messages').count('* as count');
    if (!isAdmin) {
      chatCount = chatCount.whereExists(function() {
        this.select('*')
            .from('channel_members')
            .whereRaw('channel_members.channel_id = chat_messages.channel_id')
            .where('channel_members.user_id', userId);
      });
    }
    const [{ count: chatMessages }] = await chatCount;
    stats.breakdown.chat_messages = parseInt(chatMessages);

    // Count files
    let fileCount = knex('file_uploads').count('* as count');
    if (!isAdmin) {
      fileCount = fileCount.where('user_id', userId);
    }
    const [{ count: files }] = await fileCount;
    stats.breakdown.files = parseInt(files);

    stats.total_searchable_items = Object.values(stats.breakdown).reduce((sum, count) => sum + count, 0);

    res.json(stats);
  } catch (error) {
    console.error('Error fetching search stats:', error);
    res.status(500).json({ error: 'Failed to fetch search statistics' });
  }
});

export default router;
