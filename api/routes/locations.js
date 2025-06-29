const express = require('express');
const { body, query, validationResult } = require('express-validator');
const { pool } = require('../config/database');
const { authenticateToken, requirePremium } = require('../middleware/auth');
const jwt = require('jsonwebtoken');

const router = express.Router();

// Helper function to create notifications
async function createNotification(userId, title, message, type, relatedType = null, relatedId = null) {
  try {
    await pool.execute(
      'INSERT INTO notifications (user_id, title, message, type, related_type, related_id) VALUES (?, ?, ?, ?, ?, ?)',
      [userId, title, message, type, relatedType, relatedId]
    );
  } catch (error) {
    console.error('Failed to create notification:', error);
    // Don't throw error - notifications are not critical
  }
}

/**
 * @swagger
 * components:
 *   schemas:
 *     Location:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *         title:
 *           type: string
 *         description:
 *           type: string
 *         latitude:
 *           type: number
 *         longitude:
 *           type: number
 *         address:
 *           type: string
 *         category_name:
 *           type: string
 *         danger_level:
 *           type: string
 *         like_count:
 *           type: integer
 *         bookmark_count:
 *           type: integer
 */

/**
 * @swagger
 * /api/locations/nearby:
 *   get:
 *     summary: Get locations near a specific coordinate
 *     tags: [Locations]
 *     parameters:
 *       - in: query
 *         name: lat
 *         required: true
 *         schema:
 *           type: number
 *       - in: query
 *         name: lng
 *         required: true
 *         schema:
 *           type: number
 *       - in: query
 *         name: radius
 *         schema:
 *           type: integer
 *           default: 50
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 50
 *       - in: query
 *         name: offset
 *         schema:
 *           type: integer
 *           default: 0
 *       - in: query
 *         name: category
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: List of nearby locations
 */
// Add specific routes before parameterized routes

/**
 * @swagger
 * /api/locations/categories:
 *   get:
 *     summary: Get all location categories
 *     tags: [Locations]
 *     responses:
 *       200:
 *         description: List of location categories
 */
