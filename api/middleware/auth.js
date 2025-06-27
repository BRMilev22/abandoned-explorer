const jwt = require('jsonwebtoken');
const { pool } = require('../config/database');

const authenticateToken = async (req, res, next) => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

    if (!token) {
      return res.status(401).json({
        error: 'Access denied',
        message: 'No token provided'
      });
    }

    // Verify token
    const decoded = jwt.verify(token, 'your-super-secret-jwt-key-change-in-production');
    
    // Check if user still exists and is active
    const [users] = await pool.execute(
      'SELECT id, username, email, is_premium FROM users WHERE id = ? AND is_active = TRUE',
      [decoded.userId]
    );

    if (users.length === 0) {
      return res.status(401).json({
        error: 'Access denied',
        message: 'User not found or inactive'
      });
    }

    req.user = {
      id: decoded.userId,        // For consistent access via req.user.id
      userId: decoded.userId,    // For backward compatibility
      username: decoded.username,
      isPremium: users[0].is_premium
    };
    
    next();
  } catch (error) {
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({
        error: 'Access denied',
        message: 'Invalid token'
      });
    }
    
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        error: 'Access denied',
        message: 'Token expired'
      });
    }

    console.error('Auth middleware error:', error);
    return res.status(500).json({
      error: 'Authentication failed',
      message: error.message
    });
  }
};

const requirePremium = (req, res, next) => {
  if (!req.user.isPremium) {
    return res.status(403).json({
      error: 'Premium required',
      message: 'This feature requires a premium subscription'
    });
  }
  next();
};

const requireAdmin = async (req, res, next) => {
  try {
    const [admins] = await pool.execute(
      'SELECT role FROM admin_users WHERE user_id = ?',
      [req.user.userId]
    );

    if (admins.length === 0) {
      return res.status(403).json({
        error: 'Access denied',
        message: 'Admin privileges required'
      });
    }

    req.user.adminRole = admins[0].role;
    next();
  } catch (error) {
    console.error('Admin check error:', error);
    return res.status(500).json({
      error: 'Authorization check failed',
      message: error.message
    });
  }
};

module.exports = {
  authenticateToken,
  requirePremium,
  requireAdmin
};
