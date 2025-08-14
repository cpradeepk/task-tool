export async function up(knex) {
  await knex.schema.createTable('task_dependencies', (t) => {
    t.increments('id').primary();
    t.integer('task_id').references('id').inTable('tasks').onDelete('CASCADE');
    t.integer('depends_on_task_id').references('id').inTable('tasks').onDelete('CASCADE');
    t.string('type').notNullable().defaultTo('PRE'); // PRE or POST
    t.unique(['task_id', 'depends_on_task_id', 'type']);
  });

  await knex.schema.createTable('pert_estimates', (t) => {
    t.increments('id').primary();
    t.integer('task_id').references('id').inTable('tasks').onDelete('CASCADE');
    t.integer('optimistic').notNullable().defaultTo(1);
    t.integer('most_likely').notNullable().defaultTo(1);
    t.integer('pessimistic').notNullable().defaultTo(1);
    t.unique(['task_id']);
  });

  await knex.schema.createTable('threads', (t) => {
    t.increments('id').primary();
    t.string('scope').notNullable(); // PROJECT | MODULE
    t.integer('scope_id').notNullable();
    t.unique(['scope','scope_id']);
  });

  await knex.schema.createTable('messages', (t) => {
    t.increments('id').primary();
    t.integer('thread_id').references('id').inTable('threads').onDelete('CASCADE');
    t.integer('user_id').references('id').inTable('users').onDelete('SET NULL');
    t.string('kind').notNullable().defaultTo('text'); // text, voice, image, video, link, doc
    t.text('body');
    t.timestamp('created_at').defaultTo(knex.fn.now());
  });

  await knex.schema.createTable('attachments', (t) => {
    t.increments('id').primary();
    t.integer('message_id').references('id').inTable('messages').onDelete('CASCADE');
    t.string('url');
    t.string('type');
    t.string('filename');
    t.integer('size');
  });
}

export async function down(knex) {
  await knex.schema.dropTableIfExists('attachments');
  await knex.schema.dropTableIfExists('messages');
  await knex.schema.dropTableIfExists('threads');
  await knex.schema.dropTableIfExists('pert_estimates');
  await knex.schema.dropTableIfExists('task_dependencies');
}

