const { PrismaClient } = require('@prisma/client');
const logger = require('../config/logger');

const prisma = new PrismaClient();

class MasterDataController {
  // Get all master data by type
  async getMasterDataByType(req, res) {
    try {
      const { type } = req.params;
      const { includeInactive } = req.query;

      const validTypes = ['TASK_STATUS', 'TASK_TYPE', 'PROJECT_TYPE'];
      if (!validTypes.includes(type)) {
        return res.status(400).json({ error: 'Invalid master data type' });
      }

      const where = { type };
      if (includeInactive !== 'true') {
        where.isActive = true;
      }

      const masterData = await prisma.masterData.findMany({
        where,
        orderBy: { sortOrder: 'asc' }
      });

      res.json(masterData);
    } catch (error) {
      logger.error('Error fetching master data:', error);
      res.status(500).json({ error: 'Failed to fetch master data' });
    }
  }

  // Get all master data
  async getAllMasterData(req, res) {
    try {
      const masterData = await prisma.masterData.findMany({
        orderBy: [
          { type: 'asc' },
          { sortOrder: 'asc' }
        ]
      });

      // Group by type
      const grouped = masterData.reduce((acc, item) => {
        if (!acc[item.type]) {
          acc[item.type] = [];
        }
        acc[item.type].push(item);
        return acc;
      }, {});

      res.json(grouped);
    } catch (error) {
      logger.error('Error fetching all master data:', error);
      res.status(500).json({ error: 'Failed to fetch master data' });
    }
  }

  // Create master data item (admin only)
  async createMasterData(req, res) {
    try {
      const { type, key, value, description, sortOrder } = req.body;

      const validTypes = ['TASK_STATUS', 'TASK_TYPE', 'PROJECT_TYPE'];
      if (!validTypes.includes(type)) {
        return res.status(400).json({ error: 'Invalid master data type' });
      }

      const masterData = await prisma.masterData.create({
        data: {
          type,
          key: key.toUpperCase(),
          value,
          description,
          sortOrder: sortOrder || 0
        }
      });

      logger.info(`Master data created: ${type}/${key} by ${req.user.email}`);
      res.status(201).json(masterData);
    } catch (error) {
      if (error.code === 'P2002') {
        return res.status(400).json({ error: 'Master data key already exists for this type' });
      }
      logger.error('Error creating master data:', error);
      res.status(500).json({ error: 'Failed to create master data' });
    }
  }

  // Update master data item (admin only)
  async updateMasterData(req, res) {
    try {
      const { id } = req.params;
      const { value, description, isActive, sortOrder } = req.body;

      const masterData = await prisma.masterData.update({
        where: { id },
        data: {
          value,
          description,
          isActive,
          sortOrder
        }
      });

      logger.info(`Master data updated: ${masterData.type}/${masterData.key} by ${req.user.email}`);
      res.json(masterData);
    } catch (error) {
      logger.error('Error updating master data:', error);
      res.status(500).json({ error: 'Failed to update master data' });
    }
  }

  // Delete master data item (admin only)
  async deleteMasterData(req, res) {
    try {
      const { id } = req.params;

      const masterData = await prisma.masterData.findUnique({
        where: { id }
      });

      if (!masterData) {
        return res.status(404).json({ error: 'Master data not found' });
      }

      // Check if master data is in use
      const inUse = await this.checkMasterDataInUse(masterData.type, masterData.key);
      if (inUse) {
        return res.status(400).json({ 
          error: 'Cannot delete master data that is currently in use',
          suggestion: 'Consider deactivating instead of deleting'
        });
      }

      await prisma.masterData.delete({
        where: { id }
      });

      logger.info(`Master data deleted: ${masterData.type}/${masterData.key} by ${req.user.email}`);
      res.json({ message: 'Master data deleted successfully' });
    } catch (error) {
      logger.error('Error deleting master data:', error);
      res.status(500).json({ error: 'Failed to delete master data' });
    }
  }

  // Check if master data is in use
  async checkMasterDataInUse(type, key) {
    try {
      switch (type) {
        case 'TASK_STATUS':
          const taskCount = await prisma.task.count({
            where: { status: key }
          });
          return taskCount > 0;

        case 'TASK_TYPE':
          const taskTypeCount = await prisma.task.count({
            where: { taskType: key }
          });
          return taskTypeCount > 0;

        case 'PROJECT_TYPE':
          const projectCount = await prisma.project.count({
            where: { projectType: key }
          });
          return projectCount > 0;

        default:
          return false;
      }
    } catch (error) {
      logger.error('Error checking master data usage:', error);
      return true; // Err on the side of caution
    }
  }

  // Reorder master data items (admin only)
  async reorderMasterData(req, res) {
    try {
      const { type } = req.params;
      const { items } = req.body; // Array of {id, sortOrder}

      const validTypes = ['TASK_STATUS', 'TASK_TYPE', 'PROJECT_TYPE'];
      if (!validTypes.includes(type)) {
        return res.status(400).json({ error: 'Invalid master data type' });
      }

      await Promise.all(
        items.map(item =>
          prisma.masterData.update({
            where: { id: item.id },
            data: { sortOrder: item.sortOrder }
          })
        )
      );

      logger.info(`Master data reordered for type: ${type} by ${req.user.email}`);
      res.json({ message: 'Master data reordered successfully' });
    } catch (error) {
      logger.error('Error reordering master data:', error);
      res.status(500).json({ error: 'Failed to reorder master data' });
    }
  }
}

module.exports = new MasterDataController();