const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

class PriorityController {
  // Update priority for a task, project, or module
  async updatePriority(req, res) {
    try {
      const { entityType, entityId } = req.params;
      const { priority, priorityNumber, reason } = req.body;

      // Validate entity type
      if (!['PROJECT', 'TASK', 'MODULE'].includes(entityType.toUpperCase())) {
        return res.status(400).json({ error: 'Invalid entity type' });
      }

      // Get current entity and check permissions
      const entity = await this.getEntity(entityType.toUpperCase(), entityId);
      if (!entity) {
        return res.status(404).json({ error: `${entityType} not found` });
      }

      // Check if user has permission to update priority
      const canUpdate = await this.checkPriorityUpdatePermission(req.user.id, entityType.toUpperCase(), entity);
      if (!canUpdate) {
        return res.status(403).json({ error: 'Insufficient permissions to update priority' });
      }

      // Get user role to determine if approval is needed
      const user = await prisma.user.findUnique({
        where: { id: req.user.id },
        select: { role: true }
      });

      const needsApproval = !['ADMIN', 'PROJECT_MANAGER'].includes(user.role);
      const status = needsApproval ? 'PENDING' : 'APPROVED';

      // Log priority change
      const priorityChangeLog = await prisma.priorityChangeLog.create({
        data: {
          entityType: entityType.toUpperCase(),
          entityId,
          oldPriority: entity.priority,
          newPriority: priority,
          oldPriorityNumber: entity.priorityNumber,
          newPriorityNumber: priorityNumber,
          reason,
          changedBy: req.user.id,
          status
        },
        include: {
          changer: {
            select: {
              id: true,
              name: true,
              email: true,
              role: true
            }
          }
        }
      });

      // If auto-approved, update the entity immediately
      if (status === 'APPROVED') {
        await this.updateEntityPriority(entityType.toUpperCase(), entityId, priority, priorityNumber);
      }

      res.json({
        message: needsApproval ? 'Priority change submitted for approval' : 'Priority updated successfully',
        priorityChangeLog,
        needsApproval
      });
    } catch (error) {
      console.error('Update priority error:', error);
      res.status(500).json({ error: 'Failed to update priority' });
    }
  }

  // Get priority change requests for approval
  async getPriorityChangeRequests(req, res) {
    try {
      const { status = 'PENDING', entityType } = req.query;

      // Check if user can approve priority changes
      const user = await prisma.user.findUnique({
        where: { id: req.user.id },
        select: { role: true }
      });

      if (!['ADMIN', 'PROJECT_MANAGER'].includes(user.role)) {
        return res.status(403).json({ error: 'Insufficient permissions to view priority change requests' });
      }

      const where = { status };
      if (entityType) {
        where.entityType = entityType.toUpperCase();
      }

      const requests = await prisma.priorityChangeLog.findMany({
        where,
        include: {
          changer: {
            select: {
              id: true,
              name: true,
              email: true,
              role: true
            }
          },
          approver: {
            select: {
              id: true,
              name: true,
              email: true
            }
          }
        },
        orderBy: { createdAt: 'desc' }
      });

      // Enrich with entity details
      const enrichedRequests = await Promise.all(
        requests.map(async (request) => {
          const entity = await this.getEntity(request.entityType, request.entityId);
          return {
            ...request,
            entityDetails: entity ? {
              id: entity.id,
              name: entity.name || entity.title,
              currentPriority: entity.priority,
              currentPriorityNumber: entity.priorityNumber
            } : null
          };
        })
      );

      res.json(enrichedRequests);
    } catch (error) {
      console.error('Get priority change requests error:', error);
      res.status(500).json({ error: 'Failed to fetch priority change requests' });
    }
  }

