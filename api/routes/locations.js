const express = require('express');
const { body, query, validationResult } = require('express-validator');
const { pool } = require('../config/database');
const { authenticateToken, requirePremium } = require('../middleware/auth');

const router = express.Router();

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

    // Get images and tags for all locations
    const locationImages = {};
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

    const { limit = 20, offset = 0, category } = req.query;

    let whereClause = 'WHERE l.is_approved = TRUE';
    let params = [];

    if (category) {
      whereClause += ' AND lc.name = ?';
      params.push(category);
    }

    const query_sql = `
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
        l.views_count as view_count
      FROM locations l
      LEFT JOIN location_categories lc ON l.category_id = lc.id
      LEFT JOIN danger_levels dl ON l.danger_level_id = dl.id
      LEFT JOIN users u ON l.submitted_by = u.id
      ${whereClause}
      ORDER BY l.created_at DESC
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

    // Get images for all locations
    const locationImages = {};
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

module.exports = router;
