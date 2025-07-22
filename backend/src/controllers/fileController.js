const { PrismaClient } = require('@prisma/client');
const path = require('path');
const fs = require('fs').promises;
const logger = require('../config/logger');
const fileService = require('../services/fileService');

const prisma = new PrismaClient();

class FileController {
  // Upload file
  async uploadFile(req, res) {
    try {
      if (!req.file) {
        return res.status(400).json({ error: 'No file uploaded' });
      }

      const options = {
        taskId: req.body.taskId,
        messageId: req.body.messageId,
        projectId: req.body.projectId,
        description: req.body.description,
        isPublic: req.body.isPublic === 'true'
      };

      const file = await fileService.uploadFile(req.user.id, req.file, options);

      logger.info(`File uploaded: ${req.file.originalname} by ${req.user.email}`);
      res.status(201).json(file);
    } catch (error) {
      logger.error('Error uploading file:', error);
      res.status(400).json({ error: error.message });
    }
  }

  // Upload multiple files
  async uploadMultipleFiles(req, res) {
    try {
      if (!req.files || req.files.length === 0) {
        return res.status(400).json({ error: 'No files uploaded' });
      }

      const options = {
        taskId: req.body.taskId,
        messageId: req.body.messageId,
        projectId: req.body.projectId,
        description: req.body.description,
        isPublic: req.body.isPublic === 'true'
      };

      const uploadPromises = req.files.map(file =>
        fileService.uploadFile(req.user.id, file, options)
      );

      const files = await Promise.all(uploadPromises);

      logger.info(`${files.length} files uploaded by ${req.user.email}`);
      res.status(201).json(files);
    } catch (error) {
      logger.error('Error uploading multiple files:', error);
      res.status(400).json({ error: error.message });
    }
  }

  // Get file details
  async getFile(req, res) {
    try {
      const { fileId } = req.params;
      const file = await fileService.getFile(fileId, req.user.id);

      res.json(file);
    } catch (error) {
      logger.error('Error getting file:', error);
      res.status(404).json({ error: error.message });
    }
  }

  // Download file
  async downloadFile(req, res) {
    try {
      const { fileId } = req.params;
      const file = await fileService.getFile(fileId, req.user.id);

      const filePath = fileService.getFilePath(file.filename);

      // Check if file exists
      try {
        await fs.access(filePath);
      } catch (error) {
        return res.status(404).json({ error: 'File not found on disk' });
      }

      // Set appropriate headers
      res.setHeader('Content-Disposition', `attachment; filename="${file.originalName}"`);
      res.setHeader('Content-Type', file.mimeType);

      // Send file
      res.sendFile(path.resolve(filePath));

      logger.info(`File downloaded: ${file.originalName} by ${req.user.email}`);
    } catch (error) {
      logger.error('Error downloading file:', error);
      res.status(404).json({ error: error.message });
    }
  }

  // Preview file (for images, PDFs, etc.)
  async previewFile(req, res) {
    try {
      const { fileId } = req.params;
      const file = await fileService.getFile(fileId, req.user.id);

      if (!fileService.isPreviewable(file.mimeType)) {
        return res.status(400).json({ error: 'File type not previewable' });
      }

      const filePath = fileService.getFilePath(file.filename);

      // Check if file exists
      try {
        await fs.access(filePath);
      } catch (error) {
        return res.status(404).json({ error: 'File not found on disk' });
      }

      // Set appropriate headers for preview
      res.setHeader('Content-Type', file.mimeType);
      res.setHeader('Content-Disposition', `inline; filename="${file.originalName}"`);

      // Send file for preview
      res.sendFile(path.resolve(filePath));
    } catch (error) {
      logger.error('Error previewing file:', error);
      res.status(404).json({ error: error.message });
    }
  }

  // Get task files
  async getTaskFiles(req, res) {
    try {
      const { taskId } = req.params;
      const files = await fileService.getTaskFiles(taskId, req.user.id);

      res.json(files);
    } catch (error) {
      logger.error('Error getting task files:', error);
      res.status(400).json({ error: error.message });
    }
  }

  // Get message files
  async getMessageFiles(req, res) {
    try {
      const { messageId } = req.params;
      const files = await fileService.getMessageFiles(messageId, req.user.id);

      res.json(files);
    } catch (error) {
      logger.error('Error getting message files:', error);
      res.status(400).json({ error: error.message });
    }
  }

