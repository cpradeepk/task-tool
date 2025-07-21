const { PrismaClient } = require('@prisma/client');
const logger = require('../config/logger');

const prisma = new PrismaClient();

class TimeTrackingService {
  // Start a timer for a task
  async startTimer(userId, taskId, description = null) {
    try {
      // Check if user already has an active timer
      const activeTimer = await prisma.timeEntry.findFirst({
        where: {
          userId,
          endTime: null
        }
      });

      if (activeTimer) {
        throw new Error('User already has an active timer. Please stop the current timer first.');
      }

      // Verify user has access to the task
      const task = await prisma.task.findFirst({
        where: {
          id: taskId,
          OR: [
            { createdById: userId },
            { mainAssigneeId: userId },
            {
              assignments: {
                some: { userId }
              }
            }
          ]
        }
      });

      if (!task) {
        throw new Error('Task not found or access denied');
      }

      const timeEntry = await prisma.timeEntry.create({
        data: {
          taskId,
          userId,
          description: description || `Working on ${task.title}`,
          startTime: new Date(),
          date: new Date()
        },
        include: {
          task: {
            select: { id: true, title: true }
          },
          user: {
            select: { id: true, name: true, email: true }
          }
        }
      });

      logger.info(`Timer started for task ${taskId} by user ${userId}`);
      return timeEntry;
    } catch (error) {
      logger.error('Error starting timer:', error);
      throw error;
    }
  }

  // Stop the active timer
  async stopTimer(userId) {
    try {
      const activeTimer = await prisma.timeEntry.findFirst({
        where: {
          userId,
          endTime: null
        },
        include: {
          task: {
            select: { id: true, title: true }
          }
        }
      });

      if (!activeTimer) {
        throw new Error('No active timer found');
      }

      const endTime = new Date();
      const hours = (endTime - activeTimer.startTime) / (1000 * 60 * 60); // Convert to hours

      const updatedTimeEntry = await prisma.timeEntry.update({
        where: { id: activeTimer.id },
        data: {
          endTime,
          hours
        },
        include: {
          task: {
            select: { id: true, title: true }
          },
          user: {
            select: { id: true, name: true, email: true }
          }
        }
      });

      // Update task's actual hours
      await this.updateTaskActualHours(activeTimer.taskId);

      logger.info(`Timer stopped for task ${activeTimer.taskId} by user ${userId}. Duration: ${hours.toFixed(2)} hours`);
      return updatedTimeEntry;
    } catch (error) {
      logger.error('Error stopping timer:', error);
      throw error;
    }
  }

  // Get active timer for a user
  async getActiveTimer(userId) {
    try {
      const activeTimer = await prisma.timeEntry.findFirst({
        where: {
          userId,
          endTime: null
        },
        include: {
          task: {
            select: { id: true, title: true, project: { select: { name: true } } }
          }
        }
      });

      if (activeTimer) {
        const currentTime = new Date();
        const elapsedHours = (currentTime - activeTimer.startTime) / (1000 * 60 * 60);
        
        return {
          ...activeTimer,
          elapsedHours
        };
      }

      return null;
    } catch (error) {
      logger.error('Error getting active timer:', error);
      throw error;
    }
  }

  // Update task's actual hours based on time entries
  async updateTaskActualHours(taskId) {
    try {
      const totalHours = await prisma.timeEntry.aggregate({
        where: { 
          taskId,
          endTime: { not: null } // Only completed time entries
        },
        _sum: { hours: true }
      });

      await prisma.task.update({
        where: { id: taskId },
        data: { actualHours: totalHours._sum.hours || 0 }
      });

      return totalHours._sum.hours || 0;
    } catch (error) {
      logger.error('Error updating task actual hours:', error);
      throw error;
    }
  }

