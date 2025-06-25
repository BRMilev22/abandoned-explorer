const mysql = require('mysql2/promise');

async function testActiveUsersEndpoints() {
  const connection = await mysql.createConnection({
    host: 'localhost',
    user: 'root',
    password: '',
    database: 'abandoned_explorer'
  });
  
  console.log('=== Testing Active Users Database Query ===');
  
  // First, check if our test data exists
  const [totalUsers] = await connection.execute('SELECT COUNT(*) as total FROM users');
  console.log('Total users in database:', totalUsers[0].total);
  
  const [usersWithLocations] = await connection.execute('SELECT COUNT(*) as total FROM users u JOIN user_locations ul ON u.id = ul.user_id');
  console.log('Users with locations:', usersWithLocations[0].total);
  
  // Check active users with different time intervals
  const [activeStats2h] = await connection.execute('SELECT COUNT(*) as active_count, COUNT(CASE WHEN u.is_premium = 1 THEN 1 END) as premium_count FROM users u JOIN user_locations ul ON u.id = ul.user_id WHERE u.last_login > NOW() - INTERVAL 2 HOUR');
  console.log('Active users (2h):', activeStats2h[0]);
  
  const [activeStats24h] = await connection.execute('SELECT COUNT(*) as active_count FROM users u JOIN user_locations ul ON u.id = ul.user_id WHERE u.last_login > NOW() - INTERVAL 24 HOUR');
  console.log('Active users (24h):', activeStats24h[0].active_count);
  
  // Test specific regions
  console.log('\n=== Testing Regional Queries ===');
  
  // Bulgaria (Sredets, Burgas, Varna area)
  const [bulgariaCounts] = await connection.execute(`
    SELECT COUNT(*) as count FROM users u 
    JOIN user_locations ul ON u.id = ul.user_id 
    WHERE u.last_login > NOW() - INTERVAL 24 HOUR
    AND ul.latitude BETWEEN 41.0 AND 44.5 
    AND ul.longitude BETWEEN 22.0 AND 29.0
  `);
  console.log('Bulgaria region (24h active):', bulgariaCounts[0].count);
  
  // Europe (rough bounds)
  const [europeCounts] = await connection.execute(`
    SELECT COUNT(*) as count FROM users u 
    JOIN user_locations ul ON u.id = ul.user_id 
    WHERE u.last_login > NOW() - INTERVAL 24 HOUR
    AND ul.latitude BETWEEN 35.0 AND 71.0 
    AND ul.longitude BETWEEN -10.0 AND 40.0
  `);
  console.log('Europe region (24h active):', europeCounts[0].count);
  
  // North America
  const [americaCounts] = await connection.execute(`
    SELECT COUNT(*) as count FROM users u 
    JOIN user_locations ul ON u.id = ul.user_id 
    WHERE u.last_login > NOW() - INTERVAL 24 HOUR
    AND ul.latitude BETWEEN 25.0 AND 50.0 
    AND ul.longitude BETWEEN -130.0 AND -65.0
  `);
  console.log('North America region (24h active):', americaCounts[0].count);
  
  // New York area
  const [nyCounts] = await connection.execute(`
    SELECT COUNT(*) as count FROM users u 
    JOIN user_locations ul ON u.id = ul.user_id 
    WHERE u.last_login > NOW() - INTERVAL 24 HOUR
    AND ul.latitude BETWEEN 40.0 AND 41.0 
    AND ul.longitude BETWEEN -75.0 AND -73.0
  `);
  console.log('New York area (24h active):', nyCounts[0].count);
  
  // Show sample users from different regions
  console.log('\n=== Sample Users by Region ===');
  
  const [sampleUsers] = await connection.execute(`
    SELECT u.username, ul.location_name, ul.latitude, ul.longitude, u.last_login
    FROM users u 
    JOIN user_locations ul ON u.id = ul.user_id 
    WHERE u.last_login > NOW() - INTERVAL 24 HOUR
    ORDER BY u.last_login DESC
    LIMIT 15
  `);
  
  sampleUsers.forEach(user => {
    console.log(`${user.username} (${user.location_name}): lat=${user.latitude}, lng=${user.longitude}, login=${user.last_login}`);
  });
  
  await connection.end();
}

testActiveUsersEndpoints().catch(console.error);