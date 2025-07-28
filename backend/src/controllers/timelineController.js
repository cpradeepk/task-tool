const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

class TimelineController {
  // Get project timeline for Gantt chart
  async getProjectTimeline(req, res) {
    try {
      const { projectId } = req.params;
      const { includeBaseline = false, includeDependencies = false } = req.query;

      // Check if user has access to this project
      const hasAccess = await this.checkProjectAccess(req.user.id, projectId);
      if (!hasAccess) {
        return res.status(403).json({ error: 'No access to this project' });
      }

      // Get project details
      const project = await prisma.project.findUnique({
        where: { id: projectId },
        select: {
          id: true,
          name: true,
          startDate: true,
          endDate: true,
          status: true
        }
      });

      if (!project) {
        return res.status(404).json({ error: 'Project not found' });
      }

      // Get timeline entries
      const timelineEntries = await prisma.projectTimeline.findMany({
        where: { projectId },
        orderBy: [
          { startDate: 'asc' },
          { entityType: 'asc' }
        ]
      });

      // Get modules with their tasks
      const modules = await prisma.enhancedModule.findMany({
        where: { projectId },
        include: {
          tasks: {
            select: {
              id: true,
              title: true,
              status: true,
              priority: true,
              startDate: true,
              endDate: true,
              estimatedHours: true,
              actualHours: true,
              mainAssignee: {
                select: {
                  id: true,
                  name: true,
                  shortName: true
                }
              }
            }
          }
        },
        orderBy: { orderIndex: 'asc' }
      });

      // Get task dependencies if requested
      let dependencies = [];
      if (includeDependencies === 'true') {
        dependencies = await prisma.enhancedTaskDependency.findMany({
          where: {
            OR: [
              {
                predecessorTask: {
                  projectId
                }
              },
              {
                successorTask: {
                  projectId
                }
              }
            ]
          },
          include: {
            predecessorTask: {
              select: {
                id: true,
                title: true
              }
            },
            successorTask: {
              select: {
                id: true,
                title: true
              }
            }
          }
        });
      }

      // Build timeline structure
      const timelineData = {
        project: {
          ...project,
          timeline: timelineEntries.find(t => t.entityType === 'PROJECT' && t.entityId === projectId)
        },
        modules: modules.map(module => {
          const moduleTimeline = timelineEntries.find(t => t.entityType === 'MODULE' && t.entityId === module.id);
          
          // Calculate module dates from tasks if not explicitly set
          let calculatedStartDate = module.startDate;
          let calculatedEndDate = module.endDate;
          
          if (module.tasks.length > 0) {
            const taskDates = module.tasks
              .filter(task => task.startDate && task.endDate)
              .map(task => ({
                start: new Date(task.startDate),
                end: new Date(task.endDate)
              }));
            
            if (taskDates.length > 0) {
              const earliestStart = new Date(Math.min(...taskDates.map(d => d.start)));
              const latestEnd = new Date(Math.max(...taskDates.map(d => d.end)));
              
              if (!calculatedStartDate) calculatedStartDate = earliestStart;
              if (!calculatedEndDate) calculatedEndDate = latestEnd;
            }
          }

          return {
            ...module,
            calculatedStartDate,
            calculatedEndDate,
            timeline: moduleTimeline,
            tasks: module.tasks.map(task => ({
              ...task,
              timeline: timelineEntries.find(t => t.entityType === 'TASK' && t.entityId === task.id)
            }))
          };
        }),
        dependencies: includeDependencies === 'true' ? dependencies : [],
        statistics: this.calculateTimelineStatistics(modules)
      };

      res.json(timelineData);
    } catch (error) {
      console.error('Get project timeline error:', error);
      res.status(500).json({ error: 'Failed to fetch project timeline' });
    }
  }

