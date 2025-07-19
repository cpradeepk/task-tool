const { google } = require('googleapis');
const path = require('path');
const fs = require('fs');
const logger = require('./logger');

class GoogleDriveService {
  constructor() {
    this.drive = null;
    this.auth = null;
    this.rootFolderId = process.env.GOOGLE_DRIVE_ROOT_FOLDER_ID;
    this.folders = {};
    this.initialize();
  }

  async initialize() {
    try {
      const keyFile = process.env.GOOGLE_SERVICE_ACCOUNT_KEY_FILE;
      if (!keyFile || !fs.existsSync(keyFile)) {
        throw new Error('Google service account key file not found');
      }

      this.auth = new google.auth.GoogleAuth({
        keyFile: keyFile,
        scopes: ['https://www.googleapis.com/auth/drive']
      });

      this.drive = google.drive({ version: 'v3', auth: this.auth });
      logger.info('Google Drive service initialized successfully');
    } catch (error) {
      logger.error('Failed to initialize Google Drive service:', error);
      throw error;
    }
  }

  async initializeFolderStructure() {
    try {
      if (!this.rootFolderId) {
        throw new Error('GOOGLE_DRIVE_ROOT_FOLDER_ID not configured');
      }

      const folderStructure = [
        'profile-pictures',
        'task-attachments',
        'chat-media',
        'documents',
        'voice-notes'
      ];

      for (const folderName of folderStructure) {
        const folderId = await this.createOrGetFolder(folderName, this.rootFolderId);
        this.folders[folderName] = folderId;
        logger.info(`Folder initialized: ${folderName} (${folderId})`);
      }

      logger.info('Google Drive folder structure initialized');
    } catch (error) {
      logger.error('Failed to initialize folder structure:', error);
      throw error;
    }
  }

  async createOrGetFolder(name, parentId) {
    try {
      // Check if folder already exists
      const response = await this.drive.files.list({
        q: `name='${name}' and parents in '${parentId}' and mimeType='application/vnd.google-apps.folder'`,
        fields: 'files(id, name)'
      });

      if (response.data.files.length > 0) {
        return response.data.files[0].id;
      }

      // Create new folder
      const folderMetadata = {
        name: name,
        parents: [parentId],
        mimeType: 'application/vnd.google-apps.folder'
      };

      const folder = await this.drive.files.create({
        resource: folderMetadata,
        fields: 'id'
      });

      return folder.data.id;
    } catch (error) {
      logger.error(`Failed to create/get folder ${name}:`, error);
      throw error;
    }
  }

  async uploadFile(buffer, fileName, mimeType, folderType, metadata = {}) {
    try {
      const folderId = this.folders[folderType];
      if (!folderId) {
        throw new Error(`Unknown folder type: ${folderType}`);
      }

      const fileMetadata = {
        name: fileName,
        parents: [folderId],
        ...metadata
      };

      const media = {
        mimeType: mimeType,
        body: require('stream').Readable.from(buffer)
      };

      const response = await this.drive.files.create({
        resource: fileMetadata,
        media: media,
        fields: 'id,name,size,mimeType'
      });

      logger.info(`File uploaded to Google Drive: ${fileName}`);
      return response.data;
    } catch (error) {
      logger.error('Google Drive upload error:', error);
      throw error;
    }
  }

  async downloadFile(fileId) {
    try {
      const response = await this.drive.files.get({
        fileId: fileId,
        alt: 'media'
      }, { responseType: 'arraybuffer' });

      return Buffer.from(response.data);
    } catch (error) {
      logger.error('Google Drive download error:', error);
      throw error;
    }
  }

  async getFileMetadata(fileId) {
    try {
      const response = await this.drive.files.get({
        fileId: fileId,
        fields: 'id,name,size,mimeType,createdTime'
      });

      return response.data;
    } catch (error) {
      logger.error('Google Drive metadata error:', error);
      throw error;
    }
  }

  async deleteFile(fileId) {
    try {
      await this.drive.files.delete({ fileId: fileId });
      logger.info(`File deleted from Google Drive: ${fileId}`);
    } catch (error) {
      logger.error('Google Drive delete error:', error);
      throw error;
    }
  }
}

module.exports = new GoogleDriveService();