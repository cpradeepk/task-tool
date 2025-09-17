#!/usr/bin/env node

import { knex } from '../src/db/index.js';

async function initChatTables() {
  try {
    console.log('🚀 Initializing chat system tables...');

    // Create channel_members table
    const channelMembersExists = await knex.schema.hasTable('channel_members');
    if (!channelMembersExists) {
      await knex.schema.createTable('channel_members', (table) => {
        table.increments('id').primary();
        table.integer('channel_id').references('id').inTable('chat_channels').onDelete('CASCADE');
        table.integer('user_id').references('id').inTable('users').onDelete('CASCADE');
        table.string('role').defaultTo('member');
        table.timestamp('joined_at').defaultTo(knex.fn.now());
        table.unique(['channel_id', 'user_id']);
      });
      console.log('✅ Created channel_members table');
    } else {
      console.log('ℹ️  channel_members table already exists');
    }

    // Check if chat_channels has is_archived column
    const hasIsArchived = await knex.schema.hasColumn('chat_channels', 'is_archived');
    if (!hasIsArchived) {
      await knex.schema.alterTable('chat_channels', (table) => {
        table.boolean('is_archived').defaultTo(false);
      });
      console.log('✅ Added is_archived column to chat_channels');
    } else {
      console.log('ℹ️  chat_channels.is_archived column already exists');
    }

    // Check if chat_messages has content column (vs message)
    const hasContent = await knex.schema.hasColumn('chat_messages', 'content');
    const hasMessage = await knex.schema.hasColumn('chat_messages', 'message');
    
    if (hasMessage && !hasContent) {
      await knex.schema.alterTable('chat_messages', (table) => {
        table.renameColumn('message', 'content');
      });
      console.log('✅ Renamed message column to content in chat_messages');
    } else if (!hasContent) {
      await knex.schema.alterTable('chat_messages', (table) => {
        table.text('content').notNullable();
      });
      console.log('✅ Added content column to chat_messages');
    } else {
      console.log('ℹ️  chat_messages.content column already exists');
    }

    // Add missing columns to chat_messages
    const hasType = await knex.schema.hasColumn('chat_messages', 'type');
    if (!hasType) {
      await knex.schema.alterTable('chat_messages', (table) => {
        table.string('type').defaultTo('text');
      });
      console.log('✅ Added type column to chat_messages');
    }

    const hasEditedAt = await knex.schema.hasColumn('chat_messages', 'edited_at');
    if (!hasEditedAt) {
      await knex.schema.alterTable('chat_messages', (table) => {
        table.timestamp('edited_at');
      });
      console.log('✅ Added edited_at column to chat_messages');
    }

    // Ensure default channels exist
    const channelCount = await knex('chat_channels').count('* as count').first();
    if (parseInt(channelCount.count) === 0) {
      await knex('chat_channels').insert([
        {
          name: 'General',
          description: 'General discussion for all team members',
          type: 'public',
          is_archived: false,
        },
        {
          name: 'Development',
          description: 'Development team discussions and updates',
          type: 'public',
          is_archived: false,
        },
        {
          name: 'Random',
          description: 'Random conversations and fun discussions',
          type: 'public',
          is_archived: false,
        },
      ]);
      console.log('✅ Inserted default chat channels');
    } else {
      console.log('ℹ️  Chat channels already exist');
    }

    console.log('🎉 Chat system tables initialized successfully!');
    
  } catch (error) {
    console.error('❌ Error initializing chat tables:', error);
    process.exit(1);
  } finally {
    await knex.destroy();
  }
}

// Run the initialization
initChatTables();
