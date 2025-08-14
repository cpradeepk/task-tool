export async function up(knex) {
  await knex.schema.createTable('statuses', (t) => {
    t.increments('id').primary();
    t.string('name').notNullable().unique();
    t.string('color').notNullable();
  });
  await knex.schema.createTable('priorities', (t) => {
    t.increments('id').primary();
    t.string('name').notNullable();
    t.integer('order').notNullable();
    t.string('color').notNullable();
    t.string('matrix_quadrant').notNullable();
  });
  await knex.schema.createTable('task_types', (t) => {
    t.increments('id').primary();
    t.string('name').notNullable().unique();
  });
  await knex.schema.createTable('project_types', (t) => {
    t.increments('id').primary();
    t.string('name').notNullable().unique();
  });
}

export async function down(knex) {
  await knex.schema.dropTableIfExists('project_types');
  await knex.schema.dropTableIfExists('task_types');
  await knex.schema.dropTableIfExists('priorities');
  await knex.schema.dropTableIfExists('statuses');
}

