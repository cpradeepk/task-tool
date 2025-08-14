export async function up(knex) {
  await knex.schema.createTable('user_profiles', (t) => {
    t.integer('user_id').primary().references('id').inTable('users').onDelete('CASCADE');
    t.string('name');
    t.string('short_name');
    t.string('phone');
    t.string('telegram');
    t.string('whatsapp');
    t.string('theme').defaultTo('light');
    t.string('accent_color').defaultTo('#64b5f6');
    t.string('font');
    t.string('avatar_url');
    t.timestamp('updated_at').defaultTo(knex.fn.now());
  });
}

export async function down(knex) {
  await knex.schema.dropTableIfExists('user_profiles');
}

