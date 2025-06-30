const express = require('express');
const { body, query, validationResult } = require('express-validator');
const { pool } = require('../config/database');
const { authenticateToken, requireAdmin } = require('../middleware/auth');

const router = express.Router();

// Helper function to create notifications
async function createNotification(userId, title, message, type, relatedType = null, relatedId = null, triggeredBy = null, data = null) {
  try {
    const dataJson = data ? JSON.stringify(data) : null;
    await pool.execute(
      'INSERT INTO notifications (user_id, title, message, type, related_type, related_id, triggered_by, data) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [userId, title, message, type, relatedType, relatedId, triggeredBy, dataJson]
    );
    console.log(`📩 Created ${type} notification for user ${userId}`);
  } catch (error) {
    console.error('Failed to create notification:', error);
    // Don't throw error - notifications are not critical
  }
}

// All admin routes require authentication and admin privileges
router.use(authenticateToken);
router.use(requireAdmin);

/**
 * @swagger
 * /api/admin/locations/pending:
 *   get:
 *     summary: Get pending location submissions
 *     tags: [Admin]
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
 *         description: List of pending locations
 *       403:
 *         description: Admin access required
 */
router.get('/locations/pending', [
  query('limit').optional().isInt({ min: 1, max: 100 }).toInt(),
  query('offset').optional().isInt({ min: 0 }).toInt()
], async (req, res) => {
  try {
    const { limit = 20, offset = 0 } = req.query;

    const [pendingLocations] = await pool.execute(`
      SELECT 
        l.id, l.title, l.description, l.latitude, l.longitude, l.address,
        lc.name as category_name,
        dl.name as danger_level,
        l.submitted_by,
        u.username as submitted_by_username,
        l.created_at,
        l.likes_count as like_count,
        l.bookmarks_count as bookmark_count,
        FALSE as is_bookmarked,
        FALSE as is_liked,
        l.is_approved
      FROM locations l
      LEFT JOIN location_categories lc ON l.category_id = lc.id
      LEFT JOIN danger_levels dl ON l.danger_level_id = dl.id
      LEFT JOIN users u ON l.submitted_by = u.id
      WHERE l.is_approved = FALSE
      ORDER BY l.created_at ASC
      LIMIT ? OFFSET ?
    `, [limit, offset]);

    // Get images and videos for each location
    for (let location of pendingLocations) {
      const [images] = await pool.execute(
        'SELECT image_url, thumbnail_url FROM location_images WHERE location_id = ? ORDER BY image_order',
        [location.id]
      );
      // Convert images to array of URLs (just the main image URLs)
      location.images = images.map(img => img.image_url);

      // Get videos for each location
      const [videos] = await pool.execute(
        'SELECT video_url, thumbnail_url FROM location_videos WHERE location_id = ? ORDER BY video_order',
        [location.id]
      );
      // Convert videos to array of URLs (just the main video URLs)
      location.videos = videos.map(video => video.video_url);

      // Get tags
      const [tags] = await pool.execute(`
        SELECT t.name 
        FROM tags t
        JOIN location_tags lt ON t.id = lt.tag_id
        WHERE lt.location_id = ?
      `, [location.id]);
      location.tags = tags.map(tag => tag.name);
    }

    res.json({
      pending_locations: pendingLocations,
      total: pendingLocations.length,
      has_more: pendingLocations.length === limit
    });
  } catch (error) {
    console.error('Get pending locations error:', error);
    res.status(500).json({
      error: 'Failed to get pending locations',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/admin/locations/{id}/approve:
 *   post:
 *     summary: Approve a location submission
 *     tags: [Admin]
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
 *         description: Location approved successfully
 *       404:
 *         description: Location not found
 */
router.post('/locations/:id/approve', async (req, res) => {
  try {
    const { id } = req.params;

    // Check if location exists and is pending
    const [locations] = await pool.execute(
      'SELECT id, title, submitted_by FROM locations WHERE id = ? AND is_approved = FALSE',
      [id]
    );

    if (locations.length === 0) {
      return res.status(404).json({
        error: 'Location not found or already approved'
      });
    }

    const location = locations[0];

    // Approve the location
    await pool.execute(
      'UPDATE locations SET is_approved = TRUE, approved_by = ?, approval_date = CURRENT_TIMESTAMP WHERE id = ?',
      [req.user.userId, id]
    );

    // Send approval notification to the submitter
    if (location.submitted_by) {
      await createNotification(
        location.submitted_by,
        'Location Approved! 🎉',
        `Your location "${location.title}" has been approved and is now live!`,
        'approval',
        'location',
        id,
        req.user.userId,
        { 
          locationTitle: location.title, 
          adminUsername: req.user.username,
          status: 'approved'
        }
      );
    }

    res.json({
      success: true,
      message: 'Location approved successfully'
    });
  } catch (error) {
    console.error('Approve location error:', error);
    res.status(500).json({
      error: 'Failed to approve location',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/admin/locations/{id}/reject:
 *   delete:
 *     summary: Reject and delete a location submission
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: false
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               reason:
 *                 type: string
 *     responses:
 *       200:
 *         description: Location rejected successfully
 *       404:
 *         description: Location not found
 */
router.delete('/locations/:id/reject', [
  body('reason').optional().isLength({ max: 500 }).trim()
], async (req, res) => {
  try {
    const { id } = req.params;
    const { reason } = req.body;

    // Check if location exists and get submitter info
    const [locations] = await pool.execute(
      'SELECT id, title, submitted_by FROM locations WHERE id = ? AND is_approved = FALSE',
      [id]
    );

    if (locations.length === 0) {
      return res.status(404).json({
        error: 'Location not found'
      });
    }

    const location = locations[0];

    // Send rejection notification before deleting
    if (location.submitted_by) {
      await createNotification(
        location.submitted_by,
        'Location Rejected',
        `Your location "${location.title}" was not approved${reason ? ': ' + reason : '.'}`,
        'rejection',
        'location',
        id,
        req.user.userId,
        { 
          locationTitle: location.title, 
          adminUsername: req.user.username,
          reason: reason || 'No reason provided',
          status: 'rejected'
        }
      );
    }

    // Delete the location (cascade will handle related records)
    await pool.execute('DELETE FROM locations WHERE id = ?', [id]);

    res.json({
      success: true,
      message: 'Location rejected and deleted successfully'
    });
  } catch (error) {
    console.error('Reject location error:', error);
    res.status(500).json({
      error: 'Failed to reject location',
      message: error.message
    });
  }
});

// POST version of reject endpoint for mobile app compatibility
router.post('/locations/:id/reject', [
  body('reason').optional().isLength({ max: 500 }).trim()
], async (req, res) => {
  try {
    const { id } = req.params;
    const { reason } = req.body;

    // Check if location exists and get submitter info
    const [locations] = await pool.execute(
      'SELECT id, title, submitted_by FROM locations WHERE id = ? AND is_approved = FALSE',
      [id]
    );

    if (locations.length === 0) {
      return res.status(404).json({
        error: 'Location not found'
      });
    }

    const location = locations[0];

    // Send rejection notification before deleting
    if (location.submitted_by) {
      await createNotification(
        location.submitted_by,
        'Location Rejected',
        `Your location "${location.title}" was not approved${reason ? ': ' + reason : '.'}`,
        'rejection',
        'location',
        id,
        req.user.userId,
        { 
          locationTitle: location.title, 
          adminUsername: req.user.username,
          reason: reason || 'No reason provided',
          status: 'rejected'
        }
      );
    }

    // Delete the location (cascade will handle related records)
    await pool.execute('DELETE FROM locations WHERE id = ?', [id]);

    res.json({
      success: true,
      message: 'Location rejected and deleted successfully'
    });
  } catch (error) {
    console.error('Reject location error:', error);
    res.status(500).json({
      error: 'Failed to reject location',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/admin/users:
 *   get:
 *     summary: Get users list with pagination
 *     tags: [Admin]
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
 *       - in: query
 *         name: search
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: List of users
 */
router.get('/users', [
  query('limit').optional().isInt({ min: 1, max: 100 }).toInt(),
  query('offset').optional().isInt({ min: 0 }).toInt(),
  query('search').optional().isLength({ min: 1, max: 100 }).trim()
], async (req, res) => {
  try {
    const { limit = 20, offset = 0, search } = req.query;

    let whereClause = 'WHERE 1=1';
    let params = [];

    if (search) {
      whereClause += ' AND (u.username LIKE ? OR u.email LIKE ?)';
      params.push(`%${search}%`, `%${search}%`);
    }

    const [users] = await pool.execute(`
      SELECT 
        u.id, u.username, u.email, u.age, u.is_premium, u.created_at, u.last_login, u.is_active,
        COUNT(DISTINCT l.id) as submitted_locations,
        COUNT(DISTINCT CASE WHEN l.is_approved = TRUE THEN l.id END) as approved_locations,
        COUNT(DISTINCT r.id) as reports_made
      FROM users u
      LEFT JOIN locations l ON u.id = l.submitted_by
      LEFT JOIN reports r ON u.id = r.reporter_id
      ${whereClause}
      GROUP BY u.id
      ORDER BY u.created_at DESC
      LIMIT ? OFFSET ?
    `, [...params, limit, offset]);

    res.json({
      users,
      has_more: users.length === limit
    });
  } catch (error) {
    console.error('Get users error:', error);
    res.status(500).json({
      error: 'Failed to get users',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/admin/users/{id}/ban:
 *   post:
 *     summary: Ban a user
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: false
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               reason:
 *                 type: string
 *     responses:
 *       200:
 *         description: User banned successfully
 */
router.post('/users/:id/ban', [
  body('reason').optional().isLength({ max: 500 }).trim()
], async (req, res) => {
  try {
    const { id } = req.params;
    const { reason } = req.body;

    // Check if user exists
    const [users] = await pool.execute(
      'SELECT id, username FROM users WHERE id = ?',
      [id]
    );

    if (users.length === 0) {
      return res.status(404).json({
        error: 'User not found'
      });
    }

    // Deactivate user
    await pool.execute(
      'UPDATE users SET is_active = FALSE, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      [id]
    );

    res.json({
      message: 'User banned successfully',
      username: users[0].username,
      reason: reason || 'No reason provided'
    });
  } catch (error) {
    console.error('Ban user error:', error);
    res.status(500).json({
      error: 'Failed to ban user',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/admin/stats:
 *   get:
 *     summary: Get application statistics
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Application statistics
 */
router.get('/stats', async (req, res) => {
  try {
    // Get various statistics
    const [totalUsers] = await pool.execute('SELECT COUNT(*) as count FROM users WHERE is_active = TRUE');
    const [totalLocations] = await pool.execute('SELECT COUNT(*) as count FROM locations WHERE is_approved = TRUE');
    const [pendingLocations] = await pool.execute('SELECT COUNT(*) as count FROM locations WHERE is_approved = FALSE');
    const [premiumUsers] = await pool.execute('SELECT COUNT(*) as count FROM users WHERE is_premium = TRUE AND is_active = TRUE');
    const [totalImages] = await pool.execute('SELECT COUNT(*) as count FROM location_images');
    const [totalLikes] = await pool.execute('SELECT COUNT(*) as count FROM likes');
    const [totalBookmarks] = await pool.execute('SELECT COUNT(*) as count FROM bookmarks');

    // Get recent activity
    const [recentSubmissions] = await pool.execute(`
      SELECT l.title, u.username, l.created_at
      FROM locations l
      JOIN users u ON l.submitted_by = u.id
      WHERE l.is_approved = FALSE
      ORDER BY l.created_at DESC
      LIMIT 5
    `);

    // Get popular categories
    const [popularCategories] = await pool.execute(`
      SELECT lc.name, COUNT(l.id) as count
      FROM location_categories lc
      LEFT JOIN locations l ON lc.id = l.category_id AND l.is_approved = TRUE
      GROUP BY lc.id, lc.name
      ORDER BY count DESC
    `);

    res.json({
      stats: {
        total_users: totalUsers[0].count,
        total_locations: totalLocations[0].count,
        pending_locations: pendingLocations[0].count,
        premium_users: premiumUsers[0].count,
        total_images: totalImages[0].count,
        total_likes: totalLikes[0].count,
        total_bookmarks: totalBookmarks[0].count
      },
      recent_submissions: recentSubmissions,
      popular_categories: popularCategories
    });
  } catch (error) {
    console.error('Get stats error:', error);
    res.status(500).json({
      error: 'Failed to get statistics',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/admin/status:
 *   get:
 *     summary: Check if current user is admin
 *     tags: [Admin]
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
router.get('/status', async (req, res) => {
  try {
    // If we reached here, the user passed both authenticateToken and requireAdmin middleware
    res.json({
      is_admin: true
    });
  } catch (error) {
    console.error('Get admin status error:', error);
    res.status(500).json({
      error: 'Failed to check admin status',
      message: error.message
    });
  }
});

module.exports = router;
