#!/usr/bin/env node

/**
 * Migration Runner for Margadarshi Task Management System
 * Runs the Phase 3 & 4 database migrations
 */

import { knex } from './src/db/index.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function runMigration() {
  console.log('🚀 Starting Margadarshi Phase 3 & 4 database migration...');
  console.log('='.repeat(70));
  
  try {
    // Test database connection
    console.log('📡 Testing database connection...');
    await knex.raw('SELECT 1');
    console.log('✅ Database connection successful');
    
    // Check if migration has already been run
    console.log('🔍 Checking migration status...');
    
    const tableExists = await knex.schema.hasTable('task_support');
    if (tableExists) {
      console.log('⚠️  Migration appears to have already been run');
      console.log('   task_support table already exists');
      
      const proceed = process.argv.includes('--force');
      if (!proceed) {
        console.log('   Use --force flag to run anyway');
        process.exit(0);
      }
      console.log('   Proceeding with --force flag...');
    }
    
    // Run the migration using the existing migration file
    console.log('📦 Running Knex migrations...');
    
    try {
      const [batchNo, log] = await knex.migrate.latest({
        directory: './src/db/migrations'
      });
      
      if (log.length === 0) {
        console.log('✅ No new migrations to run');
      } else {
        console.log(`✅ Batch ${batchNo} run: ${log.length} migrations`);
        log.forEach(migration => {
          console.log(`   - ${migration}`);
        });
      }
    } catch (migrateError) {
      console.log('⚠️  Knex migration failed, trying direct SQL execution...');
      console.log('Error:', migrateError.message);
      
      // Fallback to direct SQL execution
      await runDirectSQL();
    }
    
    // Update existing tasks with formatted IDs
    console.log('🔄 Updating existing tasks with formatted IDs...');
    await updateTaskIds();
    
    // Insert sample data
    console.log('📝 Inserting sample task templates...');
    await insertSampleData();
    
    // Verify migration
    console.log('🔍 Verifying migration...');
    await verifyMigration();
    
    console.log('🎉 Migration completed successfully!');
    console.log('='.repeat(70));
    console.log('📋 Summary:');
    console.log('   ✅ Task support team features enabled');
    console.log('   ✅ Task history and comments system active');
    console.log('   ✅ User warning system implemented');
    console.log('   ✅ Leave and WFH management ready');
    console.log('   ✅ Task templates available');
    console.log('   ✅ Employee ID card system ready');
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
    console.error('Stack trace:', error.stack);
    process.exit(1);
  } finally {
    await knex.destroy();
  }
}

async function runDirectSQL() {
  console.log('📄 Reading SQL migration file...');
  
  const sqlFile = path.join(__dirname, 'database_migration.sql');
  if (!fs.existsSync(sqlFile)) {
    throw new Error('SQL migration file not found');
  }
  
  const sql = fs.readFileSync(sqlFile, 'utf8');
  
  // Split SQL into individual statements, handling multi-line statements
  const statements = [];
  let currentStatement = '';
  let inFunction = false;
  
  const lines = sql.split('\n');
  for (const line of lines) {
    const trimmedLine = line.trim();
    
    // Skip comments and empty lines
    if (trimmedLine.startsWith('--') || trimmedLine === '') {
      continue;
    }
    
    // Handle function definitions
    if (trimmedLine.includes('CREATE OR REPLACE FUNCTION') || trimmedLine.includes('DO $$')) {
      inFunction = true;
    }
    
    currentStatement += line + '\n';
    
    // End of statement detection
    if (trimmedLine.endsWith(';')) {
      if (inFunction && (trimmedLine.includes('$$;') || trimmedLine.includes('END $$;'))) {
        inFunction = false;
        statements.push(currentStatement.trim());
        currentStatement = '';
      } else if (!inFunction) {
        statements.push(currentStatement.trim());
        currentStatement = '';
      }
    }
  }
  
  // Add any remaining statement
  if (currentStatement.trim()) {
    statements.push(currentStatement.trim());
  }
  
  console.log(`📋 Executing ${statements.length} SQL statements...`);
  
  for (let i = 0; i < statements.length; i++) {
    const statement = statements[i];
    if (statement.toLowerCase().includes('commit')) continue;
    
    try {
      await knex.raw(statement);
      console.log(`   ✅ Statement ${i + 1}/${statements.length} executed`);
    } catch (error) {
      if (error.message.includes('already exists') || 
          error.message.includes('duplicate key') ||
          error.message.includes('relation') && error.message.includes('already exists')) {
        console.log(`   ⚠️  Statement ${i + 1}/${statements.length} skipped (already exists)`);
      } else {
        console.error(`   ❌ Statement ${i + 1}/${statements.length} failed:`, error.message);
        throw error;
      }
    }
  }
}

