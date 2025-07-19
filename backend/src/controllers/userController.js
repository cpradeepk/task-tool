const prisma = require('../config/database');
const googleDriveService = require('../config/googleDrive');

class UserController {
  async getProfile(req, res) {
    try {
      const user = await prisma.user.findUnique({
        where: { id: req.user.id },
        select: {
          id: true,
          email: true,
          name: true,
          shortName: true,
          phone: true,
          telegram: true,
          whatsapp: true,
          profilePictureId: true,
          isAdmin: true,
          primaryColor: true,
          fontFamily: true,
          createdAt: true,
          updatedAt: true
        }
      });

      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }

      res.json({
        ...user,
        profilePictureUrl: user.profilePictureId ? 
          `/api/files/profile-picture/${user.profilePictureId}` : null
      });
    } catch (error) {
      console.error('Get profile error:', error);
      res.status(500).json({ error: 'Failed to fetch profile' });
    }
  }

  async updateProfile(req, res) {
    try {
      const {
        name,
        shortName,
        phone,
        telegram,
        whatsapp,
        primaryColor,
        fontFamily
      } = req.body;

      const updatedUser = await prisma.user.update({
        where: { id: req.user.id },
        data: {
          ...(name && { name }),
          ...(shortName !== undefined && { shortName }),
          ...(phone !== undefined && { phone }),
          ...(telegram !== undefined && { telegram }),
          ...(whatsapp !== undefined && { whatsapp }),
          ...(primaryColor && { primaryColor }),
          ...(fontFamily && { fontFamily })
        },
        select: {
          id: true,
          email: true,
          name: true,
          shortName: true,
          phone: true,
          telegram: true,
          whatsapp: true,
          profilePictureId: true,
          isAdmin: true,
          primaryColor: true,
          fontFamily: true,
          updatedAt: true
        }
      });

      res.json({
        ...updatedUser,
        profilePictureUrl: updatedUser.profilePictureId ? 
          `/api/files/profile-picture/${updatedUser.profilePictureId}` : null
      });
    } catch (error) {
      console.error('Update profile error:', error);
      res.status(500).json({ error: 'Failed to update profile' });
    }
  }

  async getAllUsers(req, res) {
    try {
      const users = await prisma.user.findMany({
        select: {
          id: true,
          email: true,
          name: true,
          shortName: true,
          isAdmin: true,
          isActive: true,
          createdAt: true,
          profilePictureId: true,
          _count: {
            select: {
              assignedTasks: true,
              createdTasks: true
            }
          }
        },
        orderBy: [
          { isAdmin: 'desc' },
          { name: 'asc' }
        ]
      });

      const usersWithUrls = users.map(user => ({
        ...user,
        profilePictureUrl: user.profilePictureId ? 
          `/api/files/profile-picture/${user.profilePictureId}` : null
      }));

      res.json(usersWithUrls);
    } catch (error) {
      console.error('Get all users error:', error);
      res.status(500).json({ error: 'Failed to fetch users' });
    }
  }

  async toggleUserStatus(req, res) {
    try {
      const { id } = req.params;

      // Prevent admin from deactivating themselves
      if (id === req.user.id) {
        return res.status(400).json({ 
          error: 'Cannot change your own status' 
        });
      }

      const user = await prisma.user.findUnique({
        where: { id },
        select: { isActive: true, isAdmin: true }
      });

      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }

      // Prevent deactivating the last admin
      if (user.isAdmin && user.isActive) {
        const adminCount = await prisma.user.count({
          where: { isAdmin: true, isActive: true }
        });

        if (adminCount <= 1) {
          return res.status(400).json({ 
            error: 'Cannot deactivate the last admin user' 
          });
        }
      }

      const updatedUser = await prisma.user.update({
        where: { id },
        data: { isActive: !user.isActive },
        select: {
          id: true,
          email: true,
          name: true,
          isAdmin: true,
          isActive: true
        }
      });

      res.json({
        message: `User ${updatedUser.isActive ? 'activated' : 'deactivated'} successfully`,
        user: updatedUser
      });
    } catch (error) {
      console.error('Toggle user status error:', error);
      res.status(500).json({ error: 'Failed to update user status' });
    }
  }
}

module.exports = new UserController();