  // Get user files
  async getUserFiles(req, res) {
    try {
      const {
        taskId,
        projectId,
        page,
        limit,
        search,
        mimeType
      } = req.query;

      const options = {
        taskId,
        projectId,
        page: page ? parseInt(page) : 1,
        limit: limit ? parseInt(limit) : 20,
        search,
        mimeType
      };

      const result = await fileService.getUserFiles(req.user.id, options);
      res.json(result);
    } catch (error) {
      logger.error('Error getting user files:', error);
      res.status(500).json({ error: 'Failed to get user files' });
    }
  }

  // Update file
  async updateFile(req, res) {
    try {
      const { fileId } = req.params;
      const updateData = req.body;

      const file = await fileService.updateFile(fileId, req.user.id, updateData);

      logger.info(`File updated: ${fileId} by ${req.user.email}`);
      res.json(file);
    } catch (error) {
      logger.error('Error updating file:', error);
      res.status(400).json({ error: error.message });
    }
  }

  // Delete file
  async deleteFile(req, res) {
    try {
      const { fileId } = req.params;
      await fileService.deleteFile(fileId, req.user.id);

      logger.info(`File deleted: ${fileId} by ${req.user.email}`);
      res.status(204).send();
    } catch (error) {
      logger.error('Error deleting file:', error);
      res.status(400).json({ error: error.message });
    }
  }

  // Get file statistics
  async getFileStats(req, res) {
    try {
      const { projectId } = req.query;
      const stats = await fileService.getFileStats(req.user.id, projectId);

      res.json(stats);
    } catch (error) {
      logger.error('Error getting file stats:', error);
      res.status(500).json({ error: 'Failed to get file statistics' });
    }
  }

  // Get project files (for project members)
  async getProjectFiles(req, res) {
    try {
      const { projectId } = req.params;
      const { page = 1, limit = 20, search, mimeType } = req.query;

      // Verify user has access to the project
      const membership = await prisma.projectMember.findFirst({
        where: {
          projectId,
          userId: req.user.id
        }
      });

      if (!membership && !req.user.isAdmin) {
        return res.status(403).json({ error: 'Access denied to this project' });
      }

      const where = {
        task: { projectId }
      };

      if (search) {
        where.OR = [
          { originalName: { contains: search, mode: 'insensitive' } },
          { description: { contains: search, mode: 'insensitive' } }
        ];
      }

      if (mimeType) {
        where.mimeType = { startsWith: mimeType };
      }

      const [files, totalCount] = await Promise.all([
        prisma.fileUpload.findMany({
          where,
          include: {
            uploadedBy: { select: { id: true, name: true, email: true } },
            task: { select: { id: true, title: true } }
          },
          orderBy: { createdAt: 'desc' },
          skip: (parseInt(page) - 1) * parseInt(limit),
          take: parseInt(limit)
        }),
        prisma.fileUpload.count({ where })
      ]);

      const result = {
        files: files.map(file => fileService.formatFileResponse(file)),
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total: totalCount,
          pages: Math.ceil(totalCount / parseInt(limit))
        }
      };

      res.json(result);
    } catch (error) {
      logger.error('Error getting project files:', error);
      res.status(500).json({ error: 'Failed to get project files' });
    }
  }

  // Get recent files
  async getRecentFiles(req, res) {
    try {
      const { limit = 10 } = req.query;

      // Get user's project memberships
      const projectMemberships = await prisma.projectMember.findMany({
        where: { userId: req.user.id },
        select: { projectId: true }
      });

      const projectIds = projectMemberships.map(m => m.projectId);

      const files = await prisma.fileUpload.findMany({
        where: {
          OR: [
            { uploadedById: req.user.id },
            { task: { projectId: { in: projectIds } } }
          ]
        },
        include: {
          uploadedBy: { select: { id: true, name: true, email: true } },
          task: { select: { id: true, title: true, projectId: true } }
        },
        orderBy: { createdAt: 'desc' },
        take: parseInt(limit)
      });

      res.json(files.map(file => fileService.formatFileResponse(file)));
    } catch (error) {
      logger.error('Error getting recent files:', error);
      res.status(500).json({ error: 'Failed to get recent files' });
    }
  }
}

module.exports = new FileController();
