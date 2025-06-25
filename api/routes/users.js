const express = require('express');
const { body, query, validationResult } = require('express-validator');
const { pool } = require('../config/database');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

/**
 * @swagger
 * /api/users/profile:
 *   get:
 *     summary: Get user profile with statistics
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: User profile retrieved successfully
 */
router.get('/profile', authenticateToken, async (req, res) => {
  try {
    const [users] = await pool.execute(`
      SELECT 
        u.id, u.username, u.email, u.age, u.is_premium, u.profile_image_url, u.created_at,
        COUNT(DISTINCT l.id) as submitted_locations,
        COUNT(DISTINCT CASE WHEN l.is_approved = TRUE THEN l.id END) as approved_locations,
        COUNT(DISTINCT b.id) as bookmarked_locations,
        COUNT(DISTINCT lk.id) as liked_locations
      FROM users u
      LEFT JOIN locations l ON u.id = l.submitted_by
      LEFT JOIN bookmarks b ON u.id = b.user_id
      LEFT JOIN likes lk ON u.id = lk.user_id
      WHERE u.id = ?
      GROUP BY u.id
    `, [req.user.userId]);

    if (users.length === 0) {
      return res.status(404).json({
        error: 'User not found'
      });
    }

    const user = users[0];

    // Get user preferences
    const [preferences] = await pool.execute(`
      SELECT lc.name, lc.icon 
      FROM user_preferences up
      JOIN location_categories lc ON up.category_id = lc.id
      WHERE up.user_id = ?
    `, [req.user.userId]);

    user.preferences = preferences;

    res.json({ user });
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({
      error: 'Failed to get profile',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/users/profile:
 *   put:
 *     summary: Update user profile
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               username:
 *                 type: string
 *               age:
 *                 type: integer
 *               profile_image_url:
 *                 type: string
 *     responses:
 *       200:
 *         description: Profile updated successfully
 */
router.put('/profile', [
  authenticateToken,
  body('username').optional().isLength({ min: 3, max: 50 }).trim().escape(),
  body('age').optional().isInt({ min: 13, max: 120 }),
  body('profile_image_url').optional().isURL()
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Validation Error',
        details: errors.array()
      });
    }

    const updates = {};
    const values = [];
    
    if (req.body.username) {
      // Check if username is already taken
      const [existing] = await pool.execute(
        'SELECT id FROM users WHERE username = ? AND id != ?',
        [req.body.username, req.user.userId]
      );
      
      if (existing.length > 0) {
        return res.status(409).json({
          error: 'Username already taken'
        });
      }
      
      updates.username = '?';
      values.push(req.body.username);
    }
    
    if (req.body.age) {
      updates.age = '?';
      values.push(req.body.age);
    }
    
    if (req.body.profile_image_url) {
      updates.profile_image_url = '?';
      values.push(req.body.profile_image_url);
    }

    if (Object.keys(updates).length === 0) {
      return res.status(400).json({
        error: 'No valid fields to update'
      });
    }

    const setClause = Object.keys(updates).map(key => `${key} = ${updates[key]}`).join(', ');
    values.push(req.user.userId);

    await pool.execute(
      `UPDATE users SET ${setClause}, updated_at = CURRENT_TIMESTAMP WHERE id = ?`,
      values
    );

    res.json({
      message: 'Profile updated successfully'
    });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({
      error: 'Failed to update profile',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/users/preferences:
 *   post:
 *     summary: Update user preferences
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               category_ids:
 *                 type: array
 *                 items:
 *                   type: integer
 *     responses:
 *       200:
 *         description: Preferences updated successfully
 */
router.post('/preferences', [
  authenticateToken,
  body('category_ids').isArray().custom((value) => {
    return value.every(id => Number.isInteger(id) && id > 0);
  })
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Validation Error',
        details: errors.array()
      });
    }

    const { category_ids } = req.body;

    // Remove existing preferences
    await pool.execute(
      'DELETE FROM user_preferences WHERE user_id = ?',
      [req.user.userId]
    );

    // Add new preferences
    if (category_ids.length > 0) {
      const values = category_ids.map(id => [req.user.userId, id]);
      const placeholders = values.map(() => '(?, ?)').join(', ');
      
      await pool.execute(
        `INSERT INTO user_preferences (user_id, category_id) VALUES ${placeholders}`,
        values.flat()
      );
    }

    res.json({
      message: 'Preferences updated successfully'
    });
  } catch (error) {
    console.error('Update preferences error:', error);
    res.status(500).json({
      error: 'Failed to update preferences',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/users/bookmarks:
 *   get:
 *     summary: Get user's bookmarked locations
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
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
 *     responses:
 *       200:
 *         description: List of bookmarked locations
 */
router.get('/bookmarks', [
  authenticateToken,
  query('limit').optional().isInt({ min: 1, max: 50 }).toInt(),
  query('offset').optional().isInt({ min: 0 }).toInt()
], async (req, res) => {
  try {
    const { limit = 20, offset = 0 } = req.query;

    const [bookmarks] = await pool.execute(`
      SELECT 
        l.id, l.title, l.description, l.latitude, l.longitude, l.address,
        lc.name as category_name, lc.icon as category_icon,
        dl.name as danger_level, dl.color as danger_color,
        u.username as submitted_by,
        l.submitted_by as submitted_by_id,
        l.created_at,
        b.created_at as bookmarked_at,
        l.likes_count as like_count,
        l.bookmarks_count as bookmark_count,
        l.is_approved,
        EXISTS(SELECT 1 FROM likes lk WHERE lk.location_id = l.id AND lk.user_id = ?) as is_liked,
        TRUE as is_bookmarked
      FROM bookmarks b
      JOIN locations l ON b.location_id = l.id
      LEFT JOIN location_categories lc ON l.category_id = lc.id
      LEFT JOIN danger_levels dl ON l.danger_level_id = dl.id
      LEFT JOIN users u ON l.submitted_by = u.id
      WHERE b.user_id = ? AND l.is_approved = TRUE
      ORDER BY b.created_at DESC
      LIMIT ? OFFSET ?
    `, [req.user.userId, req.user.userId, limit, offset]);

    // Get images for each bookmarked location
    for (let bookmark of bookmarks) {
      const [images] = await pool.execute(`
        SELECT image_url 
        FROM location_images 
        WHERE location_id = ?
        ORDER BY created_at ASC
      `, [bookmark.id]);
      
      bookmark.images = images.map(img => img.image_url);
    }

    res.json({
      bookmarks,
      has_more: bookmarks.length === limit
    });
  } catch (error) {
    console.error('Get bookmarks error:', error);
    res.status(500).json({
      error: 'Failed to get bookmarks',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/users/submissions:
 *   get:
 *     summary: Get user's submitted locations
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *           enum: [pending, approved, all]
 *           default: all
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
 *         description: List of submitted locations
 */
router.get('/submissions', [
  authenticateToken,
  query('status').optional().isIn(['pending', 'approved', 'all']),
  query('limit').optional().isInt({ min: 1, max: 50 }).toInt(),
  query('offset').optional().isInt({ min: 0 }).toInt()
], async (req, res) => {
  try {
    const { status = 'all', limit = 20, offset = 0 } = req.query;

    let whereClause = 'WHERE l.submitted_by = ?';
    const params = [req.user.userId];

    if (status === 'pending') {
      whereClause += ' AND l.is_approved = FALSE';
    } else if (status === 'approved') {
      whereClause += ' AND l.is_approved = TRUE';
    }

    const [submissions] = await pool.execute(`
      SELECT 
        l.id, l.title, l.description, l.latitude, l.longitude, l.address,
        lc.name as category_name, lc.icon as category_icon,
        dl.name as danger_level, dl.color as danger_color,
        l.is_approved, l.created_at,
        l.likes_count as like_count,
        l.bookmarks_count as bookmark_count,
        l.comments_count as comment_count
      FROM locations l
      LEFT JOIN location_categories lc ON l.category_id = lc.id
      LEFT JOIN danger_levels dl ON l.danger_level_id = dl.id
      ${whereClause}
      ORDER BY l.created_at DESC
      LIMIT ? OFFSET ?
    `, [...params, limit, offset]);

    res.json({
      submissions,
      has_more: submissions.length === limit
    });
  } catch (error) {
    console.error('Get submissions error:', error);
    res.status(500).json({
      error: 'Failed to get submissions',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/users/admin-status:
 *   get:
 *     summary: Check if current user has admin privileges
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Admin status returned
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 is_admin:
 *                   type: boolean
 *       401:
 *         description: Unauthorized
 */
router.get('/admin-status', authenticateToken, async (req, res) => {
  try {
    const [adminUsers] = await pool.execute(
      'SELECT id FROM admin_users WHERE user_id = ?',
      [req.user.userId]
    );

    res.json({
      is_admin: adminUsers.length > 0
    });
  } catch (error) {
    console.error('Check admin status error:', error);
    res.status(500).json({
      error: 'Failed to check admin status',
      message: error.message
    });
  }
});

module.exports = router;
