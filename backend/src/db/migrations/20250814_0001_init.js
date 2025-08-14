/** Initial schema: users, roles, user_roles */
export async function up(knex) {
  await knex.schema.createTable('users', (t) => {
    t.increments('id').primary();
    t.string('email').notNullable().unique();
    t.string('google_sub').unique();
    t.boolean('active').notNullable().defaultTo(true);
    t.timestamp('created_at').defaultTo(knex.fn.now());
  });

  await knex.schema.createTable('roles', (t) => {
    t.increments('id').primary();
    t.string('name').notNullable().unique();
  });

  await knex.schema.createTable('user_roles', (t) => {
    t.increments('id').primary();
    t.integer('user_id').references('id').inTable('users').onDelete('CASCADE');
    t.integer('role_id').references('id').inTable('roles').onDelete('CASCADE');
    t.unique(['user_id', 'role_id']);
  });
}

export async function down(knex) {
  await knex.schema.dropTableIfExists('user_roles');
  await knex.schema.dropTableIfExists('roles');
  await knex.schema.dropTableIfExists('users');
}

