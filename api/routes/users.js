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
 * /api/users/notifications:
 *   get:
 *     summary: Get user notifications
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: unread_only
 *         schema:
 *           type: boolean
 *           default: false
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
 *         description: List of user notifications
 */
router.get('/notifications', authenticateToken, [
  query('unread_only').optional().isBoolean().toBoolean(),
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

    const { unread_only = false, limit = 20, offset = 0 } = req.query;

    let whereClause = 'WHERE user_id = ?';
    const params = [req.user.userId];

    if (unread_only) {
      whereClause += ' AND is_read = FALSE';
    }

    const [notifications] = await pool.execute(`
      SELECT 
        id, title, message, type, related_type, related_id, 
        is_read, created_at
      FROM notifications 
      ${whereClause}
      ORDER BY created_at DESC 
      LIMIT ? OFFSET ?
    `, [...params, limit, offset]);

    // Convert MySQL TINYINT to proper boolean values
    const formattedNotifications = notifications.map(notification => ({
      ...notification,
      is_read: Boolean(notification.is_read)
    }));

    // Get unread count
    const [unreadCount] = await pool.execute(
      'SELECT COUNT(*) as count FROM notifications WHERE user_id = ? AND is_read = FALSE',
      [req.user.userId]
    );

    res.json({
      success: true,
      notifications: formattedNotifications,
      unreadCount: parseInt(unreadCount[0].count, 10),
      hasMore: notifications.length === limit
    });
  } catch (error) {
    console.error('Get notifications error:', error);
    res.status(500).json({
      error: 'Failed to fetch notifications',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/users/notifications/{id}/read:
 *   post:
 *     summary: Mark notification as read
 *     tags: [Users]
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
 *         description: Notification marked as read
 */
router.post('/notifications/:id/read', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;

    // Verify notification belongs to user
    const [notification] = await pool.execute(
      'SELECT id FROM notifications WHERE id = ? AND user_id = ?',
      [id, req.user.userId]
    );

    if (notification.length === 0) {
      return res.status(404).json({
        error: 'Notification not found'
      });
    }

    // Mark as read
    await pool.execute(
      'UPDATE notifications SET is_read = TRUE WHERE id = ?',
      [id]
    );

    res.json({
      success: true,
      message: 'Notification marked as read'
    });
  } catch (error) {
    console.error('Mark notification read error:', error);
    res.status(500).json({
      error: 'Failed to mark notification as read',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/users/notifications/read-all:
 *   post:
 *     summary: Mark all notifications as read
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: All notifications marked as read
 */
router.post('/notifications/read-all', authenticateToken, async (req, res) => {
  try {
    await pool.execute(
      'UPDATE notifications SET is_read = TRUE WHERE user_id = ? AND is_read = FALSE',
      [req.user.userId]
    );

    res.json({
      success: true,
      message: 'All notifications marked as read'
    });
  } catch (error) {
    console.error('Mark all notifications read error:', error);
    res.status(500).json({
      error: 'Failed to mark all notifications as read',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/users/preferences:
 *   get:
 *     summary: Get user preferences
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: User preferences
 */
router.get('/preferences', authenticateToken, async (req, res) => {
  try {
    const [preferences] = await pool.execute(
      'SELECT preference_key, preference_value FROM user_preferences WHERE user_id = ?',
      [req.user.userId]
    );

    // Convert to object format
    const preferencesObject = {};
    preferences.forEach(pref => {
      try {
        preferencesObject[pref.preference_key] = JSON.parse(pref.preference_value);
      } catch {
        preferencesObject[pref.preference_key] = pref.preference_value;
      }
    });

    res.json({
      success: true,
      preferences: preferencesObject
    });
  } catch (error) {
    console.error('Get preferences error:', error);
    res.status(500).json({
      error: 'Failed to fetch preferences',
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
 *               preferences:
 *                 type: object
 *     responses:
 *       200:
 *         description: Preferences updated
 */
router.post('/preferences', authenticateToken, async (req, res) => {
  try {
    const { preferences } = req.body;

    if (!preferences || typeof preferences !== 'object') {
      return res.status(400).json({
        error: 'Invalid preferences data'
      });
    }

    // Update or insert preferences
    for (const [key, value] of Object.entries(preferences)) {
      const jsonValue = JSON.stringify(value);
      
      await pool.execute(`
        INSERT INTO user_preferences (user_id, preference_key, preference_value)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE preference_value = VALUES(preference_value)
      `, [req.user.userId, key, jsonValue]);
    }

    res.json({
      success: true,
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
 * /api/users/visited-locations:
 *   get:
 *     summary: Get user's visited locations
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
 *         description: List of visited locations
 */
router.get('/visited-locations', authenticateToken, [
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

    const { limit = 20, offset = 0 } = req.query;

    const [visits] = await pool.execute(`
      SELECT 
        l.id, l.title, l.description, l.latitude, l.longitude, l.address,
        lc.name as category_name, lc.icon as category_icon,
        dl.name as danger_level, dl.color as danger_color,
        lv.visited_at,
        l.likes_count as like_count,
        l.bookmarks_count as bookmark_count,
        l.comments_count as comment_count,
        l.views_count as view_count
      FROM location_visits lv
      JOIN locations l ON lv.location_id = l.id
      LEFT JOIN location_categories lc ON l.category_id = lc.id
      LEFT JOIN danger_levels dl ON l.danger_level_id = dl.id
      WHERE lv.user_id = ? AND l.is_approved = TRUE
      ORDER BY lv.visited_at DESC
      LIMIT ? OFFSET ?
    `, [req.user.userId, limit, offset]);

    res.json({
      success: true,
      visitedLocations: visits,
      hasMore: visits.length === limit
    });
  } catch (error) {
    console.error('Get visited locations error:', error);
    res.status(500).json({
      error: 'Failed to fetch visited locations',
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
