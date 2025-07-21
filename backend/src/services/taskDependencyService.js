const { PrismaClient } = require('@prisma/client');
const logger = require('../config/logger');

const prisma = new PrismaClient();

class TaskDependencyService {
  // Calculate critical path for a project
  async calculateCriticalPath(projectId) {
    try {
      // Get all tasks for the project with their dependencies
      const tasks = await prisma.task.findMany({
        where: { projectId },
        include: {
          preDependencies: {
            include: {
              preTask: {
                select: { id: true, title: true, estimatedHours: true, status: true }
              }
            }
          },
          postDependencies: {
            include: {
              postTask: {
                select: { id: true, title: true, estimatedHours: true, status: true }
              }
            }
          }
        }
      });

      if (tasks.length === 0) {
        return { criticalPath: [], totalDuration: 0, tasks: [] };
      }

      // Build adjacency list for the dependency graph
      const graph = new Map();
      const inDegree = new Map();
      const taskMap = new Map();

      // Initialize graph
      tasks.forEach(task => {
        graph.set(task.id, []);
        inDegree.set(task.id, 0);
        taskMap.set(task.id, {
          ...task,
          earliestStart: 0,
          earliestFinish: 0,
          latestStart: 0,
          latestFinish: 0,
          slack: 0,
          duration: task.estimatedHours || 0
        });
      });

      // Build dependency graph
      tasks.forEach(task => {
        task.preDependencies.forEach(dep => {
          graph.get(dep.preTaskId).push(task.id);
          inDegree.set(task.id, inDegree.get(task.id) + 1);
        });
      });

      // Forward pass - calculate earliest start and finish times
      const queue = [];
      tasks.forEach(task => {
        if (inDegree.get(task.id) === 0) {
          queue.push(task.id);
        }
      });

      while (queue.length > 0) {
        const currentTaskId = queue.shift();
        const currentTask = taskMap.get(currentTaskId);
        
        currentTask.earliestFinish = currentTask.earliestStart + currentTask.duration;

        // Update successors
        graph.get(currentTaskId).forEach(successorId => {
          const successor = taskMap.get(successorId);
          successor.earliestStart = Math.max(
            successor.earliestStart,
            currentTask.earliestFinish
          );
          
          inDegree.set(successorId, inDegree.get(successorId) - 1);
          if (inDegree.get(successorId) === 0) {
            queue.push(successorId);
          }
        });
      }

      // Find project end time
      const projectEndTime = Math.max(...Array.from(taskMap.values()).map(t => t.earliestFinish));

      // Backward pass - calculate latest start and finish times
      const reversedTasks = Array.from(taskMap.values()).sort((a, b) => b.earliestFinish - a.earliestFinish);
      
      // Initialize latest finish times for tasks with no successors
      reversedTasks.forEach(task => {
        if (graph.get(task.id).length === 0) {
          task.latestFinish = projectEndTime;
        }
      });

      reversedTasks.forEach(task => {
        if (task.latestFinish === 0) {
          // Find minimum latest start of successors
          const successors = graph.get(task.id);
          if (successors.length > 0) {
            task.latestFinish = Math.min(...successors.map(sId => taskMap.get(sId).latestStart));
          }
        }
        
        task.latestStart = task.latestFinish - task.duration;
        task.slack = task.latestStart - task.earliestStart;

        // Update predecessors
        const predecessors = tasks.filter(t => 
          t.postDependencies.some(dep => dep.postTaskId === task.id)
        );
        
        predecessors.forEach(pred => {
          const predTask = taskMap.get(pred.id);
          if (predTask.latestFinish === 0 || predTask.latestFinish > task.latestStart) {
            predTask.latestFinish = task.latestStart;
          }
        });
      });

      // Identify critical path (tasks with zero slack)
      const criticalTasks = Array.from(taskMap.values()).filter(task => task.slack === 0);
      
      // Sort critical tasks by earliest start time to get the path
      const criticalPath = criticalTasks.sort((a, b) => a.earliestStart - b.earliestStart);

      return {
        criticalPath: criticalPath.map(task => ({
          id: task.id,
          title: task.title,
          duration: task.duration,
          earliestStart: task.earliestStart,
          earliestFinish: task.earliestFinish,
          slack: task.slack
        })),
        totalDuration: projectEndTime,
        tasks: Array.from(taskMap.values()).map(task => ({
          id: task.id,
          title: task.title,
          duration: task.duration,
          earliestStart: task.earliestStart,
          earliestFinish: task.earliestFinish,
          latestStart: task.latestStart,
          latestFinish: task.latestFinish,
          slack: task.slack,
          isCritical: task.slack === 0
        }))
      };
    } catch (error) {
      logger.error('Error calculating critical path:', error);
      throw error;
    }
  }