  // Update timeline entry
  async updateTimelineEntry(req, res) {
    try {
      const { timelineId } = req.params;
      const {
        startDate,
        endDate,
        actualStart,
        actualEnd,
        completionPercentage,
        isMilestone
      } = req.body;

      // Get timeline entry to check permissions
      const timelineEntry = await prisma.projectTimeline.findUnique({
        where: { id: timelineId }
      });

      if (!timelineEntry) {
        return res.status(404).json({ error: 'Timeline entry not found' });
      }

      // Check if user can manage this project
      const canManage = await this.checkProjectManageAccess(req.user.id, timelineEntry.projectId);
      if (!canManage) {
        return res.status(403).json({ error: 'Insufficient permissions to update timeline' });
      }

      const updatedEntry = await prisma.projectTimeline.update({
        where: { id: timelineId },
        data: {
          ...(startDate && { startDate: new Date(startDate) }),
          ...(endDate && { endDate: new Date(endDate) }),
          ...(actualStart && { actualStart: new Date(actualStart) }),
          ...(actualEnd && { actualEnd: new Date(actualEnd) }),
          ...(completionPercentage !== undefined && { completionPercentage }),
          ...(isMilestone !== undefined && { isMilestone })
        }
      });

      // Update the corresponding entity if dates changed
      if (startDate || endDate) {
        await this.updateEntityDates(
          timelineEntry.entityType,
          timelineEntry.entityId,
          startDate ? new Date(startDate) : null,
          endDate ? new Date(endDate) : null
        );
      }

      res.json(updatedEntry);
    } catch (error) {
      console.error('Update timeline entry error:', error);
      res.status(500).json({ error: 'Failed to update timeline entry' });
    }
  }

  // Create timeline entry
  async createTimelineEntry(req, res) {
    try {
      const { projectId } = req.params;
      const {
        entityType,
        entityId,
        startDate,
        endDate,
        baselineStart,
        baselineEnd,
        isMilestone = false
      } = req.body;

      // Check if user can manage this project
      const canManage = await this.checkProjectManageAccess(req.user.id, projectId);
      if (!canManage) {
        return res.status(403).json({ error: 'Insufficient permissions to create timeline entry' });
      }

      // Validate entity exists
      const entity = await this.getEntity(entityType, entityId);
      if (!entity) {
        return res.status(400).json({ error: 'Invalid entity specified' });
      }

      const timelineEntry = await prisma.projectTimeline.create({
        data: {
          projectId,
          entityType,
          entityId,
          startDate: new Date(startDate),
          endDate: new Date(endDate),
          baselineStart: baselineStart ? new Date(baselineStart) : new Date(startDate),
          baselineEnd: baselineEnd ? new Date(baselineEnd) : new Date(endDate),
          isMilestone
        }
      });

      res.status(201).json(timelineEntry);
    } catch (error) {
      console.error('Create timeline entry error:', error);
      res.status(500).json({ error: 'Failed to create timeline entry' });
    }
  }

  // Get critical path analysis
  async getCriticalPath(req, res) {
    try {
      const { projectId } = req.params;

      // Check if user has access to this project
      const hasAccess = await this.checkProjectAccess(req.user.id, projectId);
      if (!hasAccess) {
        return res.status(403).json({ error: 'No access to this project' });
      }

      // Get all tasks with dependencies
      const tasks = await prisma.task.findMany({
        where: { projectId },
        include: {
          predecessorDependencies: {
            include: {
              successorTask: {
                select: {
                  id: true,
                  title: true,
                  estimatedHours: true
                }
              }
            }
          },
          successorDependencies: {
            include: {
              predecessorTask: {
                select: {
                  id: true,
                  title: true,
                  estimatedHours: true
                }
              }
            }
          }
        }
      });

      // Calculate critical path using CPM algorithm
      const criticalPath = this.calculateCriticalPath(tasks);

      res.json({
        criticalPath,
        totalDuration: criticalPath.reduce((sum, task) => sum + (task.estimatedHours || 0), 0),
        criticalTasks: criticalPath.map(task => task.id)
      });
    } catch (error) {
      console.error('Get critical path error:', error);
      res.status(500).json({ error: 'Failed to calculate critical path' });
    }
  }

