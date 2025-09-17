#!/usr/bin/env node

import { knex } from '../src/db/index.js';

async function fixNotificationsTable() {
  try {
    console.log('🚀 Fixing notifications table schema...');

    // Check if notifications table exists
    const tableExists = await knex.schema.hasTable('notifications');
    if (!tableExists) {
      console.log('Creating notifications table...');
      await knex.schema.createTable('notifications', (table) => {
        table.increments('id').primary();
        table.integer('user_id').references('id').inTable('users').onDelete('CASCADE');
        table.string('title').notNullable();
        table.text('message');
        table.string('type');
        table.json('data');
        table.boolean('read').defaultTo(false);
        table.timestamp('read_at');
        table.timestamps(true, true);
      });
      console.log('✅ Created notifications table');
      return;
    }

    // Check and fix column names
    const hasIsRead = await knex.schema.hasColumn('notifications', 'is_read');
    const hasRead = await knex.schema.hasColumn('notifications', 'read');
    
    if (hasIsRead && !hasRead) {
      await knex.schema.alterTable('notifications', (table) => {
        table.renameColumn('is_read', 'read');
      });
      console.log('✅ Renamed is_read column to read');
    }

    // Add missing columns
    const hasData = await knex.schema.hasColumn('notifications', 'data');
    if (!hasData) {
      await knex.schema.alterTable('notifications', (table) => {
        table.json('data');
      });
      console.log('✅ Added data column');
    }

    const hasReadAt = await knex.schema.hasColumn('notifications', 'read_at');
    if (!hasReadAt) {
      await knex.schema.alterTable('notifications', (table) => {
        table.timestamp('read_at');
      });
      console.log('✅ Added read_at column');
    }

    console.log('🎉 Notifications table schema fixed successfully!');
    
  } catch (error) {
    console.error('❌ Error fixing notifications table:', error);
    process.exit(1);
  } finally {
    await knex.destroy();
  }
}

// Run the fix
fixNotificationsTable();
