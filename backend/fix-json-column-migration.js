#!/usr/bin/env node

/**
 * Fix JSON Column Migration
 * Converts existing JSON column to JSONB and creates proper index
 */

import 'dotenv/config';
import { knex } from './src/db/index.js';

const log = (message) => console.log(`📋 ${message}`);
const success = (message) => console.log(`✅ ${message}`);
const warn = (message) => console.log(`⚠️  ${message}`);
const error = (message) => console.log(`❌ ${message}`);

async function fixJsonColumn() {
  try {
    log('Starting JSON column fix...');
    
    // Check if support_team column exists and its type
    const columnInfo = await knex.raw(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'tasks' AND column_name = 'support_team'
    `);
    
    if (columnInfo.rows.length === 0) {
      warn('support_team column does not exist, skipping fix');
      return;
    }
    
    const currentType = columnInfo.rows[0].data_type;
    log(`Current support_team column type: ${currentType}`);
    
    if (currentType === 'json') {
      log('Converting JSON column to JSONB...');
      
      // First, drop the problematic index if it exists
      try {
        await knex.raw('DROP INDEX IF EXISTS idx_tasks_support_team');
        success('Dropped existing index (if any)');
      } catch (err) {
        warn(`Could not drop index: ${err.message}`);
      }
      
      // Convert JSON to JSONB
      await knex.raw('ALTER TABLE tasks ALTER COLUMN support_team TYPE JSONB USING support_team::JSONB');
      success('Converted support_team column from JSON to JSONB');
      
      // Create the proper JSONB index
      await knex.raw('CREATE INDEX idx_tasks_support_team ON tasks USING GIN (support_team jsonb_ops)');
      success('Created JSONB GIN index');
      
    } else if (currentType === 'jsonb') {
      log('Column is already JSONB, checking index...');
      
      // Check if index exists
      const indexInfo = await knex.raw(`
        SELECT indexname 
        FROM pg_indexes 
        WHERE tablename = 'tasks' AND indexname = 'idx_tasks_support_team'
      `);
      
      if (indexInfo.rows.length === 0) {
        log('Creating missing JSONB index...');
        await knex.raw('CREATE INDEX idx_tasks_support_team ON tasks USING GIN (support_team jsonb_ops)');
        success('Created JSONB GIN index');
      } else {
        success('JSONB index already exists');
      }
    } else {
      warn(`Unexpected column type: ${currentType}`);
    }
    
    success('JSON column fix completed successfully!');
    
  } catch (err) {
    error(`JSON column fix failed: ${err.message}`);
    console.error('Stack trace:', err);
    throw err;
  }
}

async function main() {
  try {
    console.log('🔧 JSON Column Fix Utility');
    console.log('==============================');
    
    // Test database connection
    log('Testing database connection...');
    await knex.raw('SELECT 1');
    success('Database connection successful');
    
    await fixJsonColumn();
    
    console.log('\n🎉 JSON column fix completed successfully!');
    process.exit(0);
    
  } catch (err) {
    error(`Fix failed: ${err.message}`);
    console.error('Full error:', err);
    process.exit(1);
  } finally {
    await knex.destroy();
  }
}

main();
