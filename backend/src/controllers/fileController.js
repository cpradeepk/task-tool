const googleDriveService = require('../config/googleDrive');
const prisma = require('../config/database');
const logger = require('../config/logger');

class FileController {
  async uploadProfilePicture(req, res) {
    try {
      if (!req.file) {
        return res.status(400).json({ error: 'No file provided' });
      }

      const { buffer, originalname, mimetype, size } = req.file;
      const fileName = `profile_${req.user.id}_${Date.now()}_${originalname}`;

      // Upload to Google Drive
      const driveFile = await googleDriveService.uploadFile(
        buffer,
        fileName,
        mimetype,
        'profile-pictures',
        {
          description: `Profile picture for user ${req.user.email}`
        }
      );

      // Delete old profile picture if exists
      const currentUser = await prisma.user.findUnique({
        where: { id: req.user.id },
        select: { profilePicture: true }
      });

      if (currentUser?.profilePicture) {
        try {
          // Find and delete old file record
          const oldFile = await prisma.fileUpload.findFirst({
            where: {
              uploadedById: req.user.id,
              folderType: 'PROFILE_PICTURES'
            }
          });

          if (oldFile) {
            await googleDriveService.deleteFile(oldFile.googleDriveId);
            await prisma.fileUpload.delete({
              where: { id: oldFile.id }
            });
          }
        } catch (deleteError) {
          logger.warn('Failed to delete old profile picture:', deleteError);
        }
      }

      // Save file record
      const fileRecord = await prisma.fileUpload.create({
        data: {
          fileName,
          originalName: originalname,
          mimeType: mimetype,
          size,
          googleDriveId: driveFile.id,
          folderType: 'PROFILE_PICTURES',
          uploadedById: req.user.id
        }
      });

      // Update user profile picture
      await prisma.user.update({
        where: { id: req.user.id },
        data: { profilePicture: driveFile.id }
      });

      res.json({
        message: 'Profile picture uploaded successfully',
        file: {
          id: fileRecord.id,
          fileName: fileRecord.fileName,
          originalName: fileRecord.originalName,
          size: fileRecord.size,
          googleDriveId: driveFile.id
        }
      });
    } catch (error) {
      logger.error('Upload profile picture error:', error);
      res.status(500).json({ error: 'Failed to upload profile picture' });
    }
  }

  async getProfilePicture(req, res) {
    try {
      const { fileId } = req.params;

      // Get file metadata
      const metadata = await googleDriveService.getFileMetadata(fileId);
      
      // Download file
      const fileData = await googleDriveService.downloadFile(fileId);

      res.set({
        'Content-Type': metadata.mimeType,
        'Content-Length': metadata.size,
        'Cache-Control': 'public, max-age=86400' // Cache for 1 day
      });

      res.send(fileData);

    } catch (error) {
      console.error('Get profile picture error:', error);
      res.status(404).json({ error: 'File not found' });
    }
  }

