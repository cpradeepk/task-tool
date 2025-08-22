/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
export const up = async function(knex) {
  // Add support team columns to tasks table
  await knex.schema.alterTable('tasks', function(table) {
    table.json('support_team').nullable(); // Array of user IDs providing support
    table.integer('warning_count').defaultTo(0);
    table.timestamp('last_warning_date').nullable();
    table.text('task_id_formatted').nullable(); // JSR-YYYYMMDD-XXX format
    table.index(['support_team'], 'idx_tasks_support_team');
    table.index(['warning_count'], 'idx_tasks_warning_count');
    table.index(['task_id_formatted'], 'idx_tasks_formatted_id');
  });

  // Create task_support junction table for better normalization
  await knex.schema.createTable('task_support', function(table) {
    table.increments('id').primary();
    table.integer('task_id').unsigned().references('id').inTable('tasks').onDelete('CASCADE');
    table.string('employee_id', 50).notNullable();
    table.timestamp('added_at').defaultTo(knex.fn.now());
    table.string('added_by', 50).nullable();
    table.text('role').nullable(); // 'support', 'reviewer', 'collaborator'
    table.boolean('is_active').defaultTo(true);
    
    table.index(['task_id'], 'idx_task_support_task_id');
    table.index(['employee_id'], 'idx_task_support_employee_id');
    table.index(['is_active'], 'idx_task_support_active');
    table.unique(['task_id', 'employee_id'], 'unique_task_employee_support');
  });

  // Create task_history table for tracking changes
  await knex.schema.createTable('task_history', function(table) {
    table.increments('id').primary();
    table.integer('task_id').unsigned().references('id').inTable('tasks').onDelete('CASCADE');
    table.string('changed_by', 50).notNullable();
    table.string('change_type', 50).notNullable(); // 'created', 'updated', 'status_changed', 'assigned', 'support_added'
    table.json('old_values').nullable();
    table.json('new_values').nullable();
    table.text('comment').nullable();
    table.timestamp('changed_at').defaultTo(knex.fn.now());
    
    table.index(['task_id'], 'idx_task_history_task_id');
    table.index(['changed_by'], 'idx_task_history_changed_by');
    table.index(['change_type'], 'idx_task_history_change_type');
    table.index(['changed_at'], 'idx_task_history_changed_at');
  });

  // Create task_comments table
  await knex.schema.createTable('task_comments', function(table) {
    table.increments('id').primary();
    table.integer('task_id').unsigned().references('id').inTable('tasks').onDelete('CASCADE');
    table.string('author_id', 50).notNullable();
    table.text('content').notNullable();
    table.json('attachments').nullable(); // Array of file references
    table.boolean('is_internal').defaultTo(false); // Internal comments vs client-visible
    table.timestamp('created_at').defaultTo(knex.fn.now());
    table.timestamp('updated_at').defaultTo(knex.fn.now());
    table.timestamp('deleted_at').nullable();
    
    table.index(['task_id'], 'idx_task_comments_task_id');
    table.index(['author_id'], 'idx_task_comments_author_id');
    table.index(['created_at'], 'idx_task_comments_created_at');
    table.index(['deleted_at'], 'idx_task_comments_deleted_at');
  });

  // Add user warning system columns
  await knex.schema.alterTable('users', function(table) {
    table.integer('warning_count').defaultTo(0);
    table.timestamp('last_warning_date').nullable();
    table.string('manager_id', 50).nullable(); // Reference to manager user ID
    table.date('hire_date').nullable();
    table.text('employee_photo').nullable(); // Base64 or file path for ID cards
    
    table.index(['manager_id'], 'idx_users_manager_id');
    table.index(['warning_count'], 'idx_users_warning_count');
  });

  // Create user_warnings table for detailed tracking
  await knex.schema.createTable('user_warnings', function(table) {
    table.increments('id').primary();
    table.string('employee_id', 50).notNullable();
    table.string('warning_type', 50).notNullable(); // 'overdue_tasks', 'missed_deadline', 'quality_issue'
    table.text('description').nullable();
    table.string('issued_by', 50).nullable();
    table.timestamp('issued_at').defaultTo(knex.fn.now());
    table.boolean('resolved').defaultTo(false);
    table.timestamp('resolved_at').nullable();
    table.string('resolved_by', 50).nullable();
    table.text('resolution_notes').nullable();
    
    table.index(['employee_id'], 'idx_user_warnings_employee_id');
    table.index(['warning_type'], 'idx_user_warnings_type');
    table.index(['issued_at'], 'idx_user_warnings_issued_at');
    table.index(['resolved'], 'idx_user_warnings_resolved');
  });

  // Create task_templates table for reusable task templates
  await knex.schema.createTable('task_templates', function(table) {
    table.increments('id').primary();
    table.string('name', 255).notNullable();
    table.text('description').nullable();
    table.json('template_data').notNullable(); // Task structure as JSON
    table.string('category', 100).nullable();
    table.string('created_by', 50).notNullable();
    table.boolean('is_public').defaultTo(false);
    table.timestamp('created_at').defaultTo(knex.fn.now());
    table.timestamp('updated_at').defaultTo(knex.fn.now());
    table.timestamp('deleted_at').nullable();
    
    table.index(['name'], 'idx_task_templates_name');
    table.index(['category'], 'idx_task_templates_category');
    table.index(['created_by'], 'idx_task_templates_created_by');
    table.index(['is_public'], 'idx_task_templates_public');
    table.index(['deleted_at'], 'idx_task_templates_deleted_at');
  });

  // Update existing tasks with formatted IDs
  const tasks = await knex('tasks').select('id', 'created_at');
  for (const task of tasks) {
    const createdDate = new Date(task.created_at);
    const year = createdDate.getFullYear();
    const month = String(createdDate.getMonth() + 1).padStart(2, '0');
    const day = String(createdDate.getDate()).padStart(2, '0');
    const taskNumber = String(task.id).padStart(3, '0');
    const formattedId = `JSR-${year}${month}${day}-${taskNumber}`;
    
    await knex('tasks')
      .where('id', task.id)
      .update({ task_id_formatted: formattedId });
  }
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
export const down = async function(knex) {
  // Drop new tables
  await knex.schema.dropTableIfExists('task_templates');
  await knex.schema.dropTableIfExists('user_warnings');
  await knex.schema.dropTableIfExists('task_comments');
  await knex.schema.dropTableIfExists('task_history');
  await knex.schema.dropTableIfExists('task_support');

  // Remove columns from tasks table
  await knex.schema.alterTable('tasks', function(table) {
    table.dropColumn('support_team');
    table.dropColumn('warning_count');
    table.dropColumn('last_warning_date');
    table.dropColumn('task_id_formatted');
  });

  // Remove columns from users table
  await knex.schema.alterTable('users', function(table) {
    table.dropColumn('warning_count');
    table.dropColumn('last_warning_date');
    table.dropColumn('manager_id');
    table.dropColumn('hire_date');
    table.dropColumn('employee_photo');
  });
};
