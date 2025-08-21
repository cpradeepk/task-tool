#!/usr/bin/env node

/**
 * Cleanup Script for Soft Deleted Records
 * This script permanently deletes records that have been soft deleted for more than specified days
 * Usage: node src/scripts/cleanup-soft-deleted.js [--days=30] [--dry-run] [--table=tablename]
 */

import { knex } from '../db/index.js';
import { permanentlyDeleteOldRecords, getSoftDeleteStats } from '../utils/softDelete.js';

// Parse command line arguments
const args = process.argv.slice(2);
const daysOld = parseInt(args.find(arg => arg.startsWith('--days='))?.split('=')[1] || '30');
const isDryRun = args.includes('--dry-run');
const specificTable = args.find(arg => arg.startsWith('--table='))?.split('=')[1];

// Tables that support soft delete (excluding chats and notes)
const SOFT_DELETE_TABLES = [
  'users',
  'projects',
  'modules',
  'tasks',
  'subtasks',
  'task_dependencies',
  'pert_estimates',
  'attachments',
  'user_profiles',
  'user_roles',
  'roles'
];

async function main() {
  console.log('🧹 Soft Delete Cleanup Script');
  console.log('==============================');
  console.log(`📅 Cleaning records older than ${daysOld} days`);
  console.log(`🔍 Mode: ${isDryRun ? 'DRY RUN (no changes will be made)' : 'LIVE (records will be permanently deleted)'}`);
  
  if (specificTable) {
    console.log(`🎯 Target table: ${specificTable}`);
  }
  
  console.log('');

  try {
    const tablesToProcess = specificTable ? [specificTable] : SOFT_DELETE_TABLES;
    let totalDeleted = 0;

    for (const tableName of tablesToProcess) {
      console.log(`\n📊 Processing table: ${tableName}`);
      console.log('─'.repeat(50));

      // Check if table exists
      const tableExists = await knex.schema.hasTable(tableName);
      if (!tableExists) {
        console.log(`⚠️  Table ${tableName} does not exist, skipping...`);
        continue;
      }

      // Check if table has soft delete columns
      const hasIsDeletedColumn = await knex.schema.hasColumn(tableName, 'is_deleted');
      const hasDeletedAtColumn = await knex.schema.hasColumn(tableName, 'deleted_at');

      if (!hasIsDeletedColumn || !hasDeletedAtColumn) {
        console.log(`⚠️  Table ${tableName} does not have soft delete columns, skipping...`);
        continue;
      }

      // Get statistics before cleanup
      const statsBefore = await getSoftDeleteStats(tableName);
      console.log(`📈 Current stats: ${statsBefore.total} total, ${statsBefore.active} active, ${statsBefore.deleted} soft deleted`);

      if (statsBefore.deleted === 0) {
        console.log(`✅ No soft deleted records found in ${tableName}`);
        continue;
      }

      // Show records that would be deleted
      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - daysOld);

      const recordsToDelete = await knex(tableName)
        .where('is_deleted', true)
        .where('deleted_at', '<', cutoffDate)
        .select('id', 'deleted_at', 'deleted_by');

      if (recordsToDelete.length === 0) {
        console.log(`✅ No records older than ${daysOld} days found in ${tableName}`);
        continue;
      }

      console.log(`🗑️  Found ${recordsToDelete.length} records to permanently delete:`);
      recordsToDelete.forEach(record => {
        const deletedDate = new Date(record.deleted_at).toLocaleDateString();
        console.log(`   - ID ${record.id} (deleted on ${deletedDate} by user ${record.deleted_by || 'unknown'})`);
      });

      if (!isDryRun) {
        // Perform permanent deletion
        const deletedCount = await permanentlyDeleteOldRecords(tableName, daysOld);
        totalDeleted += deletedCount;
        console.log(`✅ Permanently deleted ${deletedCount} records from ${tableName}`);

        // Get statistics after cleanup
        const statsAfter = await getSoftDeleteStats(tableName);
        console.log(`📉 Updated stats: ${statsAfter.total} total, ${statsAfter.active} active, ${statsAfter.deleted} soft deleted`);
      } else {
        console.log(`🔍 DRY RUN: Would permanently delete ${recordsToDelete.length} records`);
      }
    }

    console.log('\n' + '='.repeat(50));
    if (!isDryRun) {
      console.log(`🎉 Cleanup completed! Permanently deleted ${totalDeleted} records total.`);
    } else {
      console.log(`🔍 DRY RUN completed! No changes were made.`);
    }

    // Show summary statistics
    console.log('\n📊 Final Summary:');
    console.log('─'.repeat(30));
    
    for (const tableName of tablesToProcess) {
      const tableExists = await knex.schema.hasTable(tableName);
      if (!tableExists) continue;

      const hasColumns = await knex.schema.hasColumn(tableName, 'is_deleted');
      if (!hasColumns) continue;

      const stats = await getSoftDeleteStats(tableName);
      if (stats.total > 0) {
        console.log(`${tableName.padEnd(20)} | Total: ${stats.total.toString().padStart(4)} | Active: ${stats.active.toString().padStart(4)} | Deleted: ${stats.deleted.toString().padStart(4)}`);
      }
    }

  } catch (error) {
    console.error('❌ Error during cleanup:', error);
    process.exit(1);
  } finally {
    await knex.destroy();
  }
}

// Show usage information
function showUsage() {
  console.log('Usage: node src/scripts/cleanup-soft-deleted.js [options]');
  console.log('');
  console.log('Options:');
  console.log('  --days=N        Delete records older than N days (default: 30)');
  console.log('  --dry-run       Show what would be deleted without making changes');
  console.log('  --table=NAME    Process only the specified table');
  console.log('  --help          Show this help message');
  console.log('');
  console.log('Examples:');
  console.log('  node src/scripts/cleanup-soft-deleted.js --dry-run');
  console.log('  node src/scripts/cleanup-soft-deleted.js --days=60');
  console.log('  node src/scripts/cleanup-soft-deleted.js --table=tasks --days=7');
}

// Handle help flag
if (args.includes('--help')) {
  showUsage();
  process.exit(0);
}

// Run the main function
main().catch(error => {
  console.error('❌ Unexpected error:', error);
  process.exit(1);
});
