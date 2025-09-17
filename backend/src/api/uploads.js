import express from 'express';
import multer from 'multer';
import path from 'path';
import fs from 'fs/promises';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';
import { S3Client, PutObjectCommand, DeleteObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

const router = express.Router();
router.use(requireAuth);

// Configure S3 client (if available)
const s3 = process.env.S3_BUCKET ? new S3Client({
  region: process.env.S3_REGION,
  endpoint: process.env.S3_ENDPOINT,
  credentials: process.env.S3_ACCESS_KEY && process.env.S3_SECRET_KEY ? {
    accessKeyId: process.env.S3_ACCESS_KEY,
    secretAccessKey: process.env.S3_SECRET_KEY
  } : undefined,
  forcePathStyle: !!process.env.S3_FORCE_PATH_STYLE
}) : null;

// Configure local storage as fallback
const uploadDir = process.env.UPLOAD_DIR || './uploads';
await fs.mkdir(uploadDir, { recursive: true }).catch(() => {});

// Configure multer for local file uploads
const storage = multer.diskStorage({
  destination: async (req, file, cb) => {
    const userDir = path.join(uploadDir, req.user.id.toString());
    await fs.mkdir(userDir, { recursive: true }).catch(() => {});
    cb(null, userDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({
  storage,
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB limit
  },
  fileFilter: (req, file, cb) => {
    // Allow common file types
    const allowedTypes = /jpeg|jpg|png|gif|pdf|doc|docx|txt|csv|xlsx|zip/;
    const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = allowedTypes.test(file.mimetype);

    if (mimetype && extname) {
      return cb(null, true);
    } else {
      cb(new Error('Invalid file type'));
    }
  }
});

// Upload single file (local storage or S3)
router.post('/file', upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    const { originalname, filename, mimetype, size, path: filePath } = req.file;
    const { category = 'general', description = '', task_id, project_id } = req.body;

    let fileUrl = '';
    let storageType = 'local';
    let storageKey = '';

    if (s3 && process.env.S3_BUCKET) {
      // Upload to S3
      try {
        const key = `uploads/${req.user.id}/${Date.now()}-${originalname}`;
        const fileBuffer = await fs.readFile(filePath);

        const command = new PutObjectCommand({
          Bucket: process.env.S3_BUCKET,
          Key: key,
          Body: fileBuffer,
          ContentType: mimetype,
        });

        await s3.send(command);
        fileUrl = `https://${process.env.S3_BUCKET}.s3.${process.env.S3_REGION}.amazonaws.com/${key}`;
        storageType = 's3';
        storageKey = key;

        // Clean up local file
        await fs.unlink(filePath).catch(() => {});
      } catch (s3Error) {
        console.error('S3 upload failed, using local storage:', s3Error);
        fileUrl = `/task/api/uploads/serve/${req.user.id}/${filename}`;
        storageKey = filePath;
      }
    } else {
      // Use local storage
      fileUrl = `/task/api/uploads/serve/${req.user.id}/${filename}`;
      storageKey = filePath;
    }

    // Store file metadata in database
    const [fileRecord] = await knex('file_uploads').insert({
      user_id: req.user.id,
      original_name: originalname,
      filename,
      file_path: storageKey,
      file_url: fileUrl,
      mime_type: mimetype,
      file_size: size,
      storage_type: storageType,
      category,
      description,
      task_id: task_id ? parseInt(task_id) : null,
      project_id: project_id ? parseInt(project_id) : null,
      created_at: new Date(),
      updated_at: new Date()
    }).returning('*');

    res.status(201).json({
      message: 'File uploaded successfully',
      file: fileRecord
    });
  } catch (error) {
    console.error('File upload error:', error);
    res.status(500).json({ error: 'Failed to upload file' });
  }
});

// Upload multiple files
router.post('/files', upload.array('files', 5), async (req, res) => {
  try {
    if (!req.files || req.files.length === 0) {
      return res.status(400).json({ error: 'No files uploaded' });
    }

    const { category = 'general', description = '', task_id, project_id } = req.body;
    const uploadedFiles = [];

    for (const file of req.files) {
      const { originalname, filename, mimetype, size, path: filePath } = file;

      let fileUrl = '';
      let storageType = 'local';
      let storageKey = '';

      if (s3 && process.env.S3_BUCKET) {
        try {
          const key = `uploads/${req.user.id}/${Date.now()}-${originalname}`;
          const fileBuffer = await fs.readFile(filePath);

          const command = new PutObjectCommand({
            Bucket: process.env.S3_BUCKET,
            Key: key,
            Body: fileBuffer,
            ContentType: mimetype,
          });

          await s3.send(command);
          fileUrl = `https://${process.env.S3_BUCKET}.s3.${process.env.S3_REGION}.amazonaws.com/${key}`;
          storageType = 's3';
          storageKey = key;

          await fs.unlink(filePath).catch(() => {});
        } catch (s3Error) {
          console.error('S3 upload failed for file, using local storage:', s3Error);
          fileUrl = `/task/api/uploads/serve/${req.user.id}/${filename}`;
          storageKey = filePath;
        }
      } else {
        fileUrl = `/task/api/uploads/serve/${req.user.id}/${filename}`;
        storageKey = filePath;
      }

      const [fileRecord] = await knex('file_uploads').insert({
        user_id: req.user.id,
        original_name: originalname,
        filename,
        file_path: storageKey,
        file_url: fileUrl,
        mime_type: mimetype,
        file_size: size,
        storage_type: storageType,
        category,
        description,
        task_id: task_id ? parseInt(task_id) : null,
        project_id: project_id ? parseInt(project_id) : null,
        created_at: new Date(),
        updated_at: new Date()
      }).returning('*');

      uploadedFiles.push(fileRecord);
    }

    res.status(201).json({
      message: `${uploadedFiles.length} files uploaded successfully`,
      files: uploadedFiles
    });
  } catch (error) {
    console.error('Multiple file upload error:', error);
    res.status(500).json({ error: 'Failed to upload files' });
  }
});

// Get user's files
router.get('/files', async (req, res) => {
  try {
    const userId = req.user.id;
    const { category, task_id, project_id, limit = 20, offset = 0 } = req.query;

    let query = knex('file_uploads').where('user_id', userId);

    if (category) {
      query = query.where('category', category);
    }
    if (task_id) {
      query = query.where('task_id', parseInt(task_id));
    }
    if (project_id) {
      query = query.where('project_id', parseInt(project_id));
    }

    const files = await query
      .orderBy('created_at', 'desc')
      .limit(parseInt(limit))
      .offset(parseInt(offset))
      .catch(() => []);

    const [{ count: totalCount }] = await knex('file_uploads')
      .where('user_id', userId)
      .count('* as count')
      .catch(() => [{ count: 0 }]);

    res.json({
      files,
      pagination: {
        total: parseInt(totalCount),
        limit: parseInt(limit),
        offset: parseInt(offset),
        has_more: parseInt(offset) + parseInt(limit) < parseInt(totalCount)
      }
    });
  } catch (error) {
    console.error('Error fetching files:', error);
    res.status(500).json({ error: 'Failed to fetch files' });
  }
});

// Serve local files
router.get('/serve/:userId/:filename', async (req, res) => {
  try {
    const { userId, filename } = req.params;

    // Check if user has access to this file
    if (req.user.id !== parseInt(userId) && !req.user.isAdmin) {
      return res.status(403).json({ error: 'Access denied' });
    }

    const filePath = path.join(uploadDir, userId, filename);

    // Check if file exists
    try {
      await fs.access(filePath);
    } catch {
      return res.status(404).json({ error: 'File not found' });
    }

    // Get file info from database
    const fileInfo = await knex('file_uploads')
      .where('filename', filename)
      .where('user_id', parseInt(userId))
      .first()
      .catch(() => null);

    if (fileInfo) {
      res.setHeader('Content-Type', fileInfo.mime_type);
      res.setHeader('Content-Disposition', `inline; filename="${fileInfo.original_name}"`);
    }

    res.sendFile(path.resolve(filePath));
  } catch (error) {
    console.error('Error serving file:', error);
    res.status(500).json({ error: 'Failed to serve file' });
  }
});

// Delete file
router.delete('/files/:fileId', async (req, res) => {
  try {
    const userId = req.user.id;
    const fileId = parseInt(req.params.fileId);

    const file = await knex('file_uploads')
      .where({ id: fileId, user_id: userId })
      .first();

    if (!file) {
      return res.status(404).json({ error: 'File not found' });
    }

    // Delete from storage
    if (file.storage_type === 's3' && s3) {
      try {
        const command = new DeleteObjectCommand({
          Bucket: process.env.S3_BUCKET,
          Key: file.file_path
        });
        await s3.send(command);
      } catch (s3Error) {
        console.error('S3 delete error:', s3Error);
      }
    } else {
      // Delete local file
      try {
        await fs.unlink(file.file_path);
      } catch (fsError) {
        console.error('Local file delete error:', fsError);
      }
    }

    // Delete from database
    await knex('file_uploads').where('id', fileId).del();

    res.json({ message: 'File deleted successfully' });
  } catch (error) {
    console.error('Error deleting file:', error);
    res.status(500).json({ error: 'Failed to delete file' });
  }
});

// Get file statistics
router.get('/stats', async (req, res) => {
  try {
    const userId = req.user.id;

    const [totalFiles] = await knex('file_uploads')
      .where('user_id', userId)
      .count('* as count')
      .catch(() => [{ count: 0 }]);

    const [totalSize] = await knex('file_uploads')
      .where('user_id', userId)
      .sum('file_size as size')
      .catch(() => [{ size: 0 }]);

    const categoryStats = await knex('file_uploads')
      .where('user_id', userId)
      .select('category')
      .count('* as count')
      .sum('file_size as size')
      .groupBy('category')
      .catch(() => []);

    const recentFiles = await knex('file_uploads')
      .where('user_id', userId)
      .where('created_at', '>', knex.raw("NOW() - INTERVAL '7 days'"))
      .count('* as count')
      .first()
      .catch(() => ({ count: 0 }));

    res.json({
      total_files: parseInt(totalFiles.count),
      total_size: parseInt(totalSize.size || 0),
      recent_files: parseInt(recentFiles.count),
      categories: categoryStats.map(stat => ({
        category: stat.category,
        count: parseInt(stat.count),
        size: parseInt(stat.size)
      }))
    });
  } catch (error) {
    console.error('Error fetching file stats:', error);
    res.status(500).json({ error: 'Failed to fetch file statistics' });
  }
});

// S3 presigned URL (legacy support)
router.post('/presign', async (req, res) => {
  try {
    if (!s3 || !process.env.S3_BUCKET) {
      return res.status(501).json({ error: 'S3 not configured' });
    }

    const { filename, contentType } = req.body;
    if (!filename || !contentType) {
      return res.status(400).json({ error: 'filename and contentType required' });
    }

    const key = `uploads/${req.user.id}/${Date.now()}-${filename}`;
    const cmd = new PutObjectCommand({
      Bucket: process.env.S3_BUCKET,
      Key: key,
      ContentType: contentType
    });

    const url = await getSignedUrl(s3, cmd, { expiresIn: 60 * 5 });
    res.json({ url, key });
  } catch (error) {
    console.error('Error generating presigned URL:', error);
    res.status(500).json({ error: 'Failed to generate presigned URL' });
  }
});

export default router;

