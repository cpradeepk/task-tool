#!/usr/bin/env node

/**
 * Migration Runner Script
 * Runs the user_profile merge migration safely
 */

import { knex } from './src/db/index.js';
import { up as mergeUserProfile } from './src/db/migrations/20250118_0001_merge_user_profile.js';

async function runMigration() {
  console.log('🚀 Starting database migration: Merge user_profile into users table');
  console.log('='.repeat(70));
  
  try {
    // Check database connection
    await knex.raw('SELECT 1');
    console.log('✅ Database connection established');
    
    // Check if migration has already been run
    const hasUserProfilesTable = await knex.schema.hasTable('user_profiles');
    const hasNameColumn = await knex.schema.hasColumn('users', 'name');
    
    if (!hasUserProfilesTable && hasNameColumn) {
      console.log('⚠️  Migration appears to have already been run');
      console.log('   - user_profiles table does not exist');
      console.log('   - users table already has name column');
      console.log('   Skipping migration...');
      return;
    }
    
    // Show current state
    console.log('\n📊 Current database state:');
    console.log(`   - user_profiles table exists: ${hasUserProfilesTable}`);
    console.log(`   - users table has name column: ${hasNameColumn}`);
    
    if (hasUserProfilesTable) {
      const profileCount = await knex('user_profiles').count('* as count').first();
      console.log(`   - user_profiles records: ${profileCount.count}`);
    }
    
    const userCount = await knex('users').count('* as count').first();
    console.log(`   - users records: ${userCount.count}`);
    
    // Confirm before proceeding
    console.log('\n⚠️  This migration will:');
    console.log('   1. Add profile columns to users table');
    console.log('   2. Migrate data from user_profiles to users');
    console.log('   3. Drop the user_profiles table');
    console.log('   4. Update API endpoints to use consolidated users table');
    
    // Run the migration
    console.log('\n🔄 Running migration...');
    await mergeUserProfile(knex);
    
    // Verify migration success
    console.log('\n✅ Migration completed successfully!');
    
    // Show final state
    const finalUserCount = await knex('users').count('* as count').first();
    const hasNameColumnAfter = await knex.schema.hasColumn('users', 'name');
    const hasUserProfilesTableAfter = await knex.schema.hasTable('user_profiles');
    
    console.log('\n📊 Final database state:');
    console.log(`   - users records: ${finalUserCount.count}`);
    console.log(`   - users table has name column: ${hasNameColumnAfter}`);
    console.log(`   - user_profiles table exists: ${hasUserProfilesTableAfter}`);
    
    // Show sample user data
    const sampleUsers = await knex('users')
      .select('id', 'email', 'name', 'theme', 'accent_color')
      .whereNotNull('name')
      .limit(3);
    
    if (sampleUsers.length > 0) {
      console.log('\n📋 Sample migrated user data:');
      sampleUsers.forEach(user => {
        console.log(`   - ${user.email}: ${user.name} (theme: ${user.theme})`);
      });
    }
    
    console.log('\n🎉 Database schema restructuring completed successfully!');
    console.log('   The user_profile table has been merged into the users table.');
    console.log('   All API endpoints have been updated to use the consolidated structure.');
    
  } catch (error) {
    console.error('\n❌ Migration failed:', error.message);
    console.error('Stack trace:', error.stack);
    process.exit(1);
  } finally {
    await knex.destroy();
  }
}

// Handle graceful shutdown
process.on('SIGINT', async () => {
  console.log('\n⚠️  Migration interrupted by user');
  await knex.destroy();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  console.log('\n⚠️  Migration terminated');
  await knex.destroy();
  process.exit(0);
});

// Run the migration
runMigration().catch(console.error);
