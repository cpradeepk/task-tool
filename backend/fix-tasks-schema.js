import 'dotenv/config';
import { knex } from './src/db/index.js';

async function fixTasksSchema() {
  try {
    console.log('🔧 Starting tasks schema fix...');
    
    // Check database connection
    await knex.raw('SELECT 1');
    console.log('✅ Database connection established');

    // Check if tasks table exists
    const tasksExists = await knex.schema.hasTable('tasks');
    if (!tasksExists) {
      console.log('❌ Tasks table does not exist');
      return;
    }

    console.log('📋 Checking current tasks table schema...');
    
    // Check for missing columns
    const columns = {
      project_id: await knex.schema.hasColumn('tasks', 'project_id'),
      task_id: await knex.schema.hasColumn('tasks', 'task_id'),
      assigned_to: await knex.schema.hasColumn('tasks', 'assigned_to'),
      created_by: await knex.schema.hasColumn('tasks', 'created_by'),
      updated_at: await knex.schema.hasColumn('tasks', 'updated_at'),
      estimated_hours: await knex.schema.hasColumn('tasks', 'estimated_hours'),
      actual_hours: await knex.schema.hasColumn('tasks', 'actual_hours'),
      due_date: await knex.schema.hasColumn('tasks', 'due_date'),
      completed_at: await knex.schema.hasColumn('tasks', 'completed_at'),
      status_id: await knex.schema.hasColumn('tasks', 'status_id'),
      priority_id: await knex.schema.hasColumn('tasks', 'priority_id'),
      task_type_id: await knex.schema.hasColumn('tasks', 'task_type_id')
    };

    console.log('Current column status:', columns);

    // Add missing columns
    await knex.schema.alterTable('tasks', (table) => {
      if (!columns.project_id) {
        table.integer('project_id').references('id').inTable('projects').onDelete('CASCADE');
        console.log('✅ Added project_id column');
      }

      if (!columns.task_id) {
        table.string('task_id').unique();
        console.log('✅ Added task_id column');
      }

      if (!columns.assigned_to) {
        table.integer('assigned_to').references('id').inTable('users');
        console.log('✅ Added assigned_to column');
      }

      if (!columns.created_by) {
        table.integer('created_by').references('id').inTable('users');
        console.log('✅ Added created_by column');
      }

      if (!columns.updated_at) {
        table.timestamp('updated_at').defaultTo(knex.fn.now());
        console.log('✅ Added updated_at column');
      }

      if (!columns.estimated_hours) {
        table.integer('estimated_hours');
        console.log('✅ Added estimated_hours column');
      }

      if (!columns.actual_hours) {
        table.integer('actual_hours');
        console.log('✅ Added actual_hours column');
      }

      if (!columns.due_date) {
        table.date('due_date');
        console.log('✅ Added due_date column');
      }

      if (!columns.completed_at) {
        table.timestamp('completed_at');
        console.log('✅ Added completed_at column');
      }

      if (!columns.status_id) {
        table.integer('status_id').references('id').inTable('statuses');
        console.log('✅ Added status_id column');
      }

      if (!columns.priority_id) {
        table.integer('priority_id').references('id').inTable('priorities');
        console.log('✅ Added priority_id column');
      }

      if (!columns.task_type_id) {
        table.integer('task_type_id').references('id').inTable('task_types');
        console.log('✅ Added task_type_id column');
      }
    });

    // Update existing tasks to have project_id based on their module
    if (!columns.project_id) {
      const tasksWithoutProjectId = await knex('tasks')
        .leftJoin('modules', 'tasks.module_id', 'modules.id')
        .whereNull('tasks.project_id')
        .whereNotNull('modules.project_id')
        .select('tasks.id', 'modules.project_id');

      for (const task of tasksWithoutProjectId) {
        await knex('tasks')
          .where('id', task.id)
          .update('project_id', task.project_id);
      }

      console.log(`✅ Updated ${tasksWithoutProjectId.length} tasks with project_id`);
    }

    // Ensure master data tables exist and have default data
    console.log('📋 Checking master data tables...');
    
    const statusesExists = await knex.schema.hasTable('statuses');
    const prioritiesExists = await knex.schema.hasTable('priorities');
    const taskTypesExists = await knex.schema.hasTable('task_types');

    if (!statusesExists) {
      await knex.schema.createTable('statuses', (table) => {
        table.increments('id').primary();
        table.string('name').notNullable().unique();
        table.string('color').notNullable();
      });
      console.log('✅ Created statuses table');
    }

    if (!prioritiesExists) {
      await knex.schema.createTable('priorities', (table) => {
        table.increments('id').primary();
        table.string('name').notNullable();
        table.integer('order').notNullable();
        table.string('color').notNullable();
        table.string('matrix_quadrant').notNullable();
      });
      console.log('✅ Created priorities table');
    }

    if (!taskTypesExists) {
      await knex.schema.createTable('task_types', (table) => {
        table.increments('id').primary();
        table.string('name').notNullable().unique();
      });
      console.log('✅ Created task_types table');
    }

    // Insert default data if tables are empty
    const statusCount = await knex('statuses').count('id as count').first();
    if (statusCount.count == 0) {
      await knex('statuses').insert([
        { name: 'Open', color: '#ffffff' },
        { name: 'In Progress', color: '#ffeb3b' },
        { name: 'Completed', color: '#4caf50' },
        { name: 'Cancelled', color: '#9e9e9e' },
        { name: 'Hold', color: '#795548' },
        { name: 'Delayed', color: '#f44336' }
      ]);
      console.log('✅ Inserted default statuses');
    }

    const priorityCount = await knex('priorities').count('id as count').first();
    if (priorityCount.count == 0) {
      await knex('priorities').insert([
        { name: 'Important & Urgent', order: 1, color: '#ff9800', matrix_quadrant: 'IU' },
        { name: 'Important & Not Urgent', order: 2, color: '#ffeb3b', matrix_quadrant: 'IN' },
        { name: 'Not Important & Urgent', order: 3, color: '#ffffff', matrix_quadrant: 'NU' },
        { name: 'Not Important & Not Urgent', order: 4, color: '#ffffff', matrix_quadrant: 'NN' }
      ]);
      console.log('✅ Inserted default priorities');
    }

    const taskTypeCount = await knex('task_types').count('id as count').first();
    if (taskTypeCount.count == 0) {
      await knex('task_types').insert([
        { name: 'Requirement' },
        { name: 'Design' },
        { name: 'Coding' },
        { name: 'Testing' },
        { name: 'Learning' },
        { name: 'Documentation' }
      ]);
      console.log('✅ Inserted default task types');
    }

    console.log('🎉 Tasks schema fix completed successfully!');

  } catch (error) {
    console.error('❌ Error fixing tasks schema:', error);
    throw error;
  } finally {
    await knex.destroy();
  }
}

// Run the fix
fixTasksSchema().catch(console.error);