  // Get time tracking report for a user
  async getUserTimeReport(userId, startDate, endDate) {
    try {
      const timeEntries = await prisma.timeEntry.findMany({
        where: {
          userId,
          date: {
            gte: new Date(startDate),
            lte: new Date(endDate)
          },
          endTime: { not: null }
        },
        include: {
          task: {
            select: {
              id: true,
              title: true,
              project: { select: { id: true, name: true } },
              subProject: { select: { id: true, name: true } }
            }
          }
        },
        orderBy: { date: 'desc' }
      });

      // Group by date
      const dailyReport = {};
      let totalHours = 0;

      timeEntries.forEach(entry => {
        const dateKey = entry.date.toISOString().split('T')[0];
        if (!dailyReport[dateKey]) {
          dailyReport[dateKey] = {
            date: dateKey,
            entries: [],
            totalHours: 0
          };
        }
        
        dailyReport[dateKey].entries.push(entry);
        dailyReport[dateKey].totalHours += entry.hours;
        totalHours += entry.hours;
      });

      // Group by project
      const projectReport = {};
      timeEntries.forEach(entry => {
        const projectId = entry.task.project?.id || 'no-project';
        const projectName = entry.task.project?.name || 'No Project';
        
        if (!projectReport[projectId]) {
          projectReport[projectId] = {
            projectId,
            projectName,
            totalHours: 0,
            tasks: {}
          };
        }
        
        projectReport[projectId].totalHours += entry.hours;
        
        if (!projectReport[projectId].tasks[entry.taskId]) {
          projectReport[projectId].tasks[entry.taskId] = {
            taskId: entry.taskId,
            taskTitle: entry.task.title,
            totalHours: 0,
            entries: []
          };
        }
        
        projectReport[projectId].tasks[entry.taskId].totalHours += entry.hours;
        projectReport[projectId].tasks[entry.taskId].entries.push(entry);
      });

      return {
        totalHours,
        dailyReport: Object.values(dailyReport),
        projectReport: Object.values(projectReport).map(project => ({
          ...project,
          tasks: Object.values(project.tasks)
        })),
        timeEntries
      };
    } catch (error) {
      logger.error('Error getting user time report:', error);
      throw error;
    }
  }

  // Get project time tracking summary
  async getProjectTimeReport(projectId, startDate, endDate) {
    try {
      const timeEntries = await prisma.timeEntry.findMany({
        where: {
          task: { projectId },
          date: {
            gte: new Date(startDate),
            lte: new Date(endDate)
          },
          endTime: { not: null }
        },
        include: {
          task: {
            select: {
              id: true,
              title: true,
              estimatedHours: true,
              optimisticHours: true,
              pessimisticHours: true,
              mostLikelyHours: true
            }
          },
          user: {
            select: { id: true, name: true, email: true }
          }
        }
      });

      // Group by task
      const taskReport = {};
      let totalActualHours = 0;
      let totalEstimatedHours = 0;

      timeEntries.forEach(entry => {
        const taskId = entry.taskId;
        
        if (!taskReport[taskId]) {
          taskReport[taskId] = {
            taskId,
            taskTitle: entry.task.title,
            estimatedHours: entry.task.estimatedHours || 0,
            optimisticHours: entry.task.optimisticHours,
            pessimisticHours: entry.task.pessimisticHours,
            mostLikelyHours: entry.task.mostLikelyHours,
            actualHours: 0,
            variance: 0,
            users: {},
            entries: []
          };
          
          totalEstimatedHours += entry.task.estimatedHours || 0;
        }
        
        taskReport[taskId].actualHours += entry.hours;
        taskReport[taskId].entries.push(entry);
        totalActualHours += entry.hours;
        
        // Group by user
        if (!taskReport[taskId].users[entry.userId]) {
          taskReport[taskId].users[entry.userId] = {
            userId: entry.userId,
            userName: entry.user.name,
            hours: 0
          };
        }
        taskReport[taskId].users[entry.userId].hours += entry.hours;
      });

      // Calculate variances
      Object.values(taskReport).forEach(task => {
        task.variance = task.actualHours - task.estimatedHours;
        task.variancePercentage = task.estimatedHours > 0 
          ? ((task.variance / task.estimatedHours) * 100) 
          : 0;
        task.users = Object.values(task.users);
      });

      // Group by user
      const userReport = {};
      timeEntries.forEach(entry => {
        if (!userReport[entry.userId]) {
          userReport[entry.userId] = {
            userId: entry.userId,
            userName: entry.user.name,
            totalHours: 0,
            tasks: {}
          };
        }
        
        userReport[entry.userId].totalHours += entry.hours;
        
        if (!userReport[entry.userId].tasks[entry.taskId]) {
          userReport[entry.userId].tasks[entry.taskId] = {
            taskId: entry.taskId,
            taskTitle: entry.task.title,
            hours: 0
          };
        }
        
        userReport[entry.userId].tasks[entry.taskId].hours += entry.hours;
      });

      return {
        summary: {
          totalActualHours,
          totalEstimatedHours,
          totalVariance: totalActualHours - totalEstimatedHours,
          totalVariancePercentage: totalEstimatedHours > 0 
            ? (((totalActualHours - totalEstimatedHours) / totalEstimatedHours) * 100) 
            : 0
        },
        taskReport: Object.values(taskReport),
        userReport: Object.values(userReport).map(user => ({
          ...user,
          tasks: Object.values(user.tasks)
        }))
      };
    } catch (error) {
      logger.error('Error getting project time report:', error);
      throw error;
    }
  }

