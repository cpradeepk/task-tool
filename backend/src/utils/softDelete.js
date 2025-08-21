/**
 * Soft Delete Utility Functions
 * Provides consistent soft delete functionality across all entities
 */

import { knex } from '../db/index.js';

/**
 * Soft delete a record by setting is_deleted=true, deleted_at=now, deleted_by=userId
 * @param {string} tableName - Name of the table
 * @param {number} id - ID of the record to delete
 * @param {number} userId - ID of the user performing the deletion
 * @returns {Promise<boolean>} - True if successful
 */
export async function softDelete(tableName, id, userId) {
  try {
    const result = await knex(tableName)
      .where('id', id)
      .where('is_deleted', false) // Only delete if not already deleted
      .update({
        is_deleted: true,
        deleted_at: knex.fn.now(),
        deleted_by: userId
      });

    return result > 0;
  } catch (error) {
    console.error(`Error soft deleting from ${tableName}:`, error);
    throw error;
  }
}

/**
 * Restore a soft deleted record
 * @param {string} tableName - Name of the table
 * @param {number} id - ID of the record to restore
 * @returns {Promise<boolean>} - True if successful
 */
export async function restoreSoftDeleted(tableName, id) {
  try {
    const result = await knex(tableName)
      .where('id', id)
      .where('is_deleted', true) // Only restore if deleted
      .update({
        is_deleted: false,
        deleted_at: null,
        deleted_by: null
      });

    return result > 0;
  } catch (error) {
    console.error(`Error restoring from ${tableName}:`, error);
    throw error;
  }
}

/**
 * Get query builder with soft delete filter applied
 * @param {string} tableName - Name of the table
 * @param {boolean} includeDeleted - Whether to include deleted records
 * @returns {QueryBuilder} - Knex query builder
 */
export function getQueryWithSoftDelete(tableName, includeDeleted = false) {
  const query = knex(tableName);
  
  if (!includeDeleted) {
    query.where('is_deleted', false);
  }
  
  return query;
}

/**
 * Add soft delete columns to a table if they don't exist
 * @param {string} tableName - Name of the table
 * @returns {Promise<void>}
 */
export async function ensureSoftDeleteColumns(tableName) {
  try {
    const hasIsDeletedColumn = await knex.schema.hasColumn(tableName, 'is_deleted');
    const hasDeletedAtColumn = await knex.schema.hasColumn(tableName, 'deleted_at');
    const hasDeletedByColumn = await knex.schema.hasColumn(tableName, 'deleted_by');

    if (!hasIsDeletedColumn || !hasDeletedAtColumn || !hasDeletedByColumn) {
      await knex.schema.alterTable(tableName, (table) => {
        if (!hasIsDeletedColumn) {
          table.boolean('is_deleted').defaultTo(false);
        }
        if (!hasDeletedAtColumn) {
          table.timestamp('deleted_at');
        }
        if (!hasDeletedByColumn) {
          table.integer('deleted_by').references('id').inTable('users');
        }
      });
      console.log(`Added soft delete columns to ${tableName} table`);
    }
  } catch (error) {
    console.error(`Error ensuring soft delete columns for ${tableName}:`, error);
    throw error;
  }
}

/**
 * Permanently delete records that have been soft deleted for more than specified days
 * @param {string} tableName - Name of the table
 * @param {number} daysOld - Number of days after which to permanently delete
 * @returns {Promise<number>} - Number of records permanently deleted
 */
export async function permanentlyDeleteOldRecords(tableName, daysOld = 30) {
  try {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - daysOld);

    const result = await knex(tableName)
      .where('is_deleted', true)
      .where('deleted_at', '<', cutoffDate)
      .del();

    console.log(`Permanently deleted ${result} old records from ${tableName}`);
    return result;
  } catch (error) {
    console.error(`Error permanently deleting old records from ${tableName}:`, error);
    throw error;
  }
}

/**
 * Get soft delete statistics for a table
 * @param {string} tableName - Name of the table
 * @returns {Promise<Object>} - Statistics object
 */
export async function getSoftDeleteStats(tableName) {
  try {
    const [totalCount] = await knex(tableName).count('* as count');
    const [activeCount] = await knex(tableName).where('is_deleted', false).count('* as count');
    const [deletedCount] = await knex(tableName).where('is_deleted', true).count('* as count');

    return {
      total: parseInt(totalCount.count),
      active: parseInt(activeCount.count),
      deleted: parseInt(deletedCount.count)
    };
  } catch (error) {
    console.error(`Error getting soft delete stats for ${tableName}:`, error);
    throw error;
  }
}

/**
 * Bulk soft delete multiple records
 * @param {string} tableName - Name of the table
 * @param {Array<number>} ids - Array of IDs to delete
 * @param {number} userId - ID of the user performing the deletion
 * @returns {Promise<number>} - Number of records deleted
 */
export async function bulkSoftDelete(tableName, ids, userId) {
  try {
    const result = await knex(tableName)
      .whereIn('id', ids)
      .where('is_deleted', false)
      .update({
        is_deleted: true,
        deleted_at: knex.fn.now(),
        deleted_by: userId
      });

    return result;
  } catch (error) {
    console.error(`Error bulk soft deleting from ${tableName}:`, error);
    throw error;
  }
}

/**
 * Check if a record is soft deleted
 * @param {string} tableName - Name of the table
 * @param {number} id - ID of the record
 * @returns {Promise<boolean>} - True if record is soft deleted
 */
export async function isSoftDeleted(tableName, id) {
  try {
    const record = await knex(tableName)
      .where('id', id)
      .select('is_deleted')
      .first();

    return record ? record.is_deleted : false;
  } catch (error) {
    console.error(`Error checking soft delete status for ${tableName}:`, error);
    throw error;
  }
}
