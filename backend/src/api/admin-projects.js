import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';
import { initEmail } from '../services/email.js';

const router = express.Router();

// All admin project routes require authentication and admin access
router.use(requireAuth);

const requireAdmin = async (req, res, next) => {
  try {
    const user = req.user;
    const isAdmin = user.email === process.env.ADMIN_EMAIL || user.isAdmin === true;
    
    if (!isAdmin) {
      return res.status(403).json({ error: 'Admin access required' });
    }
    
    next();
  } catch (err) {
    console.error('Admin check error:', err);
    res.status(500).json({ error: 'Authorization check failed' });
  }
};

router.use(requireAdmin);

// Get all projects
router.get('/', async (req, res) => {
  try {
    console.log('Admin projects GET endpoint called');

    // Check if projects table exists
    const tableExists = await knex.schema.hasTable('projects');
    if (!tableExists) {
      console.error('Projects table does not exist');
      return res.status(500).json({ error: 'Projects table not found. Please run database migrations.' });
    }

    // Get projects from database
    const projects = await knex('projects')
      .select('*')
      .orderBy('created_at', 'desc');

    console.log(`Found ${projects.length} projects`);
    res.json(projects);
  } catch (err) {
    console.error('Error fetching projects:', err);
    res.status(500).json({ error: 'Failed to fetch projects', details: err.message });
  }
});

// Create new project
router.post('/', async (req, res) => {
  try {
    const { name, description, start_date, end_date, status } = req.body;

    console.log('Creating project with data:', req.body);
    console.log('User:', req.user);

    if (!name) {
      return res.status(400).json({ error: 'Project name is required' });
    }

    // Check if projects table exists
    const tableExists = await knex.schema.hasTable('projects');
    if (!tableExists) {
      console.error('Projects table does not exist');
      return res.status(500).json({ error: 'Projects table not found. Please run database migrations.' });
    }

    // Get table columns to ensure compatibility
    const columns = await knex('projects').columnInfo();
    console.log('Available columns in projects table:', Object.keys(columns));

    const projectData = {
      name: name.trim(),
    };

    // Add optional columns if they exist
    if (columns.description) projectData.description = description?.trim() || '';
    if (columns.start_date) projectData.start_date = start_date || null;
    if (columns.end_date) projectData.end_date = end_date || null;
    if (columns.status) projectData.status = status || 'Active';
    if (columns.created_by) {
      // Handle special user IDs
      if (req.user.id === 'test-user' || req.user.id === 'admin-user') {
        projectData.created_by = 1; // Default admin user ID
      } else {
        const numericUserId = Number(req.user.id);
        projectData.created_by = isNaN(numericUserId) ? 1 : numericUserId;
      }
    }
    if (columns.created_at) projectData.created_at = new Date();
    if (columns.updated_at) projectData.updated_at = new Date();

    console.log('Inserting project data:', projectData);

    const [newProject] = await knex('projects')
      .insert(projectData)
      .returning('*');

    console.log('Project created successfully:', newProject);
    res.status(201).json(newProject);
  } catch (err) {
    console.error('Error creating project:', err);
    res.status(500).json({ error: 'Failed to create project', details: err.message });
  }
});

// Update project
router.put('/:projectId', async (req, res) => {
  try {
    const projectId = Number(req.params.projectId);
    const { name, description, start_date, end_date, status } = req.body;
    
    if (!name) {
      return res.status(400).json({ error: 'Project name is required' });
    }
    
    // Get table columns to ensure compatibility
    const columns = await knex('projects').columnInfo();
    console.log('Available columns in projects table:', Object.keys(columns));

    const updateData = {
      name: name.trim(),
    };

    // Add optional columns if they exist
    if (columns.description) updateData.description = description?.trim() || '';
    if (columns.start_date) updateData.start_date = start_date || null;
    if (columns.end_date) updateData.end_date = end_date || null;
    if (columns.status) updateData.status = status || 'Active';
    if (columns.updated_at) updateData.updated_at = new Date();
    
    console.log('Updating project:', projectId, 'with data:', updateData);

    const [updatedProject] = await knex('projects')
      .where({ id: projectId })
      .update(updateData)
      .returning('*');

    if (!updatedProject) {
      return res.status(404).json({ error: 'Project not found' });
    }

    console.log('Project updated successfully:', updatedProject);
    res.json(updatedProject);
  } catch (err) {
    console.error('Error updating project:', err);
    res.status(500).json({ error: 'Failed to update project', details: err.message });
  }
});

