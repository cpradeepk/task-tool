#!/usr/bin/env node

/**
 * Initialize authentication users for the Task Tool application
 * This script creates the users table if it doesn't exist and adds test users
 */

import { knex } from './src/db/index.js';
import bcrypt from 'bcrypt';

async function initializeAuthUsers() {
  try {
    console.log('🔧 Initializing authentication users...');

    // Check if users table exists
    const hasUsersTable = await knex.schema.hasTable('users');
    
    if (!hasUsersTable) {
      console.log('📋 Creating users table...');
      await knex.schema.createTable('users', (table) => {
        table.increments('id').primary();
        table.string('email').unique().notNullable();
        table.string('pin_hash');
        table.timestamp('pin_created_at');
        table.timestamp('pin_last_used');
        table.integer('pin_attempts').defaultTo(0);
        table.timestamp('pin_locked_until');
        table.string('name');
        table.string('role').defaultTo('user');
        table.boolean('is_active').defaultTo(true);
        table.timestamp('created_at').defaultTo(knex.fn.now());
        table.timestamp('updated_at').defaultTo(knex.fn.now());
      });
      console.log('✅ Users table created successfully');
    } else {
      console.log('✅ Users table already exists');
    }

    // Check if test users exist
    const existingUsers = await knex('users').select('email');
    const existingEmails = existingUsers.map(u => u.email);

    // Test users to create
    const testUsers = [
      {
        email: 'test@example.com',
        pin: '1234',
        name: 'Test User',
        role: 'user'
      },
      {
        email: 'admin@example.com', 
        pin: '5678',
        name: 'Admin User',
        role: 'admin'
      },
      {
        email: 'mailrajk@gmail.com',
        pin: '1234',
        name: 'Raj Kumar',
        role: 'user'
      }
    ];

    for (const user of testUsers) {
      if (!existingEmails.includes(user.email)) {
        console.log(`👤 Creating user: ${user.email}`);
        
        const pinHash = await bcrypt.hash(user.pin, 10);
        
        await knex('users').insert({
          email: user.email,
          pin_hash: pinHash,
          pin_created_at: new Date(),
          created_at: new Date(),
          updated_at: new Date()
        });
        
        console.log(`✅ User created: ${user.email} (PIN: ${user.pin})`);
      } else {
        console.log(`⏭️  User already exists: ${user.email}`);
      }
    }

    // Display all users
    console.log('\n📋 Current users in database:');
    const allUsers = await knex('users').select('id', 'email', 'created_at');
    console.table(allUsers);

    console.log('\n🎉 Authentication users initialization completed!');
    console.log('\n📝 Test credentials:');
    console.log('   Email: test@example.com, PIN: 1234');
    console.log('   Email: admin@example.com, PIN: 5678');
    console.log('   Email: mailrajk@gmail.com, PIN: 1234');

  } catch (error) {
    console.error('❌ Error initializing authentication users:', error);
    throw error;
  } finally {
    await knex.destroy();
  }
}

// Run the initialization
initializeAuthUsers()
  .then(() => {
    console.log('✅ Script completed successfully');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Script failed:', error);
    process.exit(1);
  });
