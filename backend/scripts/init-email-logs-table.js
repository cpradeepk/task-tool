#!/usr/bin/env node

import { knex } from '../src/db/index.js';

async function initEmailLogsTable() {
  try {
    console.log('🚀 Initializing email logs table...');

    // Create email_logs table
    const emailLogsExists = await knex.schema.hasTable('email_logs');
    if (!emailLogsExists) {
      await knex.schema.createTable('email_logs', (table) => {
        table.increments('id').primary();
        table.integer('user_id').references('id').inTable('users').onDelete('CASCADE');
        table.string('recipient').notNullable();
        table.string('subject').notNullable();
        table.string('template');
        table.string('status').notNullable(); // sent, failed, pending
        table.string('message_id');
        table.text('error_message');
        table.timestamps(true, true);
      });
      console.log('✅ Created email_logs table');
    } else {
      console.log('ℹ️  email_logs table already exists');
    }

    console.log('🎉 Email logs table initialized successfully!');
    
  } catch (error) {
    console.error('❌ Error initializing email logs table:', error);
    process.exit(1);
  } finally {
    await knex.destroy();
  }
}

// Run the initialization
initEmailLogsTable();
