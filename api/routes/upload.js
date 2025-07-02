const express = require('express');
const multer = require('multer');
const sharp = require('sharp');
const AWS = require('aws-sdk');
const { body, validationResult } = require('express-validator');
const { pool } = require('../config/database');
const { authenticateToken, requirePremium } = require('../middleware/auth');

const router = express.Router();

// Configure AWS S3
const s3 = new AWS.S3({
  accessKeyId: process.env.AWS_ACCESS_KEY_ID,
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  region: process.env.AWS_REGION
});

// Configure Multer for memory storage - Images
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: parseInt(process.env.MAX_FILE_SIZE) || 5 * 1024 * 1024, // 5MB
    files: 5
  },
  fileFilter: (req, file, cb) => {
    const allowedTypes = (process.env.ALLOWED_IMAGE_TYPES || 'jpeg,jpg,png,webp').split(',');
    const fileType = file.mimetype.split('/')[1];
    
    if (allowedTypes.includes(fileType)) {
      cb(null, true);
    } else {
      cb(new Error(`File type ${fileType} not allowed. Allowed types: ${allowedTypes.join(', ')}`));
    }
  }
});

// Configure Multer for video uploads
const uploadVideo = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: parseInt(process.env.MAX_VIDEO_FILE_SIZE) || 50 * 1024 * 1024, // 50MB for videos
    files: 3
  },
  fileFilter: (req, file, cb) => {
    const allowedVideoTypes = (process.env.ALLOWED_VIDEO_TYPES || 'mp4,mov,avi,webm').split(',');
    const fileType = file.mimetype.split('/')[1];
    
    if (allowedVideoTypes.includes(fileType) || file.mimetype.startsWith('video/')) {
      cb(null, true);
    } else {
      cb(new Error(`Video type ${fileType} not allowed. Allowed types: ${allowedVideoTypes.join(', ')}`));
    }
  }
});

/**
 * @swagger
 * /api/upload/images:
 *   post:
 *     summary: Upload images for a location
 *     tags: [Upload]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               images:
 *                 type: array
 *                 items:
 *                   type: string
 *                   format: binary
 *               location_id:
 *                 type: string
 *     responses:
 *       200:
 *         description: Images uploaded successfully
 *       400:
 *         description: Invalid request
 *       403:
 *         description: Premium required
 */
