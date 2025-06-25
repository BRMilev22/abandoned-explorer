const mysql = require('mysql2/promise');

// Database connection pool for better performance
// Hardcoded credentials for local development
const pool = mysql.createPool({
  host: 'localhost',
  user: 'root',
  password: '',
  database: 'abandoned_explorer',
  port: 3306,
  waitForConnections: true,
  connectionLimit: 50, // Increased for high traffic
  queueLimit: 0,
  // acquireTimeout: 60000 is the default, no need to specify
  enableKeepAlive: true,
  keepAliveInitialDelay: 0,
  // Enable multiple statements for stored procedures
  multipleStatements: true,
  // Optimize for performance
  supportBigNumbers: true,
  bigNumberStrings: true,
  dateStrings: false,
  debug: false,
  trace: process.env.NODE_ENV === 'development'
});

// Test database connection
const testConnection = async () => {
  try {
    const connection = await pool.getConnection();
    console.log('✅ Database connected successfully');
    connection.release();
  } catch (error) {
    console.error('❌ Database connection failed:', error.message);
    process.exit(1);
  }
};

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('🔄 Closing database connections...');
  await pool.end();
  console.log('✅ Database connections closed');
  process.exit(0);
});

module.exports = {
  pool,
  testConnection
};