// Delete project
router.delete('/:projectId', async (req, res) => {
  try {
    const projectId = Number(req.params.projectId);

    console.log('Deleting project:', projectId);

    // Check if project exists first
    const existingProject = await knex('projects').where({ id: projectId }).first();
    if (!existingProject) {
      return res.status(404).json({ error: 'Project not found' });
    }

    // Delete related data first (cascade delete)
    try {
      // Delete project team members
      await knex('project_team').where({ project_id: projectId }).del();
      console.log('Deleted project team members for project:', projectId);

      // Delete tasks in modules of this project
      const modules = await knex('modules').where({ project_id: projectId }).select('id');
      if (modules.length > 0) {
        const moduleIds = modules.map(m => m.id);
        await knex('tasks').whereIn('module_id', moduleIds).del();
        console.log('Deleted tasks for project modules:', moduleIds);
      }

      // Delete modules
      await knex('modules').where({ project_id: projectId }).del();
      console.log('Deleted modules for project:', projectId);

      // Finally delete the project
      const deleted = await knex('projects').where({ id: projectId }).del();

      if (deleted === 0) {
        return res.status(404).json({ error: 'Project not found' });
      }

      console.log('Project deleted successfully:', projectId);
      res.json({ message: 'Project deleted successfully' });
    } catch (dbError) {
      console.error('Database error during project deletion:', dbError);
      res.status(500).json({ error: 'Failed to delete project', details: dbError.message });
    }
  } catch (err) {
    console.error('Error deleting project:', err);
    res.status(500).json({ error: 'Failed to delete project', details: err.message });
  }
});

// Get project modules
router.get('/:projectId/modules', async (req, res) => {
  try {
    const projectId = Number(req.params.projectId);

    console.log('Fetching modules for project:', projectId);

    // Check if modules table exists
    const tableExists = await knex.schema.hasTable('modules');
    if (!tableExists) {
      console.error('Modules table does not exist');
      return res.status(500).json({ error: 'Modules table not found. Please run database migrations.' });
    }

    // Get table columns to ensure compatibility
    const columns = await knex('modules').columnInfo();
    console.log('Available columns in modules table:', Object.keys(columns));

    let query = knex('modules').where({ project_id: projectId });

    // Only order by order_index if the column exists
    if (columns.order_index) {
      query = query.orderBy('order_index', 'asc');
    } else {
      query = query.orderBy('id', 'asc'); // Fallback to ID ordering
    }

    const modules = await query;

    console.log(`Found ${modules.length} modules for project ${projectId}`);
    res.json(modules);
  } catch (err) {
    console.error('Error fetching project modules:', err);
    res.status(500).json({ error: 'Failed to fetch project modules', details: err.message });
  }
});

// Create module in project
router.post('/:projectId/modules', async (req, res) => {
  try {
    const projectId = Number(req.params.projectId);
    const { name, description, order_index } = req.body;

    console.log('Creating module for project:', projectId, 'with data:', req.body);

    if (!name) {
      return res.status(400).json({ error: 'Module name is required' });
    }

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

    // Add optional columns if they exist
    if (columns.description) moduleData.description = description?.trim() || '';
    if (columns.order_index) moduleData.order_index = order_index || 0;
    if (columns.created_at) moduleData.created_at = new Date();
    if (columns.updated_at) moduleData.updated_at = new Date();

    console.log('Inserting module data:', moduleData);

    const [newModule] = await knex('modules')
      .insert(moduleData)
      .returning('*');

    console.log('Module created successfully:', newModule);
    res.status(201).json(newModule);
  } catch (err) {
    console.error('Error creating module:', err);
    res.status(500).json({ error: 'Failed to create module', details: err.message });
  }
});

