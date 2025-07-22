const { PrismaClient } = require('@prisma/client');
const logger = require('../config/logger');
const taskDependencyService = require('../services/taskDependencyService');
const activityService = require('../services/activityService');

const prisma = new PrismaClient();

class TaskDependencyController {
  // Get critical path for a project
  async getCriticalPath(req, res) {
    try {
      const { projectId } = req.params;

      // Verify user has access to the project
      if (!req.user.isAdmin) {
        const membership = await prisma.projectMember.findFirst({
          where: {
            projectId,
            userId: req.user.id
          }
        });

        if (!membership) {
          return res.status(403).json({ error: 'Access denied to this project' });
        }
      }

      const criticalPath = await taskDependencyService.calculateCriticalPath(projectId);
      res.json(criticalPath);
    } catch (error) {
      logger.error('Error getting critical path:', error);
      res.status(500).json({ error: 'Failed to calculate critical path' });
    }
  }

  // Get dependency chain for a task
  async getDependencyChain(req, res) {
    try {
      const { taskId } = req.params;

      // Verify user has access to the task
      const task = await prisma.task.findFirst({
        where: {
          id: taskId,
          OR: [
            { createdById: req.user.id },
            { mainAssigneeId: req.user.id },
            {
              assignments: {
                some: { userId: req.user.id }
              }
            },
            {
              project: {
                members: {
                  some: { userId: req.user.id }
                }
              }
            }
          ]
        }
      });

      if (!task) {
        return res.status(404).json({ error: 'Task not found or access denied' });
      }

      const dependencyChain = await taskDependencyService.getDependencyChain(taskId);
      res.json(dependencyChain);
    } catch (error) {
      logger.error('Error getting dependency chain:', error);
      res.status(500).json({ error: 'Failed to get dependency chain' });
    }
  }

  // Get available tasks (no incomplete dependencies)
  async getAvailableTasks(req, res) {
    try {
      const { projectId } = req.params;
      const { userId } = req.query;

      // Verify user has access to the project
      if (!req.user.isAdmin) {
        const membership = await prisma.projectMember.findFirst({
          where: {
            projectId,
            userId: req.user.id
          }
        });

        if (!membership) {
          return res.status(403).json({ error: 'Access denied to this project' });
        }
      }

      const availableTasks = await taskDependencyService.getAvailableTasks(
        projectId,
        userId || req.user.id
      );

      res.json(availableTasks);
    } catch (error) {
      logger.error('Error getting available tasks:', error);
      res.status(500).json({ error: 'Failed to get available tasks' });
    }
  }

  // Get blocked tasks
  async getBlockedTasks(req, res) {
    try {
      const { projectId } = req.params;

      // Verify user has access to the project
      if (!req.user.isAdmin) {
        const membership = await prisma.projectMember.findFirst({
          where: {
            projectId,
            userId: req.user.id
          }
        });

        if (!membership) {
          return res.status(403).json({ error: 'Access denied to this project' });
        }
      }

      const blockedTasks = await taskDependencyService.getBlockedTasks(projectId);
      res.json(blockedTasks);
    } catch (error) {
      logger.error('Error getting blocked tasks:', error);
      res.status(500).json({ error: 'Failed to get blocked tasks' });
    }
  }

  // Get dependency statistics
  async getDependencyStats(req, res) {
    try {
      const { projectId } = req.params;

      // Verify user has access to the project
      if (!req.user.isAdmin) {
        const membership = await prisma.projectMember.findFirst({
          where: {
            projectId,
            userId: req.user.id
          }
        });

        if (!membership) {
          return res.status(403).json({ error: 'Access denied to this project' });
        }
      }

      const stats = await taskDependencyService.getDependencyStats(projectId);
      res.json(stats);
    } catch (error) {
      logger.error('Error getting dependency stats:', error);
      res.status(500).json({ error: 'Failed to get dependency statistics' });
    }
  }

  // Validate dependency before adding
  async validateDependency(req, res) {
    try {
      const { preTaskId, postTaskId } = req.body;

      // Verify user has access to both tasks
      const [preTask, postTask] = await Promise.all([
        prisma.task.findFirst({
          where: {
            id: preTaskId,
            OR: [
              { createdById: req.user.id },
              { mainAssigneeId: req.user.id },
              {
                project: {
                  members: {
                    some: { userId: req.user.id }
                  }
                }
              }
            ]
          }
        }),
        prisma.task.findFirst({
          where: {
            id: postTaskId,
            OR: [
              { createdById: req.user.id },
              { mainAssigneeId: req.user.id },
              {
                project: {
                  members: {
                    some: { userId: req.user.id }
                  }
                }
              }
            ]
          }
        })
      ]);

      if (!preTask || !postTask) {
        return res.status(404).json({ error: 'One or both tasks not found or access denied' });
      }

      const isValid = await taskDependencyService.validateDependency(preTaskId, postTaskId);
      
      res.json({
        isValid,
        message: isValid ? 'Dependency is valid' : 'Adding this dependency would create a circular dependency'
      });
    } catch (error) {
      logger.error('Error validating dependency:', error);
      res.status(500).json({ error: 'Failed to validate dependency' });
    }
  }