async function updateTaskIds() {
  try {
    // Check if tasks need ID updates
    const tasksWithoutIds = await knex('tasks')
      .whereNull('task_id_formatted')
      .count('* as count');
    
    const count = parseInt(tasksWithoutIds[0].count);
    if (count === 0) {
      console.log('   ✅ All tasks already have formatted IDs');
      return;
    }
    
    console.log(`   📝 Updating ${count} tasks with formatted IDs...`);
    
    // Get tasks without formatted IDs
    const tasks = await knex('tasks')
      .select('id', 'created_at')
      .whereNull('task_id_formatted')
      .orderBy('created_at')
      .orderBy('id');
    
    const dateCounters = {};
    
    for (const task of tasks) {
      const createdDate = new Date(task.created_at);
      const year = createdDate.getFullYear();
      const month = String(createdDate.getMonth() + 1).padStart(2, '0');
      const day = String(createdDate.getDate()).padStart(2, '0');
      const dateStr = `${year}${month}${day}`;
      
      // Initialize or increment counter for this date
      if (!dateCounters[dateStr]) {
        // Get existing count for this date
        const existing = await knex('tasks')
          .where('task_id_formatted', 'like', `JSR-${dateStr}-%`)
          .count('* as count');
        dateCounters[dateStr] = parseInt(existing[0].count);
      }
      
      dateCounters[dateStr]++;
      const formattedId = `JSR-${dateStr}-${String(dateCounters[dateStr]).padStart(3, '0')}`;
      
      await knex('tasks')
        .where('id', task.id)
        .update({ task_id_formatted: formattedId });
    }
    
    console.log('   ✅ Task IDs updated successfully');
  } catch (error) {
    console.error('   ❌ Failed to update task IDs:', error.message);
    throw error;
  }
}

async function insertSampleData() {
  try {
    // Check if sample templates already exist
    const existingTemplates = await knex('task_templates')
      .where('created_by', 'system')
      .count('* as count');
    
    if (parseInt(existingTemplates[0].count) > 0) {
      console.log('   ✅ Sample templates already exist');
      return;
    }
    
    const sampleTemplates = [
      {
        name: 'Bug Fix Template',
        description: 'Standard template for bug fixing tasks',
        template_data: JSON.stringify({
          title: 'Fix: [Bug Description]',
          description: '## Bug Description\n\n## Steps to Reproduce\n\n## Expected Behavior\n\n## Actual Behavior\n\n## Solution',
          priority: 'High',
          status: 'Yet to Start'
        }),
        category: 'Development',
        created_by: 'system',
        is_public: true
      },
      {
        name: 'Feature Development',
        description: 'Template for new feature development',
        template_data: JSON.stringify({
          title: 'Feature: [Feature Name]',
          description: '## Feature Requirements\n\n## Acceptance Criteria\n\n## Technical Notes\n\n## Testing Requirements',
          priority: 'Medium',
          status: 'Yet to Start'
        }),
        category: 'Development',
        created_by: 'system',
        is_public: true
      },
      {
        name: 'Code Review',
        description: 'Template for code review tasks',
        template_data: JSON.stringify({
          title: 'Review: [Component/Feature]',
          description: '## Review Checklist\n- [ ] Code quality\n- [ ] Performance\n- [ ] Security\n- [ ] Documentation\n- [ ] Tests',
          priority: 'Medium',
          status: 'Yet to Start'
        }),
        category: 'Quality Assurance',
        created_by: 'system',
        is_public: true
      }
    ];
    
    await knex('task_templates').insert(sampleTemplates);
    console.log('   ✅ Sample templates inserted');
  } catch (error) {
    console.error('   ❌ Failed to insert sample data:', error.message);
    // Don't throw - this is not critical
  }
}

async function verifyMigration() {
  const tables = [
    'task_support',
    'task_history', 
    'task_comments',
    'user_warnings',
    'task_templates',
    'leaves',
    'wfh_requests'
  ];
  
  for (const table of tables) {
    const exists = await knex.schema.hasTable(table);
    if (exists) {
      const count = await knex(table).count('* as count');
      console.log(`   ✅ ${table}: exists (${count[0].count} records)`);
    } else {
      console.log(`   ❌ ${table}: missing`);
      throw new Error(`Table ${table} was not created`);
    }
  }
  
  // Check new columns
  const taskColumns = await knex('tasks').columnInfo();
  const requiredColumns = ['support_team', 'warning_count', 'task_id_formatted'];
  
  for (const column of requiredColumns) {
    if (taskColumns[column]) {
      console.log(`   ✅ tasks.${column}: exists`);
    } else {
      console.log(`   ❌ tasks.${column}: missing`);
      throw new Error(`Column tasks.${column} was not created`);
    }
  }
}

// Run the migration
if (import.meta.url === `file://${process.argv[1]}`) {
  runMigration();
}

export { runMigration };