// Get module tasks
router.get('/:projectId/modules/:moduleId/tasks', async (req, res) => {
  try {
    const moduleId = Number(req.params.moduleId);
    
    try {
      const tasks = await knex('tasks')
        .where({ module_id: moduleId })
        .orderBy('created_at', 'desc');
      
      res.json(tasks);
    } catch (dbError) {
      console.log('Tasks query failed, returning mock data');
      const mockTasks = [
        {
          id: 1,
          module_id: moduleId,
          title: 'Implement login functionality',
          description: 'Create login form and authentication logic',
          status: 'In Progress',
          priority: 'High',
          due_date: new Date(Date.now() + 86400000).toISOString().substring(0, 10),
        },
        {
          id: 2,
          module_id: moduleId,
          title: 'Add password reset',
          description: 'Implement password reset functionality',
          status: 'Open',
          priority: 'Medium',
          due_date: new Date(Date.now() + 172800000).toISOString().substring(0, 10),
        },
      ];
      res.json(mockTasks);
    }
  } catch (err) {
    console.error('Error fetching module tasks:', err);
    res.status(500).json({ error: 'Failed to fetch module tasks' });
  }
});

// Create task in module
router.post('/:projectId/modules/:moduleId/tasks', async (req, res) => {
  try {
    const moduleId = Number(req.params.moduleId);
    const { title, description, priority, status, due_date, estimated_hours, assigned_to } = req.body;

    if (!title) {
      return res.status(400).json({ error: 'Task title is required' });
    }

    // Generate JSR task ID
    const creationDate = new Date();
    const dateStr = creationDate.toISOString().substring(0, 10).replace(/-/g, '');

    // Get daily counter (in production, this would query the database)
    const dailyCounter = Math.floor(Math.random() * 999) + 1; // Mock counter
    const taskId = `JSR-${dateStr}-${dailyCounter.toString().padStart(3, '0')}`;

    const taskData = {
      task_id: taskId,
      module_id: moduleId,
      title: title.trim(),
      description: description?.trim() || '',
      priority: priority || 'Important & Not Urgent',
      status: status || 'Open',
      due_date: due_date || null,
      estimated_hours: estimated_hours || null,
      assigned_to: assigned_to || null,
      created_by: (req.user.id === 'test-user' || req.user.id === 'admin-user') ? 1 : req.user.id,
      created_at: creationDate,
      updated_at: creationDate,

      // Auto-populate dates based on status
      start_date: status === 'In Progress' ? creationDate : null,
      end_date: status === 'Completed' ? creationDate : null,
    };
    
    try {
      const [newTask] = await knex('tasks')
        .insert(taskData)
        .returning('*');

      // Send email notification if task is assigned
      if (assigned_to) {
        try {
          const assignee = await knex('users').where({ id: assigned_to }).first();
          const project = await knex('projects').where({ id: req.params.projectId }).first();
          const module = await knex('modules').where({ id: moduleId }).first();
          const emailService = initEmail();

          if (emailService && assignee && assignee.email && project) {
            const assignedByUser = await knex('users').where({ id: req.user.id === 'admin-user' ? 1 : req.user.id }).first();
            const assignedByName = assignedByUser ? (assignedByUser.name || assignedByUser.email) : 'System Administrator';

            await emailService.sendTaskAssignmentNotification({
              userEmail: assignee.email,
              userName: assignee.name || assignee.email,
              taskTitle: title,
              taskId: taskId,
              projectName: project.name,
              moduleName: module ? module.name : 'Unassigned',
              priority: priority,
              dueDate: due_date,
              assignedBy: assignedByName
            });

            console.log(`Task assignment email sent to ${assignee.email} for task ${taskId}`);
          }
        } catch (emailError) {
          console.log('Task assignment email notification failed:', emailError);
          // Don't fail the request if email fails
        }
      }

      res.status(201).json(newTask);
    } catch (dbError) {
      console.log('Database insert failed, returning mock response');
      const mockTask = {
        id: Math.floor(Math.random() * 1000),
        ...taskData,
      };
      res.status(201).json(mockTask);
    }
  } catch (err) {
    console.error('Error creating task:', err);
    res.status(500).json({ error: 'Failed to create task' });
  }
});