  // Get PERT vs Actual comparison
  async getPERTComparison(projectId) {
    try {
      const tasks = await prisma.task.findMany({
        where: { projectId },
        select: {
          id: true,
          title: true,
          optimisticHours: true,
          pessimisticHours: true,
          mostLikelyHours: true,
          estimatedHours: true,
          actualHours: true,
          status: true
        }
      });

      const comparison = tasks.map(task => {
        const pertEstimate = task.estimatedHours || 0;
        const actualHours = task.actualHours || 0;
        const variance = actualHours - pertEstimate;
        const variancePercentage = pertEstimate > 0 ? ((variance / pertEstimate) * 100) : 0;

        // Calculate accuracy category
        let accuracyCategory = 'Unknown';
        if (task.status === 'COMPLETED') {
          if (Math.abs(variancePercentage) <= 10) {
            accuracyCategory = 'Excellent';
          } else if (Math.abs(variancePercentage) <= 25) {
            accuracyCategory = 'Good';
          } else if (Math.abs(variancePercentage) <= 50) {
            accuracyCategory = 'Fair';
          } else {
            accuracyCategory = 'Poor';
          }
        } else if (actualHours > 0) {
          accuracyCategory = 'In Progress';
        }

        return {
          taskId: task.id,
          taskTitle: task.title,
          optimisticHours: task.optimisticHours,
          pessimisticHours: task.pessimisticHours,
          mostLikelyHours: task.mostLikelyHours,
          pertEstimate,
          actualHours,
          variance,
          variancePercentage,
          accuracyCategory,
          status: task.status
        };
      });

      // Calculate overall statistics
      const completedTasks = comparison.filter(t => t.status === 'COMPLETED');
      const totalPertEstimate = comparison.reduce((sum, t) => sum + t.pertEstimate, 0);
      const totalActualHours = comparison.reduce((sum, t) => sum + t.actualHours, 0);
      
      const averageVariance = completedTasks.length > 0 
        ? completedTasks.reduce((sum, t) => sum + Math.abs(t.variancePercentage), 0) / completedTasks.length
        : 0;

      return {
        summary: {
          totalTasks: tasks.length,
          completedTasks: completedTasks.length,
          totalPertEstimate,
          totalActualHours,
          totalVariance: totalActualHours - totalPertEstimate,
          averageVariancePercentage: averageVariance
        },
        tasks: comparison
      };
    } catch (error) {
      logger.error('Error getting PERT comparison:', error);
      throw error;
    }
  }

  // Get time tracking analytics
  async getTimeAnalytics(projectId, period = 'week') {
    try {
      const now = new Date();
      let startDate;

      switch (period) {
        case 'day':
          startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
          break;
        case 'week':
          startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
          break;
        case 'month':
          startDate = new Date(now.getFullYear(), now.getMonth(), 1);
          break;
        case 'quarter':
          startDate = new Date(now.getFullYear(), Math.floor(now.getMonth() / 3) * 3, 1);
          break;
        default:
          startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      }

      const timeEntries = await prisma.timeEntry.findMany({
        where: {
          task: { projectId },
          date: { gte: startDate },
          endTime: { not: null }
        },
        include: {
          task: { select: { id: true, title: true } },
          user: { select: { id: true, name: true } }
        }
      });

      // Daily breakdown
      const dailyBreakdown = {};
      timeEntries.forEach(entry => {
        const dateKey = entry.date.toISOString().split('T')[0];
        if (!dailyBreakdown[dateKey]) {
          dailyBreakdown[dateKey] = 0;
        }
        dailyBreakdown[dateKey] += entry.hours;
      });

      // User productivity
      const userProductivity = {};
      timeEntries.forEach(entry => {
        if (!userProductivity[entry.userId]) {
          userProductivity[entry.userId] = {
            userId: entry.userId,
            userName: entry.user.name,
            totalHours: 0,
            averageSessionLength: 0,
            sessions: 0
          };
        }
        userProductivity[entry.userId].totalHours += entry.hours;
        userProductivity[entry.userId].sessions += 1;
      });

      // Calculate average session lengths
      Object.values(userProductivity).forEach(user => {
        user.averageSessionLength = user.totalHours / user.sessions;
      });

      return {
        period,
        startDate,
        endDate: now,
        totalHours: timeEntries.reduce((sum, entry) => sum + entry.hours, 0),
        totalSessions: timeEntries.length,
        dailyBreakdown: Object.entries(dailyBreakdown).map(([date, hours]) => ({
          date,
          hours
        })),
        userProductivity: Object.values(userProductivity)
      };
    } catch (error) {
      logger.error('Error getting time analytics:', error);
      throw error;
    }
  }
}

module.exports = new TimeTrackingService();
