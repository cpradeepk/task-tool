export async function up(knex) {
  // Extend tasks with foreign keys to master tables
  await knex.schema.alterTable('tasks', (t) => {
    t.integer('status_id').references('id').inTable('statuses');
    t.integer('priority_id').references('id').inTable('priorities');
    t.integer('task_type_id').references('id').inTable('task_types');
  });

  // Task assignments
  await knex.schema.createTable('task_assignments', (t) => {
    t.increments('id').primary();
    t.integer('task_id').references('id').inTable('tasks').onDelete('CASCADE');
    t.integer('user_id').references('id').inTable('users').onDelete('CASCADE');
    t.boolean('is_owner').notNullable().defaultTo(false);
    t.string('role'); // optional role label (support, reviewer, etc.)
    t.unique(['task_id', 'user_id']);
  });

  // Time entries
  await knex.schema.createTable('time_entries', (t) => {
    t.increments('id').primary();
    t.integer('task_id').references('id').inTable('tasks').onDelete('CASCADE');
    t.integer('user_id').references('id').inTable('users').onDelete('CASCADE');
    t.timestamp('start');
    t.timestamp('end');
    t.integer('minutes');
    t.text('notes');
    t.timestamp('created_at').defaultTo(knex.fn.now());
  });
}

export async function down(knex) {
  await knex.schema.dropTableIfExists('time_entries');
  await knex.schema.dropTableIfExists('task_assignments');
  await knex.schema.alterTable('tasks', (t) => {
    t.dropColumns('status_id', 'priority_id', 'task_type_id');
  });
}