  // Approve or reject priority change request
  async reviewPriorityChange(req, res) {
    try {
      const { requestId } = req.params;
      const { action, notes } = req.body; // action: 'APPROVE' or 'REJECT'

      // Check if user can approve priority changes
      const user = await prisma.user.findUnique({
        where: { id: req.user.id },
        select: { role: true }
      });

      if (!['ADMIN', 'PROJECT_MANAGER'].includes(user.role)) {
        return res.status(403).json({ error: 'Insufficient permissions to review priority changes' });
      }

      // Get the priority change request
      const request = await prisma.priorityChangeLog.findUnique({
        where: { id: requestId }
      });

      if (!request) {
        return res.status(404).json({ error: 'Priority change request not found' });
      }

      if (request.status !== 'PENDING') {
        return res.status(400).json({ error: 'Request has already been reviewed' });
      }

      // Update the request status
      const updatedRequest = await prisma.priorityChangeLog.update({
        where: { id: requestId },
        data: {
          status: action === 'APPROVE' ? 'APPROVED' : 'REJECTED',
          approvedBy: req.user.id
        },
        include: {
          changer: {
            select: {
              id: true,
              name: true,
              email: true
            }
          },
          approver: {
            select: {
              id: true,
              name: true,
              email: true
            }
          }
        }
      });

      // If approved, update the entity
      if (action === 'APPROVE') {
        await this.updateEntityPriority(
          request.entityType,
          request.entityId,
          request.newPriority,
          request.newPriorityNumber
        );
      }

      res.json({
        message: `Priority change ${action.toLowerCase()}d successfully`,
        request: updatedRequest
      });
    } catch (error) {
      console.error('Review priority change error:', error);
      res.status(500).json({ error: 'Failed to review priority change' });
    }
  }

  // Get priority statistics for a project
  async getPriorityStatistics(req, res) {
    try {
      const { projectId } = req.params;

      // Check if user has access to this project
      const hasAccess = await this.checkProjectAccess(req.user.id, projectId);
      if (!hasAccess) {
        return res.status(403).json({ error: 'No access to this project' });
      }

      // Get task priority distribution
      const taskPriorityStats = await prisma.task.groupBy({
        by: ['priority'],
        where: { projectId },
        _count: { priority: true }
      });

      // Get module priority distribution
      const modulePriorityStats = await prisma.enhancedModule.groupBy({
        by: ['priority'],
        where: { projectId },
        _count: { priority: true }
      });

      // Get recent priority changes
      const recentChanges = await prisma.priorityChangeLog.findMany({
        where: {
          OR: [
            { entityType: 'PROJECT', entityId: projectId },
            {
              entityType: 'TASK',
              entityId: {
                in: await prisma.task.findMany({
                  where: { projectId },
                  select: { id: true }
                }).then(tasks => tasks.map(t => t.id))
              }
            },
            {
              entityType: 'MODULE',
              entityId: {
                in: await prisma.enhancedModule.findMany({
                  where: { projectId },
                  select: { id: true }
                }).then(modules => modules.map(m => m.id))
              }
            }
          ]
        },
        include: {
          changer: {
            select: {
              id: true,
              name: true,
              email: true
            }
          }
        },
        orderBy: { createdAt: 'desc' },
        take: 10
      });

      res.json({
        taskPriorityDistribution: taskPriorityStats,
        modulePriorityDistribution: modulePriorityStats,
        recentPriorityChanges: recentChanges
      });
    } catch (error) {
      console.error('Get priority statistics error:', error);
      res.status(500).json({ error: 'Failed to fetch priority statistics' });
    }
  }

  // Helper methods
  async getEntity(entityType, entityId) {
    switch (entityType) {
      case 'PROJECT':
        return await prisma.project.findUnique({
          where: { id: entityId },
          select: { id: true, name: true, priority: true, priorityNumber: true }
        });
      case 'TASK':
        return await prisma.task.findUnique({
          where: { id: entityId },
          select: { id: true, title: true, priority: true, priorityNumber: true, projectId: true }
        });
      case 'MODULE':
        return await prisma.enhancedModule.findUnique({
          where: { id: entityId },
          select: { id: true, name: true, priority: true, priorityNumber: true, projectId: true }
        });
      default:
        return null;
    }
  }

  async updateEntityPriority(entityType, entityId, priority, priorityNumber) {
    const updateData = {
      priority,
      ...(priorityNumber !== undefined && { priorityNumber })
    };

    switch (entityType) {
      case 'PROJECT':
        return await prisma.project.update({
          where: { id: entityId },
          data: updateData
        });
      case 'TASK':
        return await prisma.task.update({
          where: { id: entityId },
          data: updateData
        });
      case 'MODULE':
        return await prisma.enhancedModule.update({
          where: { id: entityId },
          data: updateData
        });
    }
  }

  async checkPriorityUpdatePermission(userId, entityType, entity) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { role: true }
    });

    // Admins and Project Managers can always update priorities
    if (['ADMIN', 'PROJECT_MANAGER'].includes(user.role)) {
      return true;
    }

    // For other users, check if they have access to the project
    const projectId = entityType === 'PROJECT' ? entity.id : entity.projectId;
    return await this.checkProjectAccess(userId, projectId);
  }

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
}

module.exports = new PriorityController();
