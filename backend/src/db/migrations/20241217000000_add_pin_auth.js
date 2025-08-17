export function up(knex) {
  return knex.schema.alterTable('users', (table) => {
    table.string('pin_hash', 255).nullable();
    table.timestamp('pin_created_at').nullable();
    table.timestamp('pin_last_used').nullable();
    table.integer('pin_attempts').defaultTo(0);
    table.timestamp('pin_locked_until').nullable();
  });
}

export function down(knex) {
  return knex.schema.alterTable('users', (table) => {
    table.dropColumn('pin_hash');
    table.dropColumn('pin_created_at');
    table.dropColumn('pin_last_used');
    table.dropColumn('pin_attempts');
    table.dropColumn('pin_locked_until');
  });
}
