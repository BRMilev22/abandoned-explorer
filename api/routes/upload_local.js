const express = require('express');
const multer = require('multer');
const sharp = require('sharp');
const path = require('path');
const fs = require('fs').promises;
const { body, validationResult } = require('express-validator');
const { pool } = require('../config/database');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

// Create uploads directory if it doesn't exist
const uploadsDir = path.join(__dirname, '../uploads');
const locationsDir = path.join(uploadsDir, 'locations');
const profilesDir = path.join(uploadsDir, 'profiles');

const ensureDirectoryExists = async (dir) => {
  try {
    await fs.access(dir);
  } catch {
    await fs.mkdir(dir, { recursive: true });
  }
};

// Initialize directories
ensureDirectoryExists(uploadsDir);
ensureDirectoryExists(locationsDir);
ensureDirectoryExists(profilesDir);

// Configure Multer for local storage
const storage = multer.memoryStorage();

const upload = multer({
  storage: storage,
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB
    files: 5
  },
  fileFilter: (req, file, cb) => {
    const allowedTypes = ['jpeg', 'jpg', 'png', 'webp'];
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
  storage: storage,
  limits: {
    fileSize: 50 * 1024 * 1024, // 50MB for videos
    files: 3
  },
  fileFilter: (req, file, cb) => {
    const allowedVideoTypes = ['mp4', 'mov', 'avi', 'webm'];
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
 *                 type: integer
 *     responses:
 *       200:
 *         description: Images uploaded successfully
 *       400:
 *         description: Invalid request
 */
router.post('/images', [
  authenticateToken,
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

    // Create location-specific directory
    const locationDir = path.join(locationsDir, location_id.toString());
    await ensureDirectoryExists(locationDir);

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
        const originalFilename = `original_${timestamp}_${index}.jpg`;
        const thumbnailFilename = `thumb_${timestamp}_${index}.jpg`;
        
        const originalPath = path.join(locationDir, originalFilename);
        const thumbnailPath = path.join(locationDir, thumbnailFilename);

        // Save files to disk
        await Promise.all([
          fs.writeFile(originalPath, originalBuffer),
          fs.writeFile(thumbnailPath, thumbnailBuffer)
        ]);

        // Generate URLs for accessing the images
        const baseUrl = `${req.protocol}://${req.get('host')}`;
        const originalUrl = `${baseUrl}/uploads/locations/${location_id}/${originalFilename}`;
        const thumbnailUrl = `${baseUrl}/uploads/locations/${location_id}/${thumbnailFilename}`;

        // Save to database
        await pool.execute(`
          INSERT INTO location_images (location_id, image_url, thumbnail_url, image_order, uploaded_by, file_size, image_width, image_height)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        `, [
          location_id,
          originalUrl,
          thumbnailUrl,
          index,
          req.user.userId,
          originalBuffer.length,
          1920,
          1080
        ]);

        return {
          url: originalUrl,
          thumbnail: thumbnailUrl,
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
 *                 type: integer
 *     responses:
 *       200:
 *         description: Videos uploaded successfully
 *       400:
 *         description: Invalid request
 */
router.post('/videos', [
  authenticateToken,
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

    // Create location-specific directory
    const locationDir = path.join(locationsDir, location_id.toString());
    await ensureDirectoryExists(locationDir);

    const uploadPromises = files.map(async (file, index) => {
      try {
        // Generate unique filenames
        const timestamp = Date.now();
        const fileExtension = file.originalname.split('.').pop() || 'mp4';
        const videoFilename = `video_${timestamp}_${index}.${fileExtension}`;
        const thumbnailFilename = `video_thumb_${timestamp}_${index}.jpg`;
        
        const videoPath = path.join(locationDir, videoFilename);
        const thumbnailPath = path.join(locationDir, thumbnailFilename);

        // Save video file to disk
        await fs.writeFile(videoPath, file.buffer);

        // Create a simple placeholder thumbnail 
        const thumbnailBuffer = await sharp({
          create: {
            width: 400,
            height: 300,
            channels: 3,
            background: { r: 100, g: 100, b: 100 }
          }
        })
        .png()
        .composite([{
          input: Buffer.from(
            `<svg width="400" height="300" xmlns="http://www.w3.org/2000/svg">
              <rect width="400" height="300" fill="#333"/>
              <circle cx="200" cy="150" r="40" fill="#666"/>
              <polygon points="180,130 180,170 220,150" fill="#fff"/>
              <text x="200" y="200" text-anchor="middle" font-family="Arial" font-size="14" fill="#fff">Video</text>
            </svg>`
          ),
          top: 0,
          left: 0
        }])
        .jpeg({ quality: 75 })
        .toBuffer();

        await fs.writeFile(thumbnailPath, thumbnailBuffer);

        // Generate URLs for accessing the videos
        const baseUrl = `${req.protocol}://${req.get('host')}`;
        const videoUrl = `${baseUrl}/uploads/locations/${location_id}/${videoFilename}`;
        const thumbnailUrl = `${baseUrl}/uploads/locations/${location_id}/${thumbnailFilename}`;

        // Save to database
        await pool.execute(`
          INSERT INTO location_videos (location_id, video_url, thumbnail_url, video_order, uploaded_by, file_size)
          VALUES (?, ?, ?, ?, ?, ?)
        `, [
          location_id,
          videoUrl,
          thumbnailUrl,
          index,
          req.user.userId,
          file.size
        ]);

        return {
          url: videoUrl,
          thumbnail: thumbnailUrl,
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
    const filename = `${req.user.userId}_${timestamp}.jpg`;
    const filePath = path.join(profilesDir, filename);

    // Save file to disk
    await fs.writeFile(filePath, processedBuffer);

    // Generate URL for accessing the image
    const baseUrl = `${req.protocol}://${req.get('host')}`;
    const imageUrl = `${baseUrl}/uploads/profiles/${filename}`;

    // Update user profile
    await pool.execute(
      'UPDATE users SET profile_image_url = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      [imageUrl, req.user.userId]
    );

    res.json({
      message: 'Profile image uploaded successfully',
      image_url: imageUrl
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

    // Extract file paths from URLs
    const originalUrl = new URL(image.image_url);
    const thumbnailUrl = new URL(image.thumbnail_url);
    
    const originalPath = path.join(__dirname, '..', originalUrl.pathname);
    const thumbnailPath = path.join(__dirname, '..', thumbnailUrl.pathname);

    // Delete files from disk
    try {
      await Promise.all([
        fs.unlink(originalPath),
        fs.unlink(thumbnailPath)
      ]);
    } catch (fileError) {
      console.warn('Error deleting files:', fileError);
      // Continue even if file deletion fails
    }

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

    // Extract file paths from URLs
    const videoUrl = new URL(video.video_url);
    const thumbnailUrl = new URL(video.thumbnail_url);
    
    const videoPath = path.join(__dirname, '..', videoUrl.pathname);
    const thumbnailPath = path.join(__dirname, '..', thumbnailUrl.pathname);

    // Delete files from disk
    try {
      await Promise.all([
        fs.unlink(videoPath),
        fs.unlink(thumbnailPath)
      ]);
    } catch (fileError) {
      console.warn('Error deleting video files:', fileError);
      // Continue even if file deletion fails
    }

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
