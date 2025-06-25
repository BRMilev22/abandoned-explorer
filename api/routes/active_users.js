const express = require('express');
const router = express.Router();
const { pool } = require('../config/database');
const { authenticateToken } = require('../middleware/auth');

// Calculate distance between two coordinates using Haversine formula
function calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371; // Earth's radius in kilometers
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a = 
        Math.sin(dLat/2) * Math.sin(dLat/2) +
        Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * 
        Math.sin(dLon/2) * Math.sin(dLon/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    const distance = R * c;
    return distance;
}

// Get active users within range
router.get('/active-nearby', authenticateToken, async (req, res) => {
    try {
        const { latitude, longitude, radius = 50, activity_threshold = 2 } = req.query;
        
        if (!latitude || !longitude) {
            return res.status(400).json({ 
                error: 'Latitude and longitude are required' 
            });
        }

        const lat = parseFloat(latitude);
        const lng = parseFloat(longitude);
        const radiusKm = parseFloat(radius);
        const activityHours = parseInt(activity_threshold);

        console.log(`🔍 Searching for active users near: ${lat}, ${lng} within ${radiusKm}km, active within ${activityHours}h`);

        // Query to get active users with their locations
        const query = `
            SELECT 
                u.id,
                u.username,
                u.is_premium,
                u.last_login,
                u.profile_image_url as profile_picture_url,
                ul.latitude,
                ul.longitude,
                ul.location_name,
                ul.accuracy_meters,
                TIMESTAMPDIFF(MINUTE, u.last_login, NOW()) as minutes_since_login,
                (
                    6371 * acos(
                        cos(radians(?)) * 
                        cos(radians(ul.latitude)) * 
                        cos(radians(ul.longitude) - radians(?)) + 
                        sin(radians(?)) * 
                        sin(radians(ul.latitude))
                    )
                ) AS distance_km
            FROM users u
            JOIN user_locations ul ON u.id = ul.user_id
            WHERE 
                u.is_active = TRUE 
                AND u.last_login > NOW() - INTERVAL ? HOUR
                AND (
                    6371 * acos(
                        cos(radians(?)) * 
                        cos(radians(ul.latitude)) * 
                        cos(radians(ul.longitude) - radians(?)) + 
                        sin(radians(?)) * 
                        sin(radians(ul.latitude))
                    )
                ) <= ?
            ORDER BY distance_km ASC, u.last_login DESC
            LIMIT 100
        `;

        const [users] = await pool.execute(query, [
            lat, lng, lat, activityHours, lat, lng, lat, radiusKm
        ]);

        // Format the response
        const activeUsers = users.map(user => ({
            id: user.id,
            username: user.username,
            is_premium: user.is_premium,
            last_login: user.last_login,
            profile_picture_url: user.profile_picture_url,
            location: {
                latitude: parseFloat(user.latitude),
                longitude: parseFloat(user.longitude),
                name: user.location_name,
                accuracy_meters: user.accuracy_meters
            },
            activity: {
                minutes_since_login: user.minutes_since_login,
                status: user.minutes_since_login <= 30 ? 'very_active' : 
                       user.minutes_since_login <= 120 ? 'active' : 'recent'
            },
            distance_km: parseFloat(user.distance_km)
        }));

        console.log(`📊 Found ${activeUsers.length} active users within ${radiusKm}km`);

        res.json({
            success: true,
            query: {
                center: { latitude: lat, longitude: lng },
                radius_km: radiusKm,
                activity_threshold_hours: activityHours
            },
            total_count: activeUsers.length,
            users: activeUsers
        });

    } catch (error) {
        console.error('Error fetching active users:', error);
        res.status(500).json({ 
            error: 'Failed to fetch active users',
            details: error.message 
        });
    }
});

// Get active users statistics
router.get('/active-stats', authenticateToken, async (req, res) => {
    try {
        const { latitude, longitude, radius = 50 } = req.query;
        
        if (!latitude || !longitude) {
            return res.status(400).json({ 
                error: 'Latitude and longitude are required' 
            });
        }

        const lat = parseFloat(latitude);
        const lng = parseFloat(longitude);
        const radiusKm = parseFloat(radius);

        // Query for activity statistics
        const statsQuery = `
            SELECT 
                COUNT(*) as total_users,
                SUM(CASE WHEN u.last_login > NOW() - INTERVAL 30 MINUTE THEN 1 ELSE 0 END) as very_active,
                SUM(CASE WHEN u.last_login > NOW() - INTERVAL 2 HOUR THEN 1 ELSE 0 END) as active,
                SUM(CASE WHEN u.last_login > NOW() - INTERVAL 24 HOUR THEN 1 ELSE 0 END) as recent,
                SUM(CASE WHEN u.is_premium = TRUE THEN 1 ELSE 0 END) as premium_users
            FROM users u
            JOIN user_locations ul ON u.id = ul.user_id
            WHERE 
                u.is_active = TRUE 
                AND (
                    6371 * acos(
                        cos(radians(?)) * 
                        cos(radians(ul.latitude)) * 
                        cos(radians(ul.longitude) - radians(?)) + 
                        sin(radians(?)) * 
                        sin(radians(ul.latitude))
                    )
                ) <= ?
        `;

        const [stats] = await pool.execute(statsQuery, [lat, lng, lat, radiusKm]);
        const statistics = stats[0];

        res.json({
            success: true,
            query: {
                center: { latitude: lat, longitude: lng },
                radius_km: radiusKm
            },
            statistics: {
                total_users: parseInt(statistics.total_users) || 0,
                very_active: parseInt(statistics.very_active) || 0,
                active: parseInt(statistics.active) || 0,
                recent: parseInt(statistics.recent) || 0,
                premium_users: parseInt(statistics.premium_users) || 0
            }
        });

    } catch (error) {
        console.error('Error fetching active user stats:', error);
        res.status(500).json({ 
            error: 'Failed to fetch active user statistics',
            details: error.message 
        });
    }
});

// Update user location (when user moves or logs in)
router.post('/update-location', authenticateToken, async (req, res) => {
    try {
        const { latitude, longitude, location_name, accuracy_meters = 1000 } = req.body;
        const userId = req.user.userId;

        if (!latitude || !longitude) {
            return res.status(400).json({ 
                error: 'Latitude and longitude are required' 
            });
        }

        const lat = parseFloat(latitude);
        const lng = parseFloat(longitude);

        // Update or insert user location
        const upsertQuery = `
            INSERT INTO user_locations (user_id, latitude, longitude, location_name, accuracy_meters)
            VALUES (?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE 
                latitude = VALUES(latitude),
                longitude = VALUES(longitude),
                location_name = VALUES(location_name),
                accuracy_meters = VALUES(accuracy_meters),
                updated_at = NOW()
        `;

        await pool.execute(upsertQuery, [
            userId, lat, lng, location_name || null, accuracy_meters
        ]);

        // Also update last login time
        await pool.execute(
            'UPDATE users SET last_login = NOW() WHERE id = ?',
            [userId]
        );

        console.log(`📍 Updated location for user ${userId}: ${lat}, ${lng}`);

        res.json({
            success: true,
            message: 'Location updated successfully',
            location: {
                latitude: lat,
                longitude: lng,
                location_name,
                accuracy_meters
            }
        });

    } catch (error) {
        console.error('Error updating user location:', error);
        res.status(500).json({ 
            error: 'Failed to update location',
            details: error.message 
        });
    }
});

module.exports = router;
