export async function up(knex) {
  await knex.schema.createTable('projects', (t) => {
    t.increments('id').primary();
    t.string('name').notNullable();
    t.date('start_date');
    t.timestamp('created_at').defaultTo(knex.fn.now());
  });

  await knex.schema.createTable('modules', (t) => {
    t.increments('id').primary();
    t.integer('project_id').references('id').inTable('projects').onDelete('CASCADE');
    t.string('name').notNullable();
  });

  await knex.schema.createTable('tasks', (t) => {
    t.increments('id').primary();
    t.integer('project_id').references('id').inTable('projects').onDelete('CASCADE');
    t.integer('module_id').references('id').inTable('modules').onDelete('SET NULL');
    t.string('title').notNullable();
    t.text('description');
    t.string('status').notNullable().defaultTo('Open');
    t.integer('priority').notNullable().defaultTo(3);
    t.date('start_date');
    t.date('planned_end_date');
    t.date('end_date');
    t.timestamp('created_at').defaultTo(knex.fn.now());
  });

  await knex.schema.createTable('subtasks', (t) => {
    t.increments('id').primary();
    t.integer('task_id').references('id').inTable('tasks').onDelete('CASCADE');
    t.string('title').notNullable();
    t.string('status').notNullable().defaultTo('Open');
  });
}

export async function down(knex) {
  await knex.schema.dropTableIfExists('subtasks');
  await knex.schema.dropTableIfExists('tasks');
  await knex.schema.dropTableIfExists('modules');
  await knex.schema.dropTableIfExists('projects');
}