  async uploadTaskAttachment(req, res) {
    try {
      if (!req.file) {
        return res.status(400).json({ error: 'No file provided' });
      }

      const { taskId, description } = req.body;
      const { buffer, originalname, mimetype, size } = req.file;

      // Verify task access if taskId provided
      if (taskId) {
        const task = await prisma.task.findFirst({
          where: {
            id: taskId,
            OR: [
              { createdById: req.user.id },
              { assignedToId: req.user.id },
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
          return res.status(404).json({ error: 'Task not found or no access' });
        }
      }

      const fileName = `task_${taskId || 'general'}_${Date.now()}_${originalname}`;

      // Upload to Google Drive
      const driveFile = await googleDriveService.uploadFile(
        buffer,
        fileName,
        mimetype,
        'task-attachments',
        {
          description: description || `Task attachment uploaded by ${req.user.email}`
        }
      );

      // Save file record
      const fileRecord = await prisma.fileUpload.create({
        data: {
          fileName,
          originalName: originalname,
          mimeType: mimetype,
          size,
          googleDriveId: driveFile.id,
          folderType: 'TASK_ATTACHMENTS',
          description,
          uploadedById: req.user.id,
          taskId: taskId || null
        }
      });

      res.json({
        message: 'File uploaded successfully',
        file: {
          id: fileRecord.id,
          fileName: fileRecord.fileName,
          originalName: fileRecord.originalName,
          size: fileRecord.size,
          description: fileRecord.description,
          googleDriveId: driveFile.id
        }
      });
    } catch (error) {
      logger.error('Upload task attachment error:', error);
      res.status(500).json({ error: 'Failed to upload file' });
    }
  }

  async uploadChatMedia(req, res) {
    try {
      if (!req.file) {
        return res.status(400).json({ error: 'No file provided' });
      }

      const { chatId } = req.body;
      if (!chatId) {
        return res.status(400).json({ error: 'Chat ID is required' });
      }

      // Verify chat exists and user has access
      const chat = await prisma.chat.findFirst({
        where: {
          id: chatId,
          subProject: {
            tasks: {
              some: {
                OR: [
                  { creatorId: req.user.id },
                  { assignments: { some: { userId: req.user.id } } }
                ]
              }
            }
          }
        }
      });

      if (!chat) {
        return res.status(404).json({ error: 'Chat not found or access denied' });
      }

      const { buffer, originalname, mimetype, size } = req.file;
      const fileName = `chat_${chatId}_${Date.now()}_${originalname}`;

      // Upload to Google Drive
      const driveFile = await googleDriveService.uploadFile(
        buffer,
        fileName,
        mimetype,
        'chat-media',
        {
          description: `Media for chat ${chatId}`
        }
      );

      res.json({
        fileId: driveFile.id,
        fileName: driveFile.name,
        originalName: originalname,
        size: driveFile.size,
        mimeType: mimetype,
        url: `/api/files/${driveFile.id}`
      });

    } catch (error) {
      console.error('Upload chat media error:', error);
      res.status(500).json({ error: 'Failed to upload media' });
    }
  }

  async downloadFile(req, res) {
    try {
      const { id } = req.params;

      // Get file record and verify access
      const fileRecord = await prisma.fileUpload.findFirst({
        where: {
          id,
          OR: [
            { uploadedById: req.user.id },
            {
              task: {
                OR: [
                  { createdById: req.user.id },
                  { assignedToId: req.user.id },
                  {
                    project: {
                      members: {
                        some: { userId: req.user.id }
                      }
                    }
                  }
                ]
              }
            }
          ]
        }
      });

      if (!fileRecord) {
        return res.status(404).json({ error: 'File not found or no access' });
      }

      // Download from Google Drive
      const fileBuffer = await googleDriveService.downloadFile(fileRecord.googleDriveId);

      // Set response headers
      res.setHeader('Content-Type', fileRecord.mimeType);
      res.setHeader('Content-Disposition', `attachment; filename="${fileRecord.originalName}"`);
      res.setHeader('Content-Length', fileBuffer.length);

      res.send(fileBuffer);
    } catch (error) {
      logger.error('Download file error:', error);
      res.status(500).json({ error: 'Failed to download file' });
    }
  }

  async deleteFile(req, res) {
    try {
      const { id } = req.params;

      // Get file record and verify access
      const fileRecord = await prisma.fileUpload.findFirst({
        where: {
          id,
          uploadedById: req.user.id
        }
      });

      if (!fileRecord) {
        return res.status(404).json({ error: 'File not found or no permission' });
      }

      // Delete from Google Drive
      await googleDriveService.deleteFile(fileRecord.googleDriveId);

      // Delete file record
      await prisma.fileUpload.delete({
        where: { id }
      });

      // If it was a profile picture, update user record
      if (fileRecord.folderType === 'PROFILE_PICTURES') {
        await prisma.user.update({
          where: { id: req.user.id },
          data: { profilePicture: null }
        });
      }

      res.json({ message: 'File deleted successfully' });
    } catch (error) {
      logger.error('Delete file error:', error);
      res.status(500).json({ error: 'Failed to delete file' });
    }
  }

  async getUserFiles(req, res) {
    try {
      const { userId } = req.params;
      const { folderType } = req.query;

      // Verify access (users can only see their own files unless admin)
      if (userId !== req.user.id && !req.user.isAdmin) {
        return res.status(403).json({ error: 'Access denied' });
      }

      const where = {
        uploadedById: userId
      };

      if (folderType) {
        where.folderType = folderType;
      }

      const files = await prisma.fileUpload.findMany({
        where,
        select: {
          id: true,
          fileName: true,
          originalName: true,
          mimeType: true,
          size: true,
          folderType: true,
          description: true,
          createdAt: true,
          task: {
            select: {
              id: true,
              title: true
            }
          }
        },
        orderBy: { createdAt: 'desc' }
      });

      res.json({ files });
    } catch (error) {
      logger.error('Get user files error:', error);
      res.status(500).json({ error: 'Failed to get files' });
    }
  }
}

module.exports = new FileController();
