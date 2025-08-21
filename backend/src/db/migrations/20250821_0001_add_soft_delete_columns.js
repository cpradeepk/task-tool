/**
 * Add soft delete columns to all entities (except chats and notes)
 * This migration adds is_deleted, deleted_at, and deleted_by columns
 * to all tables that need soft delete functionality
 */

export async function up(knex) {
  console.log('Adding soft delete columns to all entities...');

  // List of tables that need soft delete (excluding chats, notes, and master data)
  const tablesToUpdate = [
    'users',
    'projects', 
    'modules',
    'tasks', // Already has soft delete, but we'll check
    'subtasks',
    'task_dependencies',
    'pert_estimates',
    'attachments',
    'user_profiles',
    'user_roles',
    'roles'
  ];

  for (const tableName of tablesToUpdate) {
    // Check if table exists
    const tableExists = await knex.schema.hasTable(tableName);
    if (!tableExists) {
      console.log(`Table ${tableName} does not exist, skipping...`);
      continue;
    }

    console.log(`Processing table: ${tableName}`);

    // Check if soft delete columns exist
    const hasIsDeletedColumn = await knex.schema.hasColumn(tableName, 'is_deleted');
    const hasDeletedAtColumn = await knex.schema.hasColumn(tableName, 'deleted_at');
    const hasDeletedByColumn = await knex.schema.hasColumn(tableName, 'deleted_by');

    if (!hasIsDeletedColumn || !hasDeletedAtColumn || !hasDeletedByColumn) {
      await knex.schema.alterTable(tableName, (table) => {
        if (!hasIsDeletedColumn) {
          table.boolean('is_deleted').defaultTo(false);
          console.log(`  Added is_deleted column to ${tableName}`);
        }
        if (!hasDeletedAtColumn) {
          table.timestamp('deleted_at');
          console.log(`  Added deleted_at column to ${tableName}`);
        }
        if (!hasDeletedByColumn) {
          table.integer('deleted_by').references('id').inTable('users');
          console.log(`  Added deleted_by column to ${tableName}`);
        }
      });
    } else {
      console.log(`  Soft delete columns already exist in ${tableName}`);
    }

    // Create index on is_deleted for performance
    const indexName = `idx_${tableName}_is_deleted`;
    try {
      await knex.schema.alterTable(tableName, (table) => {
        table.index('is_deleted', indexName);
      });
      console.log(`  Created index ${indexName}`);
    } catch (error) {
      if (error.message.includes('already exists')) {
        console.log(`  Index ${indexName} already exists`);
      } else {
        console.log(`  Warning: Could not create index ${indexName}: ${error.message}`);
      }
    }
  }

  console.log('Soft delete columns migration completed successfully!');
}

export async function down(knex) {
  console.log('Removing soft delete columns...');

  const tablesToUpdate = [
    'users',
    'projects', 
    'modules',
    'subtasks',
    'task_dependencies',
    'pert_estimates',
    'attachments',
    'user_profiles',
    'user_roles',
    'roles'
  ];

  for (const tableName of tablesToUpdate) {
    const tableExists = await knex.schema.hasTable(tableName);
    if (!tableExists) {
      continue;
    }

    console.log(`Removing soft delete columns from: ${tableName}`);

    // Drop index first
    const indexName = `idx_${tableName}_is_deleted`;
    try {
      await knex.schema.alterTable(tableName, (table) => {
        table.dropIndex('is_deleted', indexName);
      });
    } catch (error) {
      // Index might not exist, continue
    }

    // Remove columns
    await knex.schema.alterTable(tableName, (table) => {
      table.dropColumn('is_deleted');
      table.dropColumn('deleted_at');
      table.dropColumn('deleted_by');
    });
  }

  console.log('Soft delete columns removal completed!');
}
