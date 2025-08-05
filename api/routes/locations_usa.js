const express = require('express');
const { pool } = require('../config/database');
const { body, query, validationResult } = require('express-validator');
const { authenticateToken, optionalAuth } = require('../middleware/auth');

const router = express.Router();

/**
 * @swagger
 * /api/locations-usa/random:
 *   get:
 *     summary: Get random location suggestions near user
 *     tags: [Locations USA]
 *     parameters:
 *       - in: query
 *         name: lat
 *         required: true
 *         schema:
 *           type: number
 *           format: float
 *         description: User's latitude
 *       - in: query
 *         name: lng
 *         required: true
 *         schema:
 *           type: number
 *           format: float
 *         description: User's longitude
 *       - in: query
 *         name: radius
 *         schema:
 *           type: integer
 *           default: 50
 *         description: Search radius in kilometers
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 10
 *         description: Number of random locations to return
 *       - in: query
 *         name: category
 *         schema:
 *           type: string
 *         description: Filter by category
 *     responses:
 *       200:
 *         description: Random location suggestions
 *       400:
 *         description: Invalid coordinates
 */
router.get('/random', [
  query('lat').isFloat({ min: -90, max: 90 }).toFloat(),
  query('lng').isFloat({ min: -180, max: 180 }).toFloat(),
  query('radius').optional().isInt({ min: 1, max: 100 }).toInt(),
  query('limit').optional().isInt({ min: 1, max: 20 }).toInt(),
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

    const { lat, lng, radius = 50, limit = 10, category } = req.query;

    let whereClause = 'WHERE lu.is_visible = TRUE';
    let params = [];
    
    if (category) {
      whereClause += ' AND lc.name = ?';
      params.push(category);
    }

    const query_sql = `
      SELECT 
        lu.id, lu.uuid, lu.title, lu.description, lu.latitude, lu.longitude, lu.address,
        lc.name as category_name, lc.icon as category_icon,
        dl.name as danger_level, dl.color as danger_color,
        lu.building_type, lu.original_tags,
        lu.created_at,
        (6371 * acos(cos(radians(?)) * cos(radians(lu.latitude)) * 
         cos(radians(lu.longitude) - radians(?)) + 
         sin(radians(?)) * sin(radians(lu.latitude)))) AS distance
      FROM locations_usa lu
      LEFT JOIN location_categories lc ON lu.category_id = lc.id
      LEFT JOIN danger_levels dl ON lu.danger_level_id = dl.id
      ${whereClause}
      HAVING distance <= ?
      ORDER BY RAND()
      LIMIT ?
    `;

    const queryParams = [lat, lng, lat, ...params, radius, limit];
    const [results] = await pool.execute(query_sql, queryParams);
    
    let locations = results || [];

    // Add distance in km to each location
    locations = locations.map(location => ({
      ...location,
      distance_km: parseFloat(location.distance).toFixed(1),
      source: 'usa'
    }));

    res.json({
      success: true,
      locations,
      total: locations.length,
      radius_km: radius,
      center: { lat, lng },
      query_type: 'random'
    });
  } catch (error) {
    console.error('Random USA locations error:', error);
    res.status(500).json({
      error: 'Failed to get random USA locations',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/locations-usa/nearby:
 *   get:
 *     summary: Get nearby USA locations
 *     tags: [Locations USA]
 *     parameters:
 *       - in: query
 *         name: lat
 *         required: true
 *         schema:
 *           type: number
 *           format: float
 *       - in: query
 *         name: lng
 *         required: true
 *         schema:
 *           type: number
 *           format: float
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
 *         name: category
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: List of nearby USA locations
 */
router.get('/nearby', [
  query('lat').isFloat({ min: -90, max: 90 }).toFloat(),
  query('lng').isFloat({ min: -180, max: 180 }).toFloat(),
  query('radius').optional().isInt({ min: 1, max: 100 }).toInt(),
  query('limit').optional().isInt({ min: 1, max: 100 }).toInt(),
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

    const { lat, lng, radius = 50, limit = 50, category } = req.query;

    let whereClause = 'WHERE lu.is_visible = TRUE';
    let params = [];
    
    if (category) {
      whereClause += ' AND lc.name = ?';
      params.push(category);
    }

    const query_sql = `
      SELECT 
        lu.id, lu.uuid, lu.title, lu.description, lu.latitude, lu.longitude, lu.address,
        lc.name as category_name, lc.icon as category_icon,
        dl.name as danger_level, dl.color as danger_color,
        lu.building_type, lu.original_tags,
        lu.created_at,
        (6371 * acos(cos(radians(?)) * cos(radians(lu.latitude)) * 
         cos(radians(lu.longitude) - radians(?)) + 
         sin(radians(?)) * sin(radians(lu.latitude)))) AS distance
      FROM locations_usa lu
      LEFT JOIN location_categories lc ON lu.category_id = lc.id
      LEFT JOIN danger_levels dl ON lu.danger_level_id = dl.id
      ${whereClause}
      HAVING distance <= ?
      ORDER BY distance
      LIMIT ?
    `;

    const queryParams = [lat, lng, lat, ...params, radius, limit];
    const [results] = await pool.execute(query_sql, queryParams);
    
    let locations = results || [];

    // Add distance in km to each location
    locations = locations.map(location => ({
      ...location,
      distance_km: parseFloat(location.distance).toFixed(1),
      source: 'usa'
    }));

    res.json({
      success: true,
      locations,
      total: locations.length,
      radius_km: radius,
      center: { lat, lng }
    });
  } catch (error) {
    console.error('Nearby USA locations error:', error);
    res.status(500).json({
      error: 'Failed to get nearby USA locations',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /api/locations-usa/stats:
 *   get:
 *     summary: Get USA locations statistics
 *     tags: [Locations USA]
 *     responses:
 *       200:
 *         description: Statistics about USA locations
 */
router.get('/stats', async (req, res) => {
  try {
    // Get total counts
    const [totalStats] = await pool.execute(`
      SELECT 
        COUNT(*) as total_locations,
        SUM(CASE WHEN is_visible = TRUE THEN 1 ELSE 0 END) as visible_locations,
        SUM(CASE WHEN is_visible = FALSE THEN 1 ELSE 0 END) as hidden_locations
      FROM locations_usa
    `);

    // Get category breakdown
    const [categoryStats] = await pool.execute(`
      SELECT 
        lc.name as category_name,
        lc.icon as category_icon,
        COUNT(lu.id) as location_count
      FROM location_categories lc
      LEFT JOIN locations_usa lu ON lc.id = lu.category_id AND lu.is_visible = TRUE
      WHERE lc.is_active = TRUE
      GROUP BY lc.id, lc.name, lc.icon
      ORDER BY location_count DESC
    `);

    // Get danger level breakdown
    const [dangerStats] = await pool.execute(`
      SELECT 
        dl.name as danger_level,
        dl.color as danger_color,
        COUNT(lu.id) as location_count
      FROM danger_levels dl
      LEFT JOIN locations_usa lu ON dl.id = lu.danger_level_id AND lu.is_visible = TRUE
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
    console.error('Get USA stats error:', error);
    res.status(500).json({
      error: 'Failed to fetch USA statistics',
      message: error.message
    });
  }
});

module.exports = router; 