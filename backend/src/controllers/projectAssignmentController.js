const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

class ProjectAssignmentController {
  // Get all users assigned to a project
  async getProjectAssignments(req, res) {
    try {
      const { projectId } = req.params;
      
      // Check if user has access to this project
      const hasAccess = await this.checkProjectAccess(req.user.id, projectId);
      if (!hasAccess) {
        return res.status(403).json({ error: 'No access to this project' });
      }

      const assignments = await prisma.userProjectAssignment.findMany({
        where: { projectId },
        include: {
          user: {
            select: {
              id: true,
              name: true,
              email: true,
              shortName: true,
              profilePicture: true,
              role: true,
              isActive: true
            }
          },
          assignedByUser: {
            select: {
              id: true,
              name: true,
              email: true
            }
          }
        },
        orderBy: [
          { role: 'asc' },
          { assignedAt: 'desc' }
        ]
      });

      res.json(assignments);
    } catch (error) {
      console.error('Get project assignments error:', error);
      res.status(500).json({ error: 'Failed to fetch project assignments' });
    }
  }

  // Assign users to a project (Admin/Project Manager only)
  async assignUsersToProject(req, res) {
    try {
      const { projectId } = req.params;
      const { userIds, role = 'MEMBER', notes } = req.body;

      // Check if user can manage this project
      const canManage = await this.checkProjectManageAccess(req.user.id, projectId);
      if (!canManage) {
        return res.status(403).json({ error: 'Insufficient permissions to manage project assignments' });
      }

      // Validate users exist and are active
      const users = await prisma.user.findMany({
        where: {
          id: { in: userIds },
          isActive: true
        },
        select: { id: true, name: true, email: true, role: true }
      });

      if (users.length !== userIds.length) {
        return res.status(400).json({ error: 'Some users not found or inactive' });
      }

      // Create assignments
      const assignments = [];
      const assignmentHistory = [];

      for (const user of users) {
        // Check if assignment already exists
        const existingAssignment = await prisma.userProjectAssignment.findUnique({
          where: {
            userId_projectId: {
              userId: user.id,
              projectId: projectId
            }
          }
        });

        if (existingAssignment) {
          // Update existing assignment
          const updated = await prisma.userProjectAssignment.update({
            where: { id: existingAssignment.id },
            data: {
              role,
              assignmentStatus: 'ASSIGNED',
              notes,
              updatedAt: new Date()
            },
            include: {
              user: {
                select: {
                  id: true,
                  name: true,
                  email: true,
                  shortName: true
                }
              }
            }
          });
          assignments.push(updated);

          // Log assignment history
          assignmentHistory.push({
            entityType: 'PROJECT',
            entityId: projectId,
            userId: user.id,
            action: 'ROLE_CHANGED',
            oldRole: existingAssignment.role,
            newRole: role,
            oldStatus: existingAssignment.assignmentStatus,
            newStatus: 'ASSIGNED',
            performedBy: req.user.id,
            notes
          });
        } else {
          // Create new assignment
          const newAssignment = await prisma.userProjectAssignment.create({
            data: {
              userId: user.id,
              projectId,
              role,
              assignmentStatus: 'ASSIGNED',
              assignedBy: req.user.id,
              notes
            },
            include: {
              user: {
                select: {
                  id: true,
                  name: true,
                  email: true,
                  shortName: true
                }
              }
            }
          });
          assignments.push(newAssignment);

          // Log assignment history
          assignmentHistory.push({
            entityType: 'PROJECT',
            entityId: projectId,
            userId: user.id,
            action: 'ASSIGNED',
            newRole: role,
            newStatus: 'ASSIGNED',
            performedBy: req.user.id,
            notes
          });
        }
      }

      // Bulk create assignment history
      if (assignmentHistory.length > 0) {
        await prisma.assignmentHistory.createMany({
          data: assignmentHistory
        });
      }

      res.json({
        message: `Successfully assigned ${assignments.length} users to project`,
        assignments
      });
    } catch (error) {
      console.error('Assign users to project error:', error);
      res.status(500).json({ error: 'Failed to assign users to project' });
    }
  }

  // Remove user from project
  async removeUserFromProject(req, res) {
    try {
      const { projectId, userId } = req.params;
      const { notes } = req.body;

      // Check if user can manage this project
      const canManage = await this.checkProjectManageAccess(req.user.id, projectId);
      if (!canManage) {
        return res.status(403).json({ error: 'Insufficient permissions to manage project assignments' });
      }

      // Find existing assignment
      const assignment = await prisma.userProjectAssignment.findUnique({
        where: {
          userId_projectId: {
            userId,
            projectId
          }
        }
      });

      if (!assignment) {
        return res.status(404).json({ error: 'Assignment not found' });
      }

      // Remove assignment
      await prisma.userProjectAssignment.delete({
        where: { id: assignment.id }
      });

      // Log assignment history
      await prisma.assignmentHistory.create({
        data: {
          entityType: 'PROJECT',
          entityId: projectId,
          userId,
          action: 'UNASSIGNED',
          oldRole: assignment.role,
          oldStatus: assignment.assignmentStatus,
          newStatus: 'UNASSIGNED',
          performedBy: req.user.id,
          notes
        }
      });

      res.json({ message: 'User successfully removed from project' });
    } catch (error) {
      console.error('Remove user from project error:', error);
      res.status(500).json({ error: 'Failed to remove user from project' });
    }
  }

  // Get assignment history for a project
  async getAssignmentHistory(req, res) {
    try {
      const { projectId } = req.params;
      
      // Check if user has access to this project
      const hasAccess = await this.checkProjectAccess(req.user.id, projectId);
      if (!hasAccess) {
        return res.status(403).json({ error: 'No access to this project' });
      }

      const history = await prisma.assignmentHistory.findMany({
        where: {
          entityType: 'PROJECT',
          entityId: projectId
        },
        include: {
          user: {
            select: {
              id: true,
              name: true,
              email: true
            }
          },
          performer: {
            select: {
              id: true,
              name: true,
              email: true
            }
          }
        },
        orderBy: { createdAt: 'desc' }
      });

      res.json(history);
    } catch (error) {
      console.error('Get assignment history error:', error);
      res.status(500).json({ error: 'Failed to fetch assignment history' });
    }
  }

  // Helper methods
  async checkProjectAccess(userId, projectId) {
    const assignment = await prisma.userProjectAssignment.findFirst({
      where: {
        userId,
        projectId,
        assignmentStatus: 'ASSIGNED'
      }
    });

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { role: true }
    });

    return assignment || ['ADMIN'].includes(user?.role);
  }

  async checkProjectManageAccess(userId, projectId) {
    const assignment = await prisma.userProjectAssignment.findFirst({
      where: {
        userId,
        projectId,
        assignmentStatus: 'ASSIGNED',
        role: { in: ['OWNER', 'ADMIN'] }
      }
    });

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { role: true }
    });

    return assignment || ['ADMIN', 'PROJECT_MANAGER'].includes(user?.role);
  }
}

module.exports = new ProjectAssignmentController();