router.get('/categories', async (req, res) => {
  try {
    const [categories] = await pool.execute(
      'SELECT id, name, icon, description, color, is_active FROM location_categories WHERE is_active = TRUE ORDER BY name'
    );

    res.json({
      success: true,
      categories: categories
    });
  } catch (error) {
    console.error('Get categories error:', error);
    res.status(500).json({
      error: 'Failed to fetch categories',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/locations/danger-levels:
 *   get:
 *     summary: Get all danger levels
 *     tags: [Locations]
 *     responses:
 *       200:
 *         description: List of danger levels
 */
router.get('/danger-levels', async (req, res) => {
  try {
    const [dangerLevels] = await pool.execute(
      'SELECT id, name, color, description, risk_level FROM danger_levels ORDER BY risk_level'
    );

    res.json({
      success: true,
      dangerLevels: dangerLevels
    });
  } catch (error) {
    console.error('Get danger levels error:', error);
    res.status(500).json({
      error: 'Failed to fetch danger levels',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/locations/tags:
 *   get:
 *     summary: Get all available tags
 *     tags: [Locations]
 *     parameters:
 *       - in: query
 *         name: popular
 *         schema:
 *           type: boolean
 *           default: false
 *         description: Return only popular tags (usage_count > 0)
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 50
 *     responses:
 *       200:
 *         description: List of tags
 */
router.get('/tags', [
  query('popular').optional().isBoolean().toBoolean(),
  query('limit').optional().isInt({ min: 1, max: 100 }).toInt()
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Validation Error',
        details: errors.array()
      });
    }

    const { popular = false, limit = 50 } = req.query;

    let whereClause = '';
    if (popular) {
      whereClause = 'WHERE usage_count > 0';
    }

    const [tags] = await pool.execute(
      `SELECT id, name, usage_count FROM tags ${whereClause} ORDER BY usage_count DESC, name ASC LIMIT ?`,
      [limit]
    );

    res.json({
      success: true,
      tags: tags
    });
  } catch (error) {
    console.error('Get tags error:', error);
    res.status(500).json({
      error: 'Failed to fetch tags',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/locations/stats:
 *   get:
 *     summary: Get location statistics
 *     tags: [Locations]
 *     responses:
 *       200:
 *         description: Location statistics
 */
router.get('/stats', async (req, res) => {
  try {
    // Get total counts
    const [totalStats] = await pool.execute(`
      SELECT 
        COUNT(*) as total_locations,
        SUM(CASE WHEN is_approved = TRUE THEN 1 ELSE 0 END) as approved_locations,
        SUM(CASE WHEN is_approved = FALSE THEN 1 ELSE 0 END) as pending_locations,
        SUM(likes_count) as total_likes,
        SUM(bookmarks_count) as total_bookmarks,
        SUM(views_count) as total_views
      FROM locations
    `);

    // Get category breakdown
    const [categoryStats] = await pool.execute(`
      SELECT 
        lc.name as category_name,
        lc.icon as category_icon,
        lc.color as category_color,
        COUNT(l.id) as location_count
      FROM location_categories lc
      LEFT JOIN locations l ON lc.id = l.category_id AND l.is_approved = TRUE
      WHERE lc.is_active = TRUE
      GROUP BY lc.id, lc.name, lc.icon, lc.color
      ORDER BY location_count DESC
    `);

    // Get danger level breakdown
    const [dangerStats] = await pool.execute(`
      SELECT 
        dl.name as danger_level,
        dl.color as danger_color,
        COUNT(l.id) as location_count
      FROM danger_levels dl
      LEFT JOIN locations l ON dl.id = l.danger_level_id AND l.is_approved = TRUE
      GROUP BY dl.id, dl.name, dl.color
      ORDER BY dl.risk_level
    `);

    res.json({
      success: true,
      stats: {
        totals: totalStats[0],
        categories: categoryStats,
        dangerLevels: dangerStats
      }
    });
  } catch (error) {
    console.error('Get stats error:', error);
    res.status(500).json({
      error: 'Failed to fetch statistics',
      message: error.message
    });
  }
});

router.get('/nearby', [
  query('lat').isFloat({ min: -90, max: 90 }).toFloat(),
  query('lng').isFloat({ min: -180, max: 180 }).toFloat(),
  query('radius').optional().isInt({ min: 1, max: 500 }).toInt(),
  query('limit').optional().isInt({ min: 1, max: 100 }).toInt(),
  query('offset').optional().isInt({ min: 0 }).toInt(),
  query('category').optional().isString().trim()
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Validation Error',
        details: errors.array()
      });
    }

    const { lat, lng, radius = 50, limit = 50, offset = 0, category } = req.query;

    // Log search for analytics (commented out - search_logs table not implemented)
    // if (req.user) {
    //   await pool.execute(
    //     'INSERT INTO search_logs (user_id, latitude, longitude, radius_km, category_filter) VALUES (?, ?, ?, ?, ?)',
    //     [req.user?.userId || null, lat, lng, radius, category ? JSON.stringify([category]) : null]
    //   );
    // }

    let whereClause = 'WHERE l.is_approved = TRUE';
    let params = [];
    
    if (category) {
      whereClause += ' AND lc.name = ?';
      params.push(category);
    }

    let query_sql = `
      SELECT 
        l.id, l.title, l.description, l.latitude, l.longitude, l.address,
        lc.name as category_name, lc.icon as category_icon,
        dl.name as danger_level, dl.color as danger_color,
        u.username as submitted_by,
        l.created_at,
        l.is_approved,
        l.likes_count as like_count,
        l.bookmarks_count as bookmark_count,
        l.comments_count as comment_count,
        l.views_count as view_count,
        (6371 * acos(cos(radians(?)) * cos(radians(l.latitude)) * 
         cos(radians(l.longitude) - radians(?)) + 
         sin(radians(?)) * sin(radians(l.latitude)))) AS distance
      FROM locations l
      LEFT JOIN location_categories lc ON l.category_id = lc.id
      LEFT JOIN danger_levels dl ON l.danger_level_id = dl.id
      LEFT JOIN users u ON l.submitted_by = u.id
      ${whereClause}
      HAVING distance <= ?
      ORDER BY distance
      LIMIT ? OFFSET ?
    `;

    const queryParams = [lat, lng, lat, ...params, radius, limit, offset];
    const [results] = await pool.execute(query_sql, queryParams);
    
    let locations = results || [];

    // Get user's bookmarks and likes if authenticated
    let userBookmarks = [];
    let userLikes = [];
    
    if (req.user) {
      const locationIds = locations.map(loc => loc.id);
      if (locationIds.length > 0) {
        const placeholders = locationIds.map(() => '?').join(',');
        
        const [bookmarks] = await pool.execute(
          `SELECT location_id FROM bookmarks WHERE user_id = ? AND location_id IN (${placeholders})`,
          [req.user.userId, ...locationIds]
        );
        userBookmarks = bookmarks.map(b => b.location_id);
        
        const [likes] = await pool.execute(
          `SELECT location_id FROM likes WHERE user_id = ? AND location_id IN (${placeholders})`,
          [req.user.userId, ...locationIds]
        );
        userLikes = likes.map(l => l.location_id);
      }
    }

    // Get images, videos and tags for all locations
    const locationImages = {};
    const locationVideos = {};
    const locationTags = {};
    
    if (locations.length > 0) {
      const locationIds = locations.map(loc => loc.id);
      const placeholders = locationIds.map(() => '?').join(',');
      
      // Get images
      const [images] = await pool.execute(
        `SELECT location_id, image_url, thumbnail_url FROM location_images WHERE location_id IN (${placeholders}) ORDER BY location_id, image_order`,
        locationIds
      );
      
      // Group images by location_id
      images.forEach(img => {
        if (!locationImages[img.location_id]) {
          locationImages[img.location_id] = [];
        }
        locationImages[img.location_id].push(img.image_url);
      });
      
      // Get videos
      const [videos] = await pool.execute(
        `SELECT location_id, video_url, thumbnail_url FROM location_videos WHERE location_id IN (${placeholders}) ORDER BY location_id, video_order`,
        locationIds
      );
      
      // Group videos by location_id
      videos.forEach(video => {
        if (!locationVideos[video.location_id]) {
          locationVideos[video.location_id] = [];
        }
        locationVideos[video.location_id].push(video.video_url);
      });
      
      // Get tags
      const [tags] = await pool.execute(
        `SELECT lt.location_id, t.name 
         FROM tags t
         JOIN location_tags lt ON t.id = lt.tag_id
         WHERE lt.location_id IN (${placeholders})`,
        locationIds
      );
      
      // Group tags by location_id
      tags.forEach(tag => {
        if (!locationTags[tag.location_id]) {
          locationTags[tag.location_id] = [];
        }
        locationTags[tag.location_id].push(tag.name);
      });
    }

    // Add user interaction flags
    locations = locations.map(location => ({
      ...location,
      is_bookmarked: userBookmarks.includes(location.id),
      is_liked: userLikes.includes(location.id),
      distance_km: parseFloat(location.distance),
      images: locationImages[location.id] || [],
      videos: locationVideos[location.id] || [],
      tags: locationTags[location.id] || []
    }));

    res.json({
      locations,
      has_more: false, // For nearby locations, we return all results within radius
      total: locations.length,
      radius_km: radius,
      center: { lat, lng }
    });
  } catch (error) {
    console.error('Nearby locations error:', error);
    res.status(500).json({
      error: 'Failed to get nearby locations',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/locations/feed:
 *   get:
 *     summary: Get recent locations feed
 *     tags: [Locations]
 *     parameters:
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 20
 *       - in: query
 *         name: offset
 *         schema:
 *           type: integer
 *           default: 0
 *       - in: query
 *         name: category
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: List of recent locations
 */
router.get('/feed', [
  query('limit').optional().isInt({ min: 1, max: 50 }).toInt(),
  query('offset').optional().isInt({ min: 0 }).toInt(),
  query('category').optional().isString().trim(),
  query('lat').optional().isFloat({ min: -90, max: 90 }).toFloat(),
  query('lng').optional().isFloat({ min: -180, max: 180 }).toFloat(),
  query('priority_radius').optional().isInt({ min: 1, max: 1000 }).toInt()
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Validation Error',
        details: errors.array()
      });
    }

    const { limit = 20, offset = 0, category, lat, lng, priority_radius = 100 } = req.query;

    let whereClause = 'WHERE l.is_approved = TRUE';
    let params = [];
    let selectFields = `
        l.id, l.title, l.description, l.latitude, l.longitude, l.address,
        lc.name as category_name, lc.icon as category_icon,
        dl.name as danger_level, dl.color as danger_color,
        u.username as submitted_by,
        l.created_at,
        l.is_approved,
        l.likes_count as like_count,
        l.bookmarks_count as bookmark_count,
        l.comments_count as comment_count,
        l.views_count as view_count`;
    
    let orderBy = 'ORDER BY l.created_at DESC';

    if (category) {
      whereClause += ' AND lc.name = ?';
      params.push(category);
    }

    // Add geographic prioritization if coordinates provided
    if (lat !== undefined && lng !== undefined) {
      selectFields += `, 
        (6371 * acos(cos(radians(?)) * cos(radians(l.latitude)) * 
         cos(radians(l.longitude) - radians(?)) + 
         sin(radians(?)) * sin(radians(l.latitude)))) AS distance`;
      
      // Priority ordering: nearby locations first, then by creation date
      orderBy = `ORDER BY 
        CASE WHEN (6371 * acos(cos(radians(?)) * cos(radians(l.latitude)) * 
                  cos(radians(l.longitude) - radians(?)) + 
                  sin(radians(?)) * sin(radians(l.latitude)))) <= ? THEN 0 ELSE 1 END,
        (6371 * acos(cos(radians(?)) * cos(radians(l.latitude)) * 
         cos(radians(l.longitude) - radians(?)) + 
         sin(radians(?)) * sin(radians(l.latitude)))),
        l.created_at DESC`;
      
      params.unshift(lat, lng, lat); // For SELECT distance calculation
      params.push(lat, lng, lat, priority_radius, lat, lng, lat); // For ORDER BY
    }

    const query_sql = `
      SELECT ${selectFields}
      FROM locations l
      LEFT JOIN location_categories lc ON l.category_id = lc.id
      LEFT JOIN danger_levels dl ON l.danger_level_id = dl.id
      LEFT JOIN users u ON l.submitted_by = u.id
      ${whereClause}
      ${orderBy}
      LIMIT ? OFFSET ?
    `;

    params.push(limit, offset);
    const [locations] = await pool.execute(query_sql, params);

    // Get user interactions if authenticated
    let userBookmarks = [];
    let userLikes = [];
    
    if (req.user && locations.length > 0) {
      const locationIds = locations.map(loc => loc.id);
      const placeholders = locationIds.map(() => '?').join(',');
      
      const [bookmarks] = await pool.execute(
        `SELECT location_id FROM bookmarks WHERE user_id = ? AND location_id IN (${placeholders})`,
        [req.user.userId, ...locationIds]
      );
      userBookmarks = bookmarks.map(b => b.location_id);
      
      const [likes] = await pool.execute(
        `SELECT location_id FROM likes WHERE user_id = ? AND location_id IN (${placeholders})`,
        [req.user.userId, ...locationIds]
      );
      userLikes = likes.map(l => l.location_id);
    }

    // Get images and videos for all locations
    const locationImages = {};
    const locationVideos = {};
    const locationTags = {};
    
    if (locations.length > 0) {
      const locationIds = locations.map(loc => loc.id);
      const placeholders = locationIds.map(() => '?').join(',');
      
      // Get images
      const [images] = await pool.execute(
        `SELECT location_id, image_url, thumbnail_url FROM location_images WHERE location_id IN (${placeholders}) ORDER BY location_id, image_order`,
        locationIds
      );
      
      // Group images by location_id
      images.forEach(img => {
        if (!locationImages[img.location_id]) {
          locationImages[img.location_id] = [];
        }
        locationImages[img.location_id].push(img.image_url);
      });
      
      // Get videos
      const [videos] = await pool.execute(
        `SELECT location_id, video_url, thumbnail_url FROM location_videos WHERE location_id IN (${placeholders}) ORDER BY location_id, video_order`,
        locationIds
      );
      
      // Group videos by location_id
      videos.forEach(video => {
        if (!locationVideos[video.location_id]) {
          locationVideos[video.location_id] = [];
        }
        locationVideos[video.location_id].push(video.video_url);
      });
      
      // Get tags
      const [tags] = await pool.execute(
        `SELECT lt.location_id, t.name 
         FROM tags t
         JOIN location_tags lt ON t.id = lt.tag_id
         WHERE lt.location_id IN (${placeholders})`,
        locationIds
      );
      
      // Group tags by location_id
      tags.forEach(tag => {
        if (!locationTags[tag.location_id]) {
          locationTags[tag.location_id] = [];
        }
        locationTags[tag.location_id].push(tag.name);
      });
    }

    const enrichedLocations = locations.map(location => ({
      ...location,
      is_bookmarked: userBookmarks.includes(location.id),
      is_liked: userLikes.includes(location.id),
      images: locationImages[location.id] || [],
      videos: locationVideos[location.id] || [],
      tags: locationTags[location.id] || []
    }));

    res.json({
      locations: enrichedLocations,
      has_more: locations.length === limit
    });
  } catch (error) {
    console.error('Feed locations error:', error);
    res.status(500).json({
      error: 'Failed to get locations feed',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/locations/{id}:
 *   get:
 *     summary: Get location details by ID
 *     tags: [Locations]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Location details
 *       404:
 *         description: Location not found
 */
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const [locations] = await pool.execute(`
      SELECT 
        l.id, l.title, l.description, l.latitude, l.longitude, l.address,
        lc.name as category_name, lc.icon as category_icon,
        dl.name as danger_level, dl.color as danger_color,
        u.username as submitted_by,
        l.created_at,
        l.likes_count as like_count,
        l.bookmarks_count as bookmark_count,
        l.comments_count as comment_count,
        l.views_count as view_count
      FROM locations l
      LEFT JOIN location_categories lc ON l.category_id = lc.id
      LEFT JOIN danger_levels dl ON l.danger_level_id = dl.id
      LEFT JOIN users u ON l.submitted_by = u.id
      WHERE l.id = ? AND l.is_approved = TRUE
    `, [id]);

    if (locations.length === 0) {
      return res.status(404).json({
        error: 'Location not found'
      });
    }

    const location = locations[0];

    // Get location images
    const [images] = await pool.execute(
      'SELECT image_url, thumbnail_url FROM location_images WHERE location_id = ? ORDER BY image_order',
      [id]
    );

    // Get location videos
    const [videos] = await pool.execute(
      'SELECT video_url, thumbnail_url FROM location_videos WHERE location_id = ? ORDER BY video_order',
      [id]
    );

    // Get location tags
    const [tags] = await pool.execute(`
      SELECT t.name 
      FROM tags t
      JOIN location_tags lt ON t.id = lt.tag_id
      WHERE lt.location_id = ?
    `, [id]);

    // Check user interactions if authenticated
    let isBookmarked = false;
    let isLiked = false;

    if (req.user) {
      const [bookmarks] = await pool.execute(
        'SELECT 1 FROM bookmarks WHERE user_id = ? AND location_id = ?',
        [req.user.userId, id]
      );
      isBookmarked = bookmarks.length > 0;

      const [likes] = await pool.execute(
        'SELECT 1 FROM likes WHERE user_id = ? AND location_id = ?',
        [req.user.userId, id]
      );
      isLiked = likes.length > 0;

      // Increment view count
      await pool.execute(
        'UPDATE locations SET views_count = views_count + 1 WHERE id = ?',
        [id]
      );
    }

    res.json({
      location: {
        ...location,
        images: images.map(img => ({
          url: img.image_url,
          thumbnail: img.thumbnail_url
        })),
        videos: videos.map(video => ({
          url: video.video_url,
          thumbnail: video.thumbnail_url
        })),
        tags: tags.map(tag => tag.name),
        is_bookmarked: isBookmarked,
        is_liked: isLiked
      }
    });
  } catch (error) {
    console.error('Get location error:', error);
    res.status(500).json({
      error: 'Failed to get location',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/locations:
 *   post:
 *     summary: Submit a new location
 *     tags: [Locations]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - title
 *               - description
 *               - latitude
 *               - longitude
 *               - category_id
 *               - danger_level_id
 *             properties:
 *               title:
 *                 type: string
 *               description:
 *                 type: string
 *               latitude:
 *                 type: number
 *               longitude:
 *                 type: number
 *               address:
 *                 type: string
 *               category_id:
 *                 type: integer
 *               danger_level_id:
 *                 type: integer
 *               tags:
 *                 type: array
 *                 items:
 *                   type: string
 *     responses:
 *       201:
 *         description: Location submitted successfully
 *       400:
 *         description: Validation error
 *       401:
 *         description: Unauthorized
 */
router.post('/', [
  authenticateToken,
  body('title').isLength({ min: 3, max: 255 }).trim(),
  body('description').isLength({ min: 5, max: 2000 }).trim(),
  body('latitude').isFloat({ min: -90, max: 90 }),
  body('longitude').isFloat({ min: -180, max: 180 }),
  body('address').optional({ checkFalsy: true }).isLength({ max: 500 }).trim(),
  body('category_id').isInt({ min: 1 }),
  body('danger_level_id').isInt({ min: 1 }),
  body('tags').optional().isArray()
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Validation Error',
        details: errors.array()
      });
    }

    const {
      title,
      description,
      latitude,
      longitude,
      address,
      category_id,
      danger_level_id,
      tags = []
    } = req.body;

    // Check if category and danger level exist
    const [categories] = await pool.execute('SELECT id FROM location_categories WHERE id = ?', [category_id]);
    const [dangerLevels] = await pool.execute('SELECT id FROM danger_levels WHERE id = ?', [danger_level_id]);

    if (categories.length === 0) {
      return res.status(400).json({
        error: 'Invalid category'
      });
    }

    if (dangerLevels.length === 0) {
      return res.status(400).json({
        error: 'Invalid danger level'
      });
    }

    // Insert location
    const [result] = await pool.execute(`
      INSERT INTO locations (title, description, latitude, longitude, address, category_id, danger_level_id, submitted_by)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `, [title, description, latitude, longitude, address, category_id, danger_level_id, req.user.userId]);

    const locationId = result.insertId;

    // Add tags if provided
    if (tags.length > 0) {
      for (const tagName of tags) {
        // Insert tag if it doesn't exist
        await pool.execute(
          'INSERT IGNORE INTO tags (name) VALUES (?)',
          [tagName.toLowerCase().trim()]
        );

        // Get tag ID
        const [tagResult] = await pool.execute(
          'SELECT id FROM tags WHERE name = ?',
          [tagName.toLowerCase().trim()]
        );

        if (tagResult.length > 0) {
          // Link tag to location
          await pool.execute(
            'INSERT IGNORE INTO location_tags (location_id, tag_id) VALUES (?, ?)',
            [locationId, tagResult[0].id]
          );
        }
      }
    }

    res.status(201).json({
      message: 'Location submitted successfully',
      location_id: locationId,
      status: 'pending_approval'
    });
  } catch (error) {
    console.error('Submit location error:', error);
    res.status(500).json({
      error: 'Failed to submit location',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/locations/{id}/like:
 *   post:
 *     summary: Like/unlike a location
 *     tags: [Locations]
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
 *         description: Like status updated
 *       404:
 *         description: Location not found
 */
router.post('/:id/like', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;

    // Check if location exists
    const [locations] = await pool.execute(
      'SELECT id FROM locations WHERE id = ? AND is_approved = TRUE',
      [id]
    );

    if (locations.length === 0) {
      return res.status(404).json({
        error: 'Location not found'
      });
    }

    // Check if already liked
    const [existingLikes] = await pool.execute(
      'SELECT id FROM likes WHERE user_id = ? AND location_id = ?',
      [req.user.userId, id]
    );

    let isLiked;
    if (existingLikes.length > 0) {
      // Unlike
      await pool.execute(
        'DELETE FROM likes WHERE user_id = ? AND location_id = ?',
        [req.user.userId, id]
      );
      isLiked = false;
    } else {
      // Like
      await pool.execute(
        'INSERT INTO likes (user_id, location_id) VALUES (?, ?)',
        [req.user.userId, id]
      );
      isLiked = true;
    }

    // Get updated like count
    const [likeCount] = await pool.execute(
      'SELECT COUNT(*) as count FROM likes WHERE location_id = ?',
      [id]
    );

    // Update the likes_count in the locations table
    await pool.execute(
      'UPDATE locations SET likes_count = ? WHERE id = ?',
      [likeCount[0].count, id]
    );

    // Create notification
    await createNotification(req.user.userId, 'Location Liked', `You have ${isLiked ? 'liked' : 'unliked'} a location.`, 'like', 'location', id);

    res.json({
      success: true,
      isLiked: isLiked,
      likeCount: parseInt(likeCount[0].count)
    });
  } catch (error) {
    console.error('Like location error:', error);
    res.status(500).json({
      error: 'Failed to update like status',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/locations/{id}/bookmark:
 *   post:
 *     summary: Bookmark/unbookmark a location
 *     tags: [Locations]
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
 *         description: Bookmark status updated
 *       404:
 *         description: Location not found
 */
router.post('/:id/bookmark', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;

    // Check if location exists
    const [locations] = await pool.execute(
      'SELECT id FROM locations WHERE id = ? AND is_approved = TRUE',
      [id]
    );

    if (locations.length === 0) {
      return res.status(404).json({
        error: 'Location not found'
      });
    }

    // Check if already bookmarked
    const [existingBookmarks] = await pool.execute(
      'SELECT id FROM bookmarks WHERE user_id = ? AND location_id = ?',
      [req.user.userId, id]
    );

    let isBookmarked;
    if (existingBookmarks.length > 0) {
      // Remove bookmark
      await pool.execute(
        'DELETE FROM bookmarks WHERE user_id = ? AND location_id = ?',
        [req.user.userId, id]
      );
      isBookmarked = false;
    } else {
      // Add bookmark
      await pool.execute(
        'INSERT INTO bookmarks (user_id, location_id) VALUES (?, ?)',
        [req.user.userId, id]
      );
      isBookmarked = true;
    }

    // Get updated bookmark count
    const [bookmarkCount] = await pool.execute(
      'SELECT COUNT(*) as count FROM bookmarks WHERE location_id = ?',
      [id]
    );

    // Update the bookmarks_count in the locations table
    await pool.execute(
      'UPDATE locations SET bookmarks_count = ? WHERE id = ?',
      [bookmarkCount[0].count, id]
    );

    // Create notification
    await createNotification(req.user.userId, 'Location Bookmarked', `You have ${isBookmarked ? 'bookmarked' : 'unbookmarked'} a location.`, 'bookmark', 'location', id);

    res.json({
      success: true,
      isBookmarked: isBookmarked,
      bookmarkCount: parseInt(bookmarkCount[0].count)
    });
  } catch (error) {
    console.error('Bookmark location error:', error);
    res.status(500).json({
      error: 'Failed to update bookmark status',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/locations/{id}/visit:
 *   post:
 *     summary: Track a location visit
 *     tags: [Locations]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Visit tracked successfully
 */
router.post('/:id/visit', async (req, res) => {
  try {
    const { id } = req.params;

    // Check if location exists
    const [locations] = await pool.execute(
      'SELECT id FROM locations WHERE id = ? AND is_approved = TRUE',
      [id]
    );

    if (locations.length === 0) {
      return res.status(404).json({
        error: 'Location not found'
      });
    }

    // Get user ID if authenticated, otherwise track anonymously
    const userId = req.user?.id || null;
    const ipAddress = req.ip || req.connection.remoteAddress;
    const userAgent = req.get('User-Agent');

    // Insert visit record
    await pool.execute(
      'INSERT INTO location_visits (location_id, user_id, ip_address, user_agent) VALUES (?, ?, ?, ?)',
      [id, userId, ipAddress, userAgent]
    );

    // Update view count
    await pool.execute(
      'UPDATE locations SET views_count = views_count + 1 WHERE id = ?',
      [id]
    );

    // Get updated view count
    const [viewCount] = await pool.execute(
      'SELECT views_count FROM locations WHERE id = ?',
      [id]
    );

    // Create notification if user is authenticated
    if (userId) {
      await createNotification(userId, 'Location Visited', `You have visited a location.`, 'visit', 'location', id);
    }

    res.json({
      success: true,
      message: 'Visit tracked successfully',
      viewCount: viewCount[0].views_count
    });
  } catch (error) {
    console.error('Track visit error:', error);
    res.status(500).json({
      error: 'Failed to track visit',
      message: error.message
    });
  }
});

// Search locations
router.get('/search', [
  query('q').optional().isLength({ min: 1, max: 100 }).trim(),
  query('lat').optional().isFloat({ min: -90, max: 90 }),
  query('lng').optional().isFloat({ min: -180, max: 180 }),
  query('radius').optional().isInt({ min: 1, max: 500 }),
  query('category').optional().isString(),
  query('limit').optional().isInt({ min: 1, max: 50 }),
  query('offset').optional().isInt({ min: 0 })
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Validation Error',
        details: errors.array()
      });
    }

    const { q, lat, lng, radius = 50, category, limit = 20, offset = 0 } = req.query;

    let whereClause = 'WHERE l.is_approved = TRUE';
    let params = [];

    // Text search
    if (q) {
      whereClause += ' AND (MATCH(l.title, l.description) AGAINST(? IN NATURAL LANGUAGE MODE) OR l.title LIKE ? OR l.address LIKE ?)';
      params.push(q, `%${q}%`, `%${q}%`);
    }

    // Category filter
    if (category) {
      whereClause += ' AND lc.name = ?';
      params.push(category);
    }

    let orderClause = 'ORDER BY l.created_at DESC';
    
    // Location-based search
    if (lat && lng) {
      whereClause += ` AND (6371 * acos(cos(radians(?)) * cos(radians(l.latitude)) * 
        cos(radians(l.longitude) - radians(?)) + 
        sin(radians(?)) * sin(radians(l.latitude)))) <= ?`;
      params.push(lat, lng, lat, radius);
      orderClause = `ORDER BY (6371 * acos(cos(radians(?)) * cos(radians(l.latitude)) * 
        cos(radians(l.longitude) - radians(?)) + 
        sin(radians(?)) * sin(radians(l.latitude))))`;
      params.push(lat, lng, lat);
    }

    const query_sql = `
      SELECT 
        l.id, l.title, l.description, l.latitude, l.longitude, l.address,
        lc.name as category_name, lc.icon as category_icon,
        dl.name as danger_level, dl.color as danger_color,
        u.username as submitted_by,
        l.created_at,
        l.likes_count as like_count,
        l.bookmarks_count as bookmark_count
      FROM locations l
      LEFT JOIN location_categories lc ON l.category_id = lc.id
      LEFT JOIN danger_levels dl ON l.danger_level_id = dl.id
      LEFT JOIN users u ON l.submitted_by = u.id
      ${whereClause}
      ${orderClause}
      LIMIT ? OFFSET ?
    `;

    params.push(limit, offset);
    const [locations] = await pool.execute(query_sql, params);

    // Log search for analytics (commented out - search_logs table not implemented)
    // if (req.user) {
    //   await pool.execute(
    //     'INSERT INTO search_logs (user_id, search_query, latitude, longitude, radius_km, results_count) VALUES (?, ?, ?, ?, ?, ?)',
    //     [req.user.userId, q || null, lat || null, lng || null, radius, locations.length]
    //   );
    // }

    res.json({
      locations,
      query: q,
      total_results: locations.length,
      has_more: locations.length === limit
    });
  } catch (error) {
    console.error('Search locations error:', error);
    res.status(500).json({
      error: 'Search failed',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/locations/{id}/details:
 *   get:
 *     summary: Get detailed information about a specific location
 *     tags: [Locations]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: Detailed location information
 */
// Optional authentication middleware for location details
const optionalAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (token) {
      // If token is provided, try to authenticate
      const decoded = jwt.verify(token, 'your-super-secret-jwt-key-change-in-production');
      
      const [users] = await pool.execute(
        'SELECT id, username, email, is_premium FROM users WHERE id = ? AND is_active = TRUE',
        [decoded.userId]
      );

      if (users.length > 0) {
        req.user = {
          id: decoded.userId,
          userId: decoded.userId,
          username: decoded.username,
          isPremium: users[0].is_premium
        };
      }
    }
    // If no token or invalid token, continue without user
    next();
  } catch (error) {
    // If authentication fails, continue without user
    console.log('[Optional Auth] Authentication failed, continuing without user:', error.message);
    next();
  }
};

router.get('/:id/details', optionalAuth, async (req, res) => {
  try {
    const locationId = req.params.id;
    console.log(`[Location Details] Request for location ${locationId}`);
    console.log(`[Location Details] Authorization header:`, req.headers.authorization ? 'Present' : 'Missing');
    console.log(`[Location Details] req.user:`, req.user ? `ID: ${req.user.id}, Username: ${req.user.username}` : 'Not authenticated');
    
    // Get detailed location info with all relationships
    const [locationResult] = await pool.execute(`
      SELECT 
        l.id,
        l.title,
        l.description,
        l.latitude,
        l.longitude,
        l.address,
        l.views_count,
        l.likes_count,
        l.bookmarks_count,
        l.comments_count,
        l.created_at as submission_date,
        l.featured,
        lc.name as category_name,
        lc.icon as category_icon,
        lc.color as category_color,
        dl.name as danger_level,
        dl.color as danger_color,
        dl.description as danger_description,
        dl.risk_level,
        u.username as submitted_by_username,
        u.profile_image_url as submitted_by_avatar
      FROM locations l
      LEFT JOIN location_categories lc ON l.category_id = lc.id
      LEFT JOIN danger_levels dl ON l.danger_level_id = dl.id
      LEFT JOIN users u ON l.submitted_by = u.id
      WHERE l.id = ? AND l.is_approved = 1 AND l.deleted_at IS NULL
    `, [locationId]);

    if (locationResult.length === 0) {
      return res.status(404).json({
        error: 'Location not found'
      });
    }

    const location = locationResult[0];

    // Get location images
    const [images] = await pool.execute(`
      SELECT image_url, thumbnail_url, alt_text as caption
      FROM location_images 
      WHERE location_id = ? 
      ORDER BY image_order ASC, created_at ASC
    `, [locationId]);

    // Get location videos
    const [videos] = await pool.execute(`
      SELECT video_url, thumbnail_url, NULL as caption
      FROM location_videos 
      WHERE location_id = ? 
      ORDER BY video_order ASC, created_at ASC
    `, [locationId]);

    // Get location tags
    const [tags] = await pool.execute(`
      SELECT t.name, t.id
      FROM location_tags lt
      JOIN tags t ON lt.tag_id = t.id
      WHERE lt.location_id = ?
    `, [locationId]);

    // Get timeline events (location visits, updates, etc.)
    const [timeline] = await pool.execute(`
      SELECT 
        'visit' as event_type,
        lv.visited_at as timestamp,
        CONCAT('Location visited by ', u.username) as description,
        u.username,
        u.profile_image_url as avatar
      FROM location_visits lv
      JOIN users u ON lv.user_id = u.id
      WHERE lv.location_id = ?
      
      UNION ALL
      
      SELECT 
        'submission' as event_type,
        l.created_at as timestamp,
        CONCAT('Location submitted by ', u.username) as description,
        u.username,
        u.profile_image_url as avatar
      FROM locations l
      JOIN users u ON l.submitted_by = u.id
      WHERE l.id = ?
      
      ORDER BY timestamp DESC
      LIMIT 10
    `, [locationId, locationId]);

    // Check if user liked/bookmarked (if authenticated)
    let userInteractions = {
      isLiked: false,
      isBookmarked: false,
      hasVisited: false
    };

    if (req.user) {
      console.log(`[Location Details] Checking interactions for user ${req.user.id} and location ${locationId}`);
      
      const [interactions] = await pool.execute(`
        SELECT 
          EXISTS(SELECT 1 FROM likes WHERE user_id = ? AND location_id = ?) as is_liked,
          EXISTS(SELECT 1 FROM bookmarks WHERE user_id = ? AND location_id = ?) as is_bookmarked,
          EXISTS(SELECT 1 FROM location_visits WHERE user_id = ? AND location_id = ?) as has_visited
      `, [req.user.id, locationId, req.user.id, locationId, req.user.id, locationId]);
      
      console.log(`[Location Details] Raw interactions query result:`, interactions[0]);
      
      if (interactions.length > 0) {
        userInteractions = {
          isLiked: !!interactions[0].is_liked,
          isBookmarked: !!interactions[0].is_bookmarked,
          hasVisited: !!interactions[0].has_visited
        };
        console.log(`[Location Details] Final userInteractions:`, userInteractions);
      }
    } else {
      console.log(`[Location Details] No authenticated user found`);
    }

    res.json({
      success: true,
      location: {
        ...location,
        images,
        videos,
        tags: tags.map(tag => tag.name),
        timeline,
        userInteractions
      }
    });

  } catch (error) {
    console.error('Get location details error:', error);
    res.status(500).json({
      error: 'Failed to fetch location details',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/locations/{id}/comments:
 *   get:
 *     summary: Get comments for a specific location
 *     tags: [Comments]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 20
 *       - in: query
 *         name: offset
 *         schema:
 *           type: integer
 *           default: 0
 *     responses:
 *       200:
 *         description: List of comments for the location
 */
router.get('/:id/comments', optionalAuth, [
  query('limit').optional().isInt({ min: 1, max: 50 }).toInt(),
  query('offset').optional().isInt({ min: 0 }).toInt()
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Validation Error',
        details: errors.array()
      });
    }

    const locationId = req.params.id;
    const { limit = 20, offset = 0 } = req.query;
    
    console.log(`[Comments] Request for location ${locationId}, limit: ${limit}, offset: ${offset}`);
    console.log(`[Comments] User authenticated:`, req.user ? `ID: ${req.user.id}` : 'No');

    // Get comments with user info and reply counts
    console.log(`[Comments] Executing SQL query with params: locationId=${locationId}, limit=${limit}, offset=${offset}`);
    const [comments] = await pool.execute(`
      SELECT 
        c.id,
        c.comment_text,
        c.likes_count,
        c.created_at,
        c.updated_at,
        c.parent_comment_id,
        u.id as user_id,
        u.username,
        u.profile_image_url as avatar,
        (SELECT COUNT(*) FROM comments WHERE parent_comment_id = c.id AND is_approved = 1) as reply_count
      FROM comments c
      JOIN users u ON c.user_id = u.id
      WHERE c.location_id = ? AND c.is_approved = 1 AND c.parent_comment_id IS NULL
      ORDER BY c.created_at DESC
      LIMIT ? OFFSET ?
    `, [locationId, limit, offset]);
    
    // Convert reply_count from string to integer
    comments.forEach(comment => {
      comment.reply_count = parseInt(comment.reply_count, 10);
    });
    
    console.log(`[Comments] Found ${comments.length} comments:`, comments.map(c => ({ id: c.id, text: c.comment_text, user: c.username, replies: c.reply_count })));

    // Get replies for each comment
    for (let comment of comments) {
      const [replies] = await pool.execute(`
        SELECT 
          c.id,
          c.comment_text,
          c.likes_count,
          c.created_at,
          c.updated_at,
          u.id as user_id,
          u.username,
          u.profile_image_url as avatar
        FROM comments c
        JOIN users u ON c.user_id = u.id
        WHERE c.parent_comment_id = ? AND c.is_approved = 1
        ORDER BY c.created_at ASC
        LIMIT 5
      `, [comment.id]);
      
      comment.replies = replies;
    }

    // Get total comment count
    const [countResult] = await pool.execute(
      'SELECT COUNT(*) as total FROM comments WHERE location_id = ? AND is_approved = 1 AND parent_comment_id IS NULL',
      [locationId]
    );

    const totalCount = parseInt(countResult[0].total, 10);
    
    console.log(`[Comments] Total count: ${totalCount}, returning ${comments.length} comments`);

    const response = {
      success: true,
      comments,
      pagination: {
        total: totalCount,
        limit,
        offset,
        hasMore: offset + limit < totalCount
      }
    };
    
    console.log(`[Comments] Response:`, JSON.stringify(response, null, 2));
    res.json(response);

  } catch (error) {
    console.error('Get comments error:', error);
    res.status(500).json({
      error: 'Failed to fetch comments',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/locations/{id}/comments:
 *   post:
 *     summary: Add a comment to a location
 *     tags: [Comments]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               comment_text:
 *                 type: string
 *                 minLength: 1
 *                 maxLength: 1000
 *               parent_comment_id:
 *                 type: integer
 *                 nullable: true
 *     responses:
 *       201:
 *         description: Comment created successfully
 */
router.post('/:id/comments', authenticateToken, [
  body('comment_text').trim().isLength({ min: 1, max: 1000 }).withMessage('Comment must be between 1 and 1000 characters'),
  body('parent_comment_id').optional().isInt().withMessage('Parent comment ID must be an integer')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Validation Error',
        details: errors.array()
      });
    }

    const locationId = req.params.id;
    const { comment_text, parent_comment_id = null } = req.body;
    const userId = req.user.id;

    // Verify location exists and is approved
    const [locationCheck] = await pool.execute(
      'SELECT id FROM locations WHERE id = ? AND is_approved = 1 AND deleted_at IS NULL',
      [locationId]
    );

    if (locationCheck.length === 0) {
      return res.status(404).json({
        error: 'Location not found'
      });
    }

    // If replying to a comment, verify parent comment exists
    if (parent_comment_id) {
      const [parentCheck] = await pool.execute(
        'SELECT id FROM comments WHERE id = ? AND location_id = ? AND is_approved = 1',
        [parent_comment_id, locationId]
      );

      if (parentCheck.length === 0) {
        return res.status(404).json({
          error: 'Parent comment not found'
        });
      }
    }

    // Insert comment
    const [result] = await pool.execute(`
      INSERT INTO comments (location_id, user_id, comment_text, parent_comment_id)
      VALUES (?, ?, ?, ?)
    `, [locationId, userId, comment_text, parent_comment_id]);

    // Update location comment count
    await pool.execute(
      'UPDATE locations SET comments_count = comments_count + 1 WHERE id = ?',
      [locationId]
    );

    // Get the created comment with user info
    const [commentResult] = await pool.execute(`
      SELECT 
        c.id,
        c.comment_text,
        c.likes_count,
        c.created_at,
        c.updated_at,
        c.parent_comment_id,
        u.id as user_id,
        u.username,
        u.profile_image_url as avatar
      FROM comments c
      JOIN users u ON c.user_id = u.id
      WHERE c.id = ?
    `, [result.insertId]);

    // Create notification for location owner (if not commenting on own location)
    const [locationOwner] = await pool.execute(
      'SELECT submitted_by FROM locations WHERE id = ?',
      [locationId]
    );

    if (locationOwner[0]?.submitted_by && locationOwner[0].submitted_by !== userId) {
      await createNotification(
        locationOwner[0].submitted_by,
        'New Comment',
        `${req.user.username} commented on your location`,
        'comment',
        'location',
        locationId
      );
    }

    res.status(201).json({
      success: true,
      message: 'Comment added successfully',
      comment: commentResult[0]
    });

  } catch (error) {
    console.error('Add comment error:', error);
    res.status(500).json({
      error: 'Failed to add comment',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/locations/{id}/toggle-like:
 *   post:
 *     summary: Toggle like status for a location
 *     tags: [Locations]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: Like status toggled successfully
 */
router.post('/:id/toggle-like', authenticateToken, async (req, res) => {
  try {
    const locationId = req.params.id;
    const userId = req.user.id;
    
    console.log('Toggle like request:', { locationId, userId, user: req.user });

    // Check if location exists and is approved
    const [locationCheck] = await pool.execute(
      'SELECT id FROM locations WHERE id = ? AND is_approved = 1 AND deleted_at IS NULL',
      [locationId]
    );

    if (locationCheck.length === 0) {
      return res.status(404).json({
        error: 'Location not found'
      });
    }

    // Check if already liked
    const [existingLike] = await pool.execute(
      'SELECT id FROM likes WHERE user_id = ? AND location_id = ?',
      [userId, locationId]
    );

    if (existingLike.length > 0) {
      // Remove like
      await pool.execute(
        'DELETE FROM likes WHERE user_id = ? AND location_id = ?',
        [userId, locationId]
      );
      
      // Decrease like count
      await pool.execute(
        'UPDATE locations SET likes_count = GREATEST(0, likes_count - 1) WHERE id = ?',
        [locationId]
      );

      res.json({
        success: true,
        message: 'Like removed',
        isLiked: false
      });
    } else {
      // Add like
      await pool.execute(
        'INSERT INTO likes (user_id, location_id) VALUES (?, ?)',
        [userId, locationId]
      );
      
      // Increase like count
      await pool.execute(
        'UPDATE locations SET likes_count = likes_count + 1 WHERE id = ?',
        [locationId]
      );

      res.json({
        success: true,
        message: 'Location liked',
        isLiked: true
      });
    }

  } catch (error) {
    console.error('Toggle like error:', error);
    res.status(500).json({
      error: 'Failed to toggle like',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/locations/{id}/toggle-bookmark:
 *   post:
 *     summary: Toggle bookmark status for a location
 *     tags: [Locations]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: Bookmark status toggled successfully
 */
router.post('/:id/toggle-bookmark', authenticateToken, async (req, res) => {
  try {
    const locationId = req.params.id;
    const userId = req.user.id;
    
    console.log('Toggle bookmark request:', { locationId, userId, user: req.user });

    // Check if location exists and is approved
    const [locationCheck] = await pool.execute(
      'SELECT id FROM locations WHERE id = ? AND is_approved = 1 AND deleted_at IS NULL',
      [locationId]
    );

    if (locationCheck.length === 0) {
      return res.status(404).json({
        error: 'Location not found'
      });
    }

    // Check if already bookmarked
    const [existingBookmark] = await pool.execute(
      'SELECT id FROM bookmarks WHERE user_id = ? AND location_id = ?',
      [userId, locationId]
    );

    if (existingBookmark.length > 0) {
      // Remove bookmark
      await pool.execute(
        'DELETE FROM bookmarks WHERE user_id = ? AND location_id = ?',
        [userId, locationId]
      );
      
      // Decrease bookmark count
      await pool.execute(
        'UPDATE locations SET bookmarks_count = GREATEST(0, bookmarks_count - 1) WHERE id = ?',
        [locationId]
      );

      res.json({
        success: true,
        message: 'Bookmark removed',
        isBookmarked: false
      });
    } else {
      // Add bookmark
      await pool.execute(
        'INSERT INTO bookmarks (user_id, location_id) VALUES (?, ?)',
        [userId, locationId]
      );
      
      // Increase bookmark count
      await pool.execute(
        'UPDATE locations SET bookmarks_count = bookmarks_count + 1 WHERE id = ?',
        [locationId]
      );

      res.json({
        success: true,
        message: 'Location bookmarked',
        isBookmarked: true
      });
    }

  } catch (error) {
    console.error('Toggle bookmark error:', error);
    res.status(500).json({
      error: 'Failed to toggle bookmark',
      message: error.message
    });
  }
});

module.exports = router;