  // Validate dependency to prevent cycles
  async validateDependency(preTaskId, postTaskId) {
    try {
      // Check if adding this dependency would create a cycle
      const visited = new Set();
      const recursionStack = new Set();

      const hasCycle = async (taskId, targetId) => {
        if (recursionStack.has(taskId)) {
          return true; // Cycle detected
        }
        if (visited.has(taskId)) {
          return false;
        }

        visited.add(taskId);
        recursionStack.add(taskId);

        // Get all tasks that depend on this task
        const dependencies = await prisma.taskDependency.findMany({
          where: { preTaskId: taskId },
          select: { postTaskId: true }
        });

        for (const dep of dependencies) {
          if (dep.postTaskId === targetId || await hasCycle(dep.postTaskId, targetId)) {
            return true;
          }
        }

        recursionStack.delete(taskId);
        return false;
      };

      return !(await hasCycle(postTaskId, preTaskId));
    } catch (error) {
      logger.error('Error validating dependency:', error);
      throw error;
    }
  }

  // Get dependency chain for a task
  async getDependencyChain(taskId) {
    try {
      const visited = new Set();
      const chain = {
        predecessors: [],
        successors: []
      };

      // Get all predecessors
      const getPredecessors = async (currentTaskId, depth = 0) => {
        if (visited.has(currentTaskId) || depth > 10) return; // Prevent infinite loops
        visited.add(currentTaskId);

        const dependencies = await prisma.taskDependency.findMany({
          where: { postTaskId: currentTaskId },
          include: {
            preTask: {
              select: { id: true, title: true, status: true, estimatedHours: true }
            }
          }
        });

        for (const dep of dependencies) {
          chain.predecessors.push({
            ...dep.preTask,
            dependencyType: dep.dependencyType,
            depth
          });
          await getPredecessors(dep.preTaskId, depth + 1);
        }
      };

      // Get all successors
      visited.clear();
      const getSuccessors = async (currentTaskId, depth = 0) => {
        if (visited.has(currentTaskId) || depth > 10) return;
        visited.add(currentTaskId);

        const dependencies = await prisma.taskDependency.findMany({
          where: { preTaskId: currentTaskId },
          include: {
            postTask: {
              select: { id: true, title: true, status: true, estimatedHours: true }
            }
          }
        });

        for (const dep of dependencies) {
          chain.successors.push({
            ...dep.postTask,
            dependencyType: dep.dependencyType,
            depth
          });
          await getSuccessors(dep.postTaskId, depth + 1);
        }
      };

      await getPredecessors(taskId);
      await getSuccessors(taskId);

      return chain;
    } catch (error) {
      logger.error('Error getting dependency chain:', error);
      throw error;
    }
  }

  // Get tasks that can be started (no incomplete dependencies)
  async getAvailableTasks(projectId, userId = null) {
    try {
      const whereClause = { projectId };
      if (userId) {
        whereClause.OR = [
          { mainAssigneeId: userId },
          { assignments: { some: { userId } } }
        ];
      }

      const tasks = await prisma.task.findMany({
        where: {
          ...whereClause,
          status: { not: 'COMPLETED' }
        },
        include: {
          preDependencies: {
            include: {
              preTask: {
                select: { id: true, status: true }
              }
            }
          }
        }
      });

      // Filter tasks that have all dependencies completed
      const availableTasks = tasks.filter(task => {
        return task.preDependencies.every(dep => dep.preTask.status === 'COMPLETED');
      });

      return availableTasks;
    } catch (error) {
      logger.error('Error getting available tasks:', error);
      throw error;
    }
  }

  // Get dependency statistics for a project
  async getDependencyStats(projectId) {
    try {
      const [totalTasks, tasksWithDependencies, totalDependencies, blockedTasks] = await Promise.all([
        prisma.task.count({ where: { projectId } }),
        prisma.task.count({
          where: {
            projectId,
            OR: [
              { preDependencies: { some: {} } },
              { postDependencies: { some: {} } }
            ]
          }
        }),
        prisma.taskDependency.count({
          where: {
            OR: [
              { preTask: { projectId } },
              { postTask: { projectId } }
            ]
          }
        }),
        this.getBlockedTasks(projectId)
      ]);

      return {
        totalTasks,
        tasksWithDependencies,
        totalDependencies,
        blockedTasksCount: blockedTasks.length,
        dependencyRatio: totalTasks > 0 ? (tasksWithDependencies / totalTasks) : 0
      };
    } catch (error) {
      logger.error('Error getting dependency stats:', error);
      throw error;
    }
  }

  // Get tasks that are blocked by incomplete dependencies
  async getBlockedTasks(projectId) {
    try {
      const tasks = await prisma.task.findMany({
        where: {
          projectId,
          status: { notIn: ['COMPLETED', 'CANCELLED'] },
          preDependencies: { some: {} }
        },
        include: {
          preDependencies: {
            include: {
              preTask: {
                select: { id: true, title: true, status: true }
              }
            }
          }
        }
      });

      // Filter tasks that have incomplete dependencies
      const blockedTasks = tasks.filter(task => {
        return task.preDependencies.some(dep => dep.preTask.status !== 'COMPLETED');
      });

      return blockedTasks.map(task => ({
        id: task.id,
        title: task.title,
        status: task.status,
        blockingDependencies: task.preDependencies
          .filter(dep => dep.preTask.status !== 'COMPLETED')
          .map(dep => ({
            id: dep.preTask.id,
            title: dep.preTask.title,
            status: dep.preTask.status
          }))
      }));
    } catch (error) {
      logger.error('Error getting blocked tasks:', error);
      throw error;
    }
  }
}

module.exports = new TaskDependencyService();