router.post('/images', [
  authenticateToken,
  requirePremium,
  upload.array('images', 5),
  body('location_id').isNumeric()
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Validation Error',
        details: errors.array()
      });
    }

    const { location_id } = req.body;
    const files = req.files;

    if (!files || files.length === 0) {
      return res.status(400).json({
        error: 'No images provided'
      });
    }

    // Check if location exists and belongs to user
    const [locations] = await pool.execute(
      'SELECT id FROM locations WHERE id = ? AND submitted_by = ?',
      [location_id, req.user.userId]
    );

    if (locations.length === 0) {
      return res.status(404).json({
        error: 'Location not found or access denied'
      });
    }

    const uploadPromises = files.map(async (file, index) => {
      try {
        // Process image with Sharp
        const originalBuffer = await sharp(file.buffer)
          .resize(1920, 1080, { 
            fit: 'inside',
            withoutEnlargement: true 
          })
          .jpeg({ quality: 85 })
          .toBuffer();

        const thumbnailBuffer = await sharp(file.buffer)
          .resize(400, 300, { 
            fit: 'cover' 
          })
          .jpeg({ quality: 75 })
          .toBuffer();

        // Generate unique filenames
        const timestamp = Date.now();
        const originalKey = `locations/${location_id}/original_${timestamp}_${index}.jpg`;
        const thumbnailKey = `locations/${location_id}/thumb_${timestamp}_${index}.jpg`;

        // Upload to S3
        const [originalUpload, thumbnailUpload] = await Promise.all([
          s3.upload({
            Bucket: process.env.S3_BUCKET_NAME,
            Key: originalKey,
            Body: originalBuffer,
            ContentType: 'image/jpeg',
            ACL: 'public-read'
          }).promise(),
          s3.upload({
            Bucket: process.env.S3_BUCKET_NAME,
            Key: thumbnailKey,
            Body: thumbnailBuffer,
            ContentType: 'image/jpeg',
            ACL: 'public-read'
          }).promise()
        ]);

        // Save to database
        await pool.execute(`
          INSERT INTO location_images (location_id, image_url, thumbnail_url, image_order, uploaded_by, file_size, image_width, image_height)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        `, [
          location_id,
          originalUpload.Location,
          thumbnailUpload.Location,
          index,
          req.user.userId,
          originalBuffer.length,
          1920,
          1080
        ]);

        return {
          url: originalUpload.Location,
          thumbnail: thumbnailUpload.Location,
          order: index
        };
      } catch (error) {
        console.error(`Error processing image ${index}:`, error);
        throw error;
      }
    });

    const uploadedImages = await Promise.all(uploadPromises);

    res.json({
      message: 'Images uploaded successfully',
      images: uploadedImages,
      total_uploaded: uploadedImages.length
    });
  } catch (error) {
    console.error('Image upload error:', error);
    res.status(500).json({
      error: 'Failed to upload images',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/upload/videos:
 *   post:
 *     summary: Upload videos for a location
 *     tags: [Upload]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               videos:
 *                 type: array
 *                 items:
 *                   type: string
 *                   format: binary
 *               location_id:
 *                 type: string
 *     responses:
 *       200:
 *         description: Videos uploaded successfully
 *       400:
 *         description: Invalid request
 *       403:
 *         description: Premium required
 */
router.post('/videos', [
  authenticateToken,
  requirePremium,
  uploadVideo.array('videos', 3),
  body('location_id').isNumeric()
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Validation Error',
        details: errors.array()
      });
    }

    const { location_id } = req.body;
    const files = req.files;

    if (!files || files.length === 0) {
      return res.status(400).json({
        error: 'No videos provided'
      });
    }

    // Check if location exists and belongs to user
    const [locations] = await pool.execute(
      'SELECT id FROM locations WHERE id = ? AND submitted_by = ?',
      [location_id, req.user.userId]
    );

    if (locations.length === 0) {
      return res.status(404).json({
        error: 'Location not found or access denied'
      });
    }

    const uploadPromises = files.map(async (file, index) => {
      try {
        // Generate unique filenames
        const timestamp = Date.now();
        const fileExtension = file.originalname.split('.').pop();
        const videoKey = `locations/${location_id}/video_${timestamp}_${index}.${fileExtension}`;
        
        // Create thumbnail from video (simple approach - could be enhanced with ffmpeg)
        const thumbnailBuffer = await sharp(Buffer.alloc(100)) // Placeholder for now
          .resize(400, 300, { fit: 'cover' })
          .jpeg({ quality: 75 })
          .toBuffer();
        
        const thumbnailKey = `locations/${location_id}/video_thumb_${timestamp}_${index}.jpg`;

        // Upload video to S3
        const videoUpload = s3.upload({
          Bucket: process.env.S3_BUCKET_NAME,
          Key: videoKey,
          Body: file.buffer,
          ContentType: file.mimetype,
          ACL: 'public-read'
        }).promise();

        // Upload thumbnail to S3
        const thumbnailUpload = s3.upload({
          Bucket: process.env.S3_BUCKET_NAME,
          Key: thumbnailKey,
          Body: thumbnailBuffer,
          ContentType: 'image/jpeg',
          ACL: 'public-read'
        }).promise();

        const [videoResult, thumbnailResult] = await Promise.all([videoUpload, thumbnailUpload]);

        // Save to database
        await pool.execute(`
          INSERT INTO location_videos (location_id, video_url, thumbnail_url, video_order, uploaded_by, file_size)
          VALUES (?, ?, ?, ?, ?, ?)
        `, [
          location_id,
          videoResult.Location,
          thumbnailResult.Location,
          index,
          req.user.userId,
          file.size
        ]);

        return {
          url: videoResult.Location,
          thumbnail: thumbnailResult.Location,
          order: index
        };
      } catch (error) {
        console.error(`Error processing video ${index}:`, error);
        throw error;
      }
    });

    const uploadedVideos = await Promise.all(uploadPromises);

    res.json({
      message: 'Videos uploaded successfully',
      videos: uploadedVideos,
      total_uploaded: uploadedVideos.length
    });
  } catch (error) {
    console.error('Video upload error:', error);
    res.status(500).json({
      error: 'Failed to upload videos',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/upload/profile-image:
 *   post:
 *     summary: Upload profile image
 *     tags: [Upload]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               image:
 *                 type: string
 *                 format: binary
 *     responses:
 *       200:
 *         description: Profile image uploaded successfully
 */
router.post('/profile-image', [
  authenticateToken,
  upload.single('image')
], async (req, res) => {
  try {
    const file = req.file;

    if (!file) {
      return res.status(400).json({
        error: 'No image provided'
      });
    }

    // Process image
    const processedBuffer = await sharp(file.buffer)
      .resize(400, 400, { fit: 'cover' })
      .jpeg({ quality: 85 })
      .toBuffer();

    // Generate unique filename
    const timestamp = Date.now();
    const key = `profiles/${req.user.userId}_${timestamp}.jpg`;

    // Upload to S3
    const uploadResult = await s3.upload({
      Bucket: process.env.S3_BUCKET_NAME,
      Key: key,
      Body: processedBuffer,
      ContentType: 'image/jpeg',
      ACL: 'public-read'
    }).promise();

    // Update user profile
    await pool.execute(
      'UPDATE users SET profile_image_url = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      [uploadResult.Location, req.user.userId]
    );

    res.json({
      message: 'Profile image uploaded successfully',
      image_url: uploadResult.Location
    });
  } catch (error) {
    console.error('Profile image upload error:', error);
    res.status(500).json({
      error: 'Failed to upload profile image',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/upload/images/{id}:
 *   delete:
 *     summary: Delete an image
 *     tags: [Upload]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Image deleted successfully
 *       404:
 *         description: Image not found
 */
router.delete('/images/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;

    // Get image details
    const [images] = await pool.execute(`
      SELECT li.*, l.submitted_by 
      FROM location_images li
      JOIN locations l ON li.location_id = l.id
      WHERE li.id = ?
    `, [id]);

    if (images.length === 0) {
      return res.status(404).json({
        error: 'Image not found'
      });
    }

    const image = images[0];

    // Check if user owns the location
    if (image.submitted_by !== req.user.userId) {
      return res.status(403).json({
        error: 'Access denied'
      });
    }

    // Extract S3 keys from URLs
    const originalKey = image.image_url.split('/').slice(-3).join('/');
    const thumbnailKey = image.thumbnail_url.split('/').slice(-3).join('/');

    // Delete from S3
    await Promise.all([
      s3.deleteObject({
        Bucket: process.env.S3_BUCKET_NAME,
        Key: originalKey
      }).promise(),
      s3.deleteObject({
        Bucket: process.env.S3_BUCKET_NAME,
        Key: thumbnailKey
      }).promise()
    ]);

    // Delete from database
    await pool.execute('DELETE FROM location_images WHERE id = ?', [id]);

    res.json({
      message: 'Image deleted successfully'
    });
  } catch (error) {
    console.error('Delete image error:', error);
    res.status(500).json({
      error: 'Failed to delete image',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/upload/videos/{id}:
 *   delete:
 *     summary: Delete a video
 *     tags: [Upload]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Video deleted successfully
 *       404:
 *         description: Video not found
 */
router.delete('/videos/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;

    // Get video details
    const [videos] = await pool.execute(`
      SELECT lv.*, l.submitted_by 
      FROM location_videos lv
      JOIN locations l ON lv.location_id = l.id
      WHERE lv.id = ?
    `, [id]);

    if (videos.length === 0) {
      return res.status(404).json({
        error: 'Video not found'
      });
    }

    const video = videos[0];

    // Check if user owns the location
    if (video.submitted_by !== req.user.userId) {
      return res.status(403).json({
        error: 'Access denied'
      });
    }

    // Extract S3 keys from URLs
    const videoKey = video.video_url.split('/').slice(-3).join('/');
    const thumbnailKey = video.thumbnail_url ? video.thumbnail_url.split('/').slice(-3).join('/') : null;

    // Delete from S3
    const deletePromises = [
      s3.deleteObject({
        Bucket: process.env.S3_BUCKET_NAME,
        Key: videoKey
      }).promise()
    ];

    if (thumbnailKey) {
      deletePromises.push(
        s3.deleteObject({
          Bucket: process.env.S3_BUCKET_NAME,
          Key: thumbnailKey
        }).promise()
      );
    }

    await Promise.all(deletePromises);

    // Delete from database
    await pool.execute('DELETE FROM location_videos WHERE id = ?', [id]);

    res.json({
      message: 'Video deleted successfully'
    });
  } catch (error) {
    console.error('Delete video error:', error);
    res.status(500).json({
      error: 'Failed to delete video',
      message: error.message
    });
  }
});

module.exports = router;
