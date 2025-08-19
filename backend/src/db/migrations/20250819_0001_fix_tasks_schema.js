export async function up(knex) {
  console.log('Starting tasks schema fix migration...');

  // Check if tasks table exists
  const tasksExists = await knex.schema.hasTable('tasks');
  if (!tasksExists) {
    console.log('Tasks table does not exist, skipping migration');
    return;
  }

  // Add missing columns to tasks table
  await knex.schema.alterTable('tasks', (table) => {
    // Add project_id if it doesn't exist
    if (!await knex.schema.hasColumn('tasks', 'project_id')) {
      table.integer('project_id').references('id').inTable('projects').onDelete('CASCADE');
      console.log('Added project_id column to tasks table');
    }

    // Add task_id string column if it doesn't exist
    if (!await knex.schema.hasColumn('tasks', 'task_id')) {
      table.string('task_id').unique();
      console.log('Added task_id column to tasks table');
    }

    // Add assigned_to if it doesn't exist
    if (!await knex.schema.hasColumn('tasks', 'assigned_to')) {
      table.integer('assigned_to').references('id').inTable('users');
      console.log('Added assigned_to column to tasks table');
    }

    // Add created_by if it doesn't exist
    if (!await knex.schema.hasColumn('tasks', 'created_by')) {
      table.integer('created_by').references('id').inTable('users');
      console.log('Added created_by column to tasks table');
    }

    // Add updated_at if it doesn't exist
    if (!await knex.schema.hasColumn('tasks', 'updated_at')) {
      table.timestamp('updated_at').defaultTo(knex.fn.now());
      console.log('Added updated_at column to tasks table');
    }

    // Add estimated_hours if it doesn't exist
    if (!await knex.schema.hasColumn('tasks', 'estimated_hours')) {
      table.integer('estimated_hours');
      console.log('Added estimated_hours column to tasks table');
    }

    // Add actual_hours if it doesn't exist
    if (!await knex.schema.hasColumn('tasks', 'actual_hours')) {
      table.integer('actual_hours');
      console.log('Added actual_hours column to tasks table');
    }

    // Add due_date if it doesn't exist
    if (!await knex.schema.hasColumn('tasks', 'due_date')) {
      table.date('due_date');
      console.log('Added due_date column to tasks table');
    }

    // Add completed_at if it doesn't exist
    if (!await knex.schema.hasColumn('tasks', 'completed_at')) {
      table.timestamp('completed_at');
      console.log('Added completed_at column to tasks table');
    }
  });

  // Update existing tasks to have project_id based on their module
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

  console.log(`Updated ${tasksWithoutProjectId.length} tasks with project_id`);

  console.log('Tasks schema fix migration completed');
}

export async function down(knex) {
  // This migration is designed to be safe and not reversible
  // as it only adds missing columns that should exist
  console.log('Down migration not implemented for safety');
}