  // Get dependency graph data for visualization
  async getDependencyGraph(req, res) {
    try {
      const { projectId } = req.params;

      // Verify user has access to the project
      if (!req.user.isAdmin) {
        const membership = await prisma.projectMember.findFirst({
          where: {
            projectId,
            userId: req.user.id
          }
        });

        if (!membership) {
          return res.status(403).json({ error: 'Access denied to this project' });
        }
      }

      // Get all tasks with their dependencies
      const tasks = await prisma.task.findMany({
        where: { projectId },
        include: {
          preDependencies: {
            include: {
              preTask: {
                select: { id: true, title: true, status: true }
              }
            }
          },
          postDependencies: {
            include: {
              postTask: {
                select: { id: true, title: true, status: true }
              }
            }
          }
        }
      });

      // Get critical path data
      const criticalPathData = await taskDependencyService.calculateCriticalPath(projectId);

      // Format data for graph visualization
      const nodes = tasks.map(task => ({
        id: task.id,
        title: task.title,
        status: task.status,
        estimatedHours: task.estimatedHours,
        isCritical: criticalPathData.tasks.find(t => t.id === task.id)?.isCritical || false,
        slack: criticalPathData.tasks.find(t => t.id === task.id)?.slack || 0
      }));

      const edges = [];
      tasks.forEach(task => {
        task.preDependencies.forEach(dep => {
          edges.push({
            id: dep.id,
            source: dep.preTaskId,
            target: task.id,
            type: dep.dependencyType,
            isCritical: criticalPathData.criticalPath.some(cp => cp.id === task.id || cp.id === dep.preTaskId)
          });
        });
      });

      res.json({
        nodes,
        edges,
        criticalPath: criticalPathData.criticalPath,
        totalDuration: criticalPathData.totalDuration
      });
    } catch (error) {
      logger.error('Error getting dependency graph:', error);
      res.status(500).json({ error: 'Failed to get dependency graph' });
    }
  }

  // Auto-suggest dependencies based on task relationships
  async suggestDependencies(req, res) {
    try {
      const { taskId } = req.params;

      // Verify user has access to the task
      const task = await prisma.task.findFirst({
        where: {
          id: taskId,
          OR: [
            { createdById: req.user.id },
            { mainAssigneeId: req.user.id },
            {
              project: {
                members: {
                  some: { userId: req.user.id }
                }
              }
            }
          ]
        },
        include: {
          project: true,
          subProject: true
        }
      });

      if (!task) {
        return res.status(404).json({ error: 'Task not found or access denied' });
      }

      // Find potential dependencies based on:
      // 1. Tasks in the same project/sub-project
      // 2. Tasks with similar types that typically have dependencies
      // 3. Tasks assigned to the same user
      const potentialDependencies = await prisma.task.findMany({
        where: {
          AND: [
            { id: { not: taskId } },
            {
              OR: [
                { projectId: task.projectId },
                { subProjectId: task.subProjectId }
              ]
            },
            {
              NOT: {
                OR: [
                  { preDependencies: { some: { postTaskId: taskId } } },
                  { postDependencies: { some: { preTaskId: taskId } } }
                ]
              }
            }
          ]
        },
        select: {
          id: true,
          title: true,
          taskType: true,
          status: true,
          mainAssigneeId: true,
          estimatedHours: true
        },
        take: 10
      });

      // Score suggestions based on relevance
      const suggestions = potentialDependencies.map(potentialDep => {
        let score = 0;
        let reason = [];

        // Same sub-project gets higher score
        if (potentialDep.subProjectId === task.subProjectId) {
          score += 3;
          reason.push('Same sub-project');
        }

        // Related task types
        const typeRelations = {
          'REQUIREMENT': ['DESIGN'],
          'DESIGN': ['CODING'],
          'CODING': ['TESTING'],
          'TESTING': ['DOCUMENTATION']
        };

        if (typeRelations[potentialDep.taskType]?.includes(task.taskType)) {
          score += 2;
          reason.push('Sequential task type');
        }

        // Same assignee
        if (potentialDep.mainAssigneeId === task.mainAssigneeId) {
          score += 1;
          reason.push('Same assignee');
        }

        return {
          ...potentialDep,
          score,
          reason: reason.join(', ')
        };
      });

      // Sort by score and return top suggestions
      suggestions.sort((a, b) => b.score - a.score);

      res.json(suggestions.slice(0, 5));
    } catch (error) {
      logger.error('Error suggesting dependencies:', error);
      res.status(500).json({ error: 'Failed to suggest dependencies' });
    }
  }
}

module.exports = new TaskDependencyController();
