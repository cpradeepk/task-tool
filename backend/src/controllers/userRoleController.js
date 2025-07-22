const { PrismaClient } = require('@prisma/client');
const logger = require('../config/logger');

const prisma = new PrismaClient();

class UserRoleController {
  // Get all users with roles (admin only)
  async getAllUsersWithRoles(req, res) {
    try {
      const { search, role, isActive } = req.query;
      
      const where = {};
      
      if (search) {
        where.OR = [
          { name: { contains: search, mode: 'insensitive' } },
          { email: { contains: search, mode: 'insensitive' } }
        ];
      }
      
      if (role) {
        where.role = role;
      }
      
      if (isActive !== undefined) {
        where.isActive = isActive === 'true';
      }

      const users = await prisma.user.findMany({
        where,
        select: {
          id: true,
          email: true,
          name: true,
          role: true,
          isAdmin: true,
          isActive: true,
          lastLoginAt: true,
          createdAt: true,
          _count: {
            select: {
              createdProjects: true,
              managedProjects: true,
              projectMemberships: true
            }
          }
        },
        orderBy: [
          { role: 'asc' },
          { name: 'asc' }
        ]
      });

      res.json(users);
    } catch (error) {
      logger.error('Error fetching users with roles:', error);
      res.status(500).json({ error: 'Failed to fetch users' });
    }
  }

  // Update user role (admin only)
  async updateUserRole(req, res) {
    try {
      const { userId } = req.params;
      const { role } = req.body;

      // Validate role
      const validRoles = ['ADMIN', 'PROJECT_MANAGER', 'MEMBER', 'VIEWER'];
      if (!validRoles.includes(role)) {
        return res.status(400).json({ error: 'Invalid role specified' });
      }

      // Prevent self-demotion from admin
      if (req.user.id === userId && req.user.role === 'ADMIN' && role !== 'ADMIN') {
        return res.status(400).json({ error: 'Cannot demote yourself from admin role' });
      }

      const updatedUser = await prisma.user.update({
        where: { id: userId },
        data: { 
          role,
          isAdmin: role === 'ADMIN'
        },
        select: {
          id: true,
          email: true,
          name: true,
          role: true,
          isAdmin: true
        }
      });

      logger.info(`User role updated: ${updatedUser.email} -> ${role} by ${req.user.email}`);
      res.json(updatedUser);
    } catch (error) {
      logger.error('Error updating user role:', error);
      res.status(500).json({ error: 'Failed to update user role' });
    }
  }

  // Bulk role update (admin only)
  async bulkUpdateRoles(req, res) {
    try {
      const { updates } = req.body; // Array of {userId, role}

      const validRoles = ['ADMIN', 'PROJECT_MANAGER', 'MEMBER', 'VIEWER'];
      
      // Validate all updates
      for (const update of updates) {
        if (!validRoles.includes(update.role)) {
          return res.status(400).json({ error: `Invalid role: ${update.role}` });
        }
        
        // Prevent self-demotion from admin
        if (update.userId === req.user.id && req.user.role === 'ADMIN' && update.role !== 'ADMIN') {
          return res.status(400).json({ error: 'Cannot demote yourself from admin role' });
        }
      }

      const results = await Promise.all(
        updates.map(update => 
          prisma.user.update({
            where: { id: update.userId },
            data: { 
              role: update.role,
              isAdmin: update.role === 'ADMIN'
            },
            select: {
              id: true,
              email: true,
              name: true,
              role: true
            }
          })
        )
      );

      logger.info(`Bulk role update completed for ${results.length} users by ${req.user.email}`);
      res.json(results);
    } catch (error) {
      logger.error('Error in bulk role update:', error);
      res.status(500).json({ error: 'Failed to update user roles' });
    }
  }
}

module.exports = new UserRoleController();