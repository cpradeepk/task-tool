#!/usr/bin/env node

import { knex } from '../src/db/index.js';

async function initFileUploadsTable() {
  try {
    console.log('🚀 Initializing file uploads table...');

    // Create file_uploads table
    const fileUploadsExists = await knex.schema.hasTable('file_uploads');
    if (!fileUploadsExists) {
      await knex.schema.createTable('file_uploads', (table) => {
        table.increments('id').primary();
        table.integer('user_id').references('id').inTable('users').onDelete('CASCADE');
        table.string('original_name').notNullable();
        table.string('filename').notNullable();
        table.string('file_path').notNullable();
        table.string('file_url').notNullable();
        table.string('mime_type');
        table.integer('file_size');
        table.string('storage_type').defaultTo('local');
        table.string('category').defaultTo('general');
        table.text('description');
        table.integer('task_id').references('id').inTable('tasks').onDelete('SET NULL');
        table.integer('project_id').references('id').inTable('projects').onDelete('SET NULL');
        table.timestamps(true, true);
      });
      console.log('✅ Created file_uploads table');
    } else {
      console.log('ℹ️  file_uploads table already exists');
    }

    console.log('🎉 File uploads table initialized successfully!');
    
  } catch (error) {
    console.error('❌ Error initializing file uploads table:', error);
    process.exit(1);
  } finally {
    await knex.destroy();
  }
}

// Run the initialization
initFileUploadsTable();