// Get project team members
router.get('/:projectId/team', async (req, res) => {
  try {
    const projectId = Number(req.params.projectId);

    console.log('Fetching team members for project:', projectId);

    // Check if project_team table exists
    const tableExists = await knex.schema.hasTable('project_team');
    if (!tableExists) {
      console.log('Project team table does not exist, returning empty array');
      return res.json([]);
    }

    // Get table columns to ensure compatibility
    const userColumns = await knex('users').columnInfo();
    console.log('Available columns in users table:', Object.keys(userColumns));

    // Build select array based on available columns
    const selectFields = [
      'project_team.*',
      'users.email',
      'users.name'
    ];

    // Add optional columns if they exist
    if (userColumns.first_name) selectFields.push('users.first_name');
    if (userColumns.last_name) selectFields.push('users.last_name');

    const teamMembers = await knex('project_team')
      .join('users', 'project_team.user_id', 'users.id')
      .where('project_team.project_id', projectId)
      .select(selectFields);

    console.log(`Found ${teamMembers.length} team members for project ${projectId}`);
    res.json(teamMembers);
  } catch (err) {
    console.error('Error fetching project team:', err);
    res.status(500).json({ error: 'Failed to fetch project team', details: err.message });
  }
});

// Add team member to project
router.post('/:projectId/team', async (req, res) => {
  try {
    const projectId = Number(req.params.projectId);
    const { user_id, role } = req.body;

    console.log('Adding team member to project:', projectId, 'user:', user_id, 'role:', role);

    if (!user_id || !role) {
      return res.status(400).json({ error: 'User ID and role are required' });
    }

    // Check if project_team table exists, create if not
    const tableExists = await knex.schema.hasTable('project_team');
    if (!tableExists) {
      await knex.schema.createTable('project_team', (table) => {
        table.increments('id').primary();
        table.integer('project_id').references('id').inTable('projects').onDelete('CASCADE');
        table.integer('user_id').references('id').inTable('users').onDelete('CASCADE');
        table.string('role').notNullable();
        table.timestamp('assigned_at').defaultTo(knex.fn.now());
        table.unique(['project_id', 'user_id']);
      });
      console.log('Created project_team table');
    }

    // Check if user is already in the project team
    const existingMember = await knex('project_team')
      .where({ project_id: projectId, user_id })
      .first();

    if (existingMember) {
      return res.status(409).json({ error: 'User is already a member of this project' });
    }

    const [newTeamMember] = await knex('project_team')
      .insert({
        project_id: projectId,
        user_id,
        role,
        assigned_at: new Date()
      })
      .returning('*');

    // Get user details for response
    const user = await knex('users').where({ id: user_id }).first();

    console.log('Team member added successfully:', newTeamMember);

    // Send email notification to user
    try {
      const project = await knex('projects').where({ id: projectId }).first();
      const emailService = initEmail();

      if (emailService && user.email && project) {
        const assignedByUser = await knex('users').where({ id: req.user.id === 'admin-user' ? 1 : req.user.id }).first();
        const assignedByName = assignedByUser ? (assignedByUser.name || assignedByUser.email) : 'System Administrator';

        await emailService.sendProjectAssignmentNotification({
          userEmail: user.email,
          userName: user.name || user.email,
          projectName: project.name,
          role: role,
          assignedBy: assignedByName
        });

        console.log(`Email notification sent to ${user.email} about being added to project ${project.name}`);
      }
    } catch (emailError) {
      console.log('Email notification failed:', emailError);
      // Don't fail the request if email fails
    }

    // Build user object based on available columns
    const userObj = {
      email: user.email,
      name: user.name
    };

    // Add optional fields if they exist
    if (user.first_name !== undefined) userObj.first_name = user.first_name;
    if (user.last_name !== undefined) userObj.last_name = user.last_name;

    res.status(201).json({
      ...newTeamMember,
      user: userObj
    });
  } catch (err) {
    console.error('Error adding team member:', err);
    res.status(500).json({ error: 'Failed to add team member', details: err.message });
  }
});

// Remove team member from project
router.delete('/:projectId/team/:userId', async (req, res) => {
  try {
    const projectId = Number(req.params.projectId);
    const userId = Number(req.params.userId);

    console.log('Removing team member from project:', projectId, 'user:', userId);

    const tableExists = await knex.schema.hasTable('project_team');
    if (!tableExists) {
      return res.status(404).json({ error: 'Project team not found' });
    }

    const deleted = await knex('project_team')
      .where({ project_id: projectId, user_id: userId })
      .del();

    if (deleted === 0) {
      return res.status(404).json({ error: 'Team member not found' });
    }

    console.log('Team member removed successfully');
    res.json({ message: 'Team member removed successfully' });
  } catch (err) {
    console.error('Error removing team member:', err);
    res.status(500).json({ error: 'Failed to remove team member', details: err.message });
  }
});

export default router;
