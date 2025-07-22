const { PrismaClient } = require('@prisma/client');
const multer = require('multer');
const path = require('path');
const fs = require('fs').promises;
const logger = require('../config/logger');
const activityService = require('./activityService');

const prisma = new PrismaClient();

class FileService {
  constructor() {
    this.uploadDir = process.env.UPLOAD_DIR || 'uploads';
    this.maxFileSize = parseInt(process.env.MAX_FILE_SIZE) || 10 * 1024 * 1024; // 10MB default
    this.allowedMimeTypes = [
      'image/jpeg',
      'image/png',
      'image/gif',
      'image/webp',
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.ms-excel',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/vnd.ms-powerpoint',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'text/plain',
      'text/csv',
      'application/zip',
      'application/x-zip-compressed'
    ];

    this.initializeUploadDir();
  }

  async initializeUploadDir() {
    try {
      await fs.mkdir(this.uploadDir, { recursive: true });
      await fs.mkdir(path.join(this.uploadDir, 'tasks'), { recursive: true });
      await fs.mkdir(path.join(this.uploadDir, 'chat'), { recursive: true });
      await fs.mkdir(path.join(this.uploadDir, 'projects'), { recursive: true });
    } catch (error) {
      logger.error('Error creating upload directories:', error);
    }
  }

  // Configure multer for file uploads
  getMulterConfig(destination = 'general') {
    const storage = multer.diskStorage({
      destination: (req, file, cb) => {
        const uploadPath = path.join(this.uploadDir, destination);
        cb(null, uploadPath);
      },
      filename: (req, file, cb) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        const ext = path.extname(file.originalname);
        const name = path.basename(file.originalname, ext);
        cb(null, `${name}-${uniqueSuffix}${ext}`);
      }
    });