  // Get timeline conflicts and issues
  async getTimelineIssues(req, res) {
    try {
      const { projectId } = req.params;

      // Check if user has access to this project
      const hasAccess = await this.checkProjectAccess(req.user.id, projectId);
      if (!hasAccess) {
        return res.status(403).json({ error: 'No access to this project' });
      }

      const issues = [];

      // Check for overdue tasks
      const overdueTasks = await prisma.task.findMany({
        where: {
          projectId,
          status: { not: 'COMPLETED' },
          endDate: { lt: new Date() }
        },
        select: {
          id: true,
          title: true,
          endDate: true,
          status: true,
          mainAssignee: {
            select: { name: true }
          }
        }
      });

      issues.push(...overdueTasks.map(task => ({
        type: 'OVERDUE_TASK',
        severity: 'HIGH',
        entityType: 'TASK',
        entityId: task.id,
        title: `Task "${task.title}" is overdue`,
        description: `Due date: ${task.endDate.toISOString().split('T')[0]}`,
        assignee: task.mainAssignee?.name
      })));

      // Check for dependency conflicts
      const dependencyConflicts = await this.findDependencyConflicts(projectId);
      issues.push(...dependencyConflicts);

      // Check for resource overallocation
      const resourceConflicts = await this.findResourceConflicts(projectId);
      issues.push(...resourceConflicts);

      res.json({
        issues,
        summary: {
          total: issues.length,
          high: issues.filter(i => i.severity === 'HIGH').length,
          medium: issues.filter(i => i.severity === 'MEDIUM').length,
          low: issues.filter(i => i.severity === 'LOW').length
        }
      });
    } catch (error) {
      console.error('Get timeline issues error:', error);
      res.status(500).json({ error: 'Failed to fetch timeline issues' });
    }
  }

  // Helper methods
  calculateTimelineStatistics(modules) {
    const totalTasks = modules.reduce((sum, module) => sum + module.tasks.length, 0);
    const completedTasks = modules.reduce((sum, module) => 
      sum + module.tasks.filter(task => task.status === 'COMPLETED').length, 0
    );
    const totalEstimatedHours = modules.reduce((sum, module) => 
      sum + module.tasks.reduce((taskSum, task) => taskSum + (task.estimatedHours || 0), 0), 0
    );
    const totalActualHours = modules.reduce((sum, module) => 
      sum + module.tasks.reduce((taskSum, task) => taskSum + (task.actualHours || 0), 0), 0
    );

    return {
      totalTasks,
      completedTasks,
      completionPercentage: totalTasks > 0 ? Math.round((completedTasks / totalTasks) * 100) : 0,
      totalEstimatedHours,
      totalActualHours,
      hoursVariance: totalActualHours - totalEstimatedHours,
      efficiencyRatio: totalEstimatedHours > 0 ? totalActualHours / totalEstimatedHours : 0
    };
  }

  calculateCriticalPath(tasks) {
    // Simplified CPM algorithm - in production, use a more robust implementation
    const taskMap = new Map(tasks.map(task => [task.id, task]));
    const visited = new Set();
    const criticalPath = [];

    // Find tasks with no predecessors (start tasks)
    const startTasks = tasks.filter(task => task.predecessorDependencies.length === 0);

    // For simplicity, return the longest path by estimated hours
    // In a full implementation, this would use proper CPM calculations
    const longestPath = this.findLongestPath(startTasks, taskMap, visited);
    
    return longestPath;
  }

  findLongestPath(tasks, taskMap, visited) {
    // Simplified longest path calculation
    return tasks.sort((a, b) => (b.estimatedHours || 0) - (a.estimatedHours || 0));
  }

  async findDependencyConflicts(projectId) {
    // Implementation for finding dependency conflicts
    return [];
  }

  async findResourceConflicts(projectId) {
    // Implementation for finding resource conflicts
    return [];
  }

  async getEntity(entityType, entityId) {
    switch (entityType) {
      case 'PROJECT':
        return await prisma.project.findUnique({ where: { id: entityId } });
      case 'TASK':
        return await prisma.task.findUnique({ where: { id: entityId } });
      case 'MODULE':
        return await prisma.enhancedModule.findUnique({ where: { id: entityId } });
      default:
        return null;
    }
  }

  async updateEntityDates(entityType, entityId, startDate, endDate) {
    const updateData = {};
    if (startDate) updateData.startDate = startDate;
    if (endDate) updateData.endDate = endDate;

    switch (entityType) {
      case 'PROJECT':
        return await prisma.project.update({ where: { id: entityId }, data: updateData });
      case 'TASK':
        return await prisma.task.update({ where: { id: entityId }, data: updateData });
      case 'MODULE':
        return await prisma.enhancedModule.update({ where: { id: entityId }, data: updateData });
    }
  }

  async checkProjectAccess(userId, projectId) {
    const assignment = await prisma.userProjectAssignment.findFirst({
      where: { userId, projectId, assignmentStatus: 'ASSIGNED' }
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

module.exports = new TimelineController();