    return multer({
      storage,
      limits: {
        fileSize: this.maxFileSize
      },
      fileFilter: (req, file, cb) => {
        if (this.allowedMimeTypes.includes(file.mimetype)) {
          cb(null, true);
        } else {
          cb(new Error(`File type ${file.mimetype} is not allowed`), false);
        }
      }
    });
  }

  // Upload file and save to database
  async uploadFile(userId, fileData, options = {}) {
    try {
      const {
        taskId,
        messageId,
        projectId,
        description,
        isPublic = false
      } = options;

      const fileUpload = await prisma.fileUpload.create({
        data: {
          filename: fileData.filename,
          originalName: fileData.originalname,
          mimeType: fileData.mimetype,
          size: fileData.size,
          path: fileData.path,
          description,
          isPublic,
          uploadedById: userId,
          taskId,
          messageId
        },
        include: {
          uploadedBy: { select: { id: true, name: true, email: true } },
          task: { select: { id: true, title: true, projectId: true } },
          message: { select: { id: true, channelId: true } }
        }
      });

      // Log activity
      if (taskId) {
        const task = await prisma.task.findUnique({
          where: { id: taskId },
          select: { title: true, projectId: true }
        });

        if (task) {
          await activityService.logFileUploaded(
            userId,
            taskId,
            task.projectId,
            fileData.originalname,
            fileData.size
          );
        }
      }

      logger.info(`File uploaded: ${fileData.originalname} by user ${userId}`);
      return this.formatFileResponse(fileUpload);
    } catch (error) {
      // Clean up uploaded file if database save fails
      try {
        await fs.unlink(fileData.path);
      } catch (unlinkError) {
        logger.error('Error cleaning up uploaded file:', unlinkError);
      }
      
      logger.error('Error saving file upload:', error);
      throw error;
    }
  }

  // Get files for a task
  async getTaskFiles(taskId, userId) {
    try {
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
            },
            {
              project: {
                members: {
                  some: { userId }
                }
              }
            }
          ]
        }
      });

      if (!task) {
        throw new Error('Task not found or access denied');
      }

      const files = await prisma.fileUpload.findMany({
        where: { taskId },
        include: {
          uploadedBy: { select: { id: true, name: true, email: true } }
        },
        orderBy: { createdAt: 'desc' }
      });

      return files.map(file => this.formatFileResponse(file));
    } catch (error) {
      logger.error('Error getting task files:', error);
      throw error;
    }
  }

  // Get files for a chat message
  async getMessageFiles(messageId, userId) {
    try {
      // Verify user has access to the message
      const message = await prisma.chatMessage.findFirst({
        where: {
          id: messageId,
          OR: [
            { senderId: userId },
            { recipientId: userId },
            {
              channel: {
                members: {
                  some: { userId }
                }
              }
            }
          ]
        }
      });

      if (!message) {
        throw new Error('Message not found or access denied');
      }

      const files = await prisma.fileUpload.findMany({
        where: { messageId },
        include: {
          uploadedBy: { select: { id: true, name: true, email: true } }
        },
        orderBy: { createdAt: 'desc' }
      });

      return files.map(file => this.formatFileResponse(file));
    } catch (error) {
      logger.error('Error getting message files:', error);
      throw error;
    }
  }

  // Get user's files
  async getUserFiles(userId, options = {}) {
    try {
      const {
        taskId,
        projectId,
        page = 1,
        limit = 20,
        search,
        mimeType
      } = options;

      const where = { uploadedById: userId };

      if (taskId) {
        where.taskId = taskId;
      }

      if (projectId) {
        where.task = { projectId };
      }

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
            task: { select: { id: true, title: true, projectId: true } }
          },
          orderBy: { createdAt: 'desc' },
          skip: (page - 1) * limit,
          take: limit
        }),
        prisma.fileUpload.count({ where })
      ]);

      return {
        files: files.map(file => this.formatFileResponse(file)),
        pagination: {
          page,
          limit,
          total: totalCount,
          pages: Math.ceil(totalCount / limit)
        }
      };
    } catch (error) {
      logger.error('Error getting user files:', error);
      throw error;
    }
  }

  // Get file by ID
  async getFile(fileId, userId) {
    try {
      const file = await prisma.fileUpload.findFirst({
        where: {
          id: fileId,
          OR: [
            { uploadedById: userId },
            { isPublic: true },
            {
              task: {
                OR: [
                  { createdById: userId },
                  { mainAssigneeId: userId },
                  {
                    assignments: {
                      some: { userId }
                    }
                  },
                  {
                    project: {
                      members: {
                        some: { userId }
                      }
                    }
                  }
                ]
              }
            },
            {
              message: {
                OR: [
                  { senderId: userId },
                  { recipientId: userId },
                  {
                    channel: {
                      members: {
                        some: { userId }
                      }
                    }
                  }
                ]
              }
            }
          ]
        },
        include: {
          uploadedBy: { select: { id: true, name: true, email: true } },
          task: { select: { id: true, title: true, projectId: true } },
          message: { select: { id: true, channelId: true } }
        }
      });

      if (!file) {
        throw new Error('File not found or access denied');
      }

      return this.formatFileResponse(file);
    } catch (error) {
      logger.error('Error getting file:', error);
      throw error;
    }
  }

  // Delete file
  async deleteFile(fileId, userId) {
    try {
      const file = await prisma.fileUpload.findFirst({
        where: {
          id: fileId,
          uploadedById: userId
        }
      });

      if (!file) {
        throw new Error('File not found or access denied');
      }

      // Delete file from filesystem
      try {
        await fs.unlink(file.path);
      } catch (fsError) {
        logger.warn('Error deleting file from filesystem:', fsError);
      }

      // Delete from database
      await prisma.fileUpload.delete({
        where: { id: fileId }
      });

      logger.info(`File deleted: ${file.originalName} by user ${userId}`);
    } catch (error) {
      logger.error('Error deleting file:', error);
      throw error;
    }
  }

  // Update file metadata
  async updateFile(fileId, userId, updateData) {
    try {
      const file = await prisma.fileUpload.findFirst({
        where: {
          id: fileId,
          uploadedById: userId
        }
      });

      if (!file) {
        throw new Error('File not found or access denied');
      }

      const allowedUpdates = ['description', 'isPublic'];
      const filteredData = {};
      
      Object.keys(updateData).forEach(key => {
        if (allowedUpdates.includes(key)) {
          filteredData[key] = updateData[key];
        }
      });

      const updatedFile = await prisma.fileUpload.update({
        where: { id: fileId },
        data: filteredData,
        include: {
          uploadedBy: { select: { id: true, name: true, email: true } },
          task: { select: { id: true, title: true, projectId: true } },
          message: { select: { id: true, channelId: true } }
        }
      });

      logger.info(`File updated: ${updatedFile.originalName} by user ${userId}`);
      return this.formatFileResponse(updatedFile);
    } catch (error) {
      logger.error('Error updating file:', error);
      throw error;
    }
  }

  // Get file statistics
  async getFileStats(userId, projectId = null) {
    try {
      const where = { uploadedById: userId };
      
      if (projectId) {
        where.task = { projectId };
      }

      const [totalFiles, totalSize, typeStats] = await Promise.all([
        prisma.fileUpload.count({ where }),
        
        prisma.fileUpload.aggregate({
          where,
          _sum: { size: true }
        }),
        
        prisma.fileUpload.groupBy({
          by: ['mimeType'],
          where,
          _count: { mimeType: true },
          _sum: { size: true }
        })
      ]);

      return {
        totalFiles,
        totalSize: totalSize._sum.size || 0,
        byType: typeStats.map(stat => ({
          mimeType: stat.mimeType,
          count: stat._count.mimeType,
          size: stat._sum.size
        }))
      };
    } catch (error) {
      logger.error('Error getting file stats:', error);
      throw error;
    }
  }

  // Format file response
  formatFileResponse(file) {
    return {
      id: file.id,
      filename: file.filename,
      originalName: file.originalName,
      mimeType: file.mimeType,
      size: file.size,
      description: file.description,
      isPublic: file.isPublic,
      createdAt: file.createdAt,
      uploadedBy: file.uploadedBy,
      task: file.task,
      message: file.message,
      downloadUrl: `/api/files/${file.id}/download`,
      previewUrl: this.isPreviewable(file.mimeType) ? `/api/files/${file.id}/preview` : null
    };
  }

  // Check if file type is previewable
  isPreviewable(mimeType) {
    const previewableTypes = [
      'image/jpeg',
      'image/png',
      'image/gif',
      'image/webp',
      'application/pdf',
      'text/plain'
    ];
    
    return previewableTypes.includes(mimeType);
  }

  // Get file path for serving
  getFilePath(filename) {
    return path.join(this.uploadDir, filename);
  }
}

module.exports = new FileService();
