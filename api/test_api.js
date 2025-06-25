const axios = require('axios');

const API_BASE = 'http://localhost:3000/api';

async function testActiveUsersAPI() {
  try {
    console.log('=== Testing Active Users API Endpoints ===\n');
    
    // First, authenticate to get a token
    console.log('0. Authenticating with test user...');
    const loginResponse = await axios.post(`${API_BASE}/auth/login`, {
      email: 'test@test.com',
      password: 'test'
    });
    
    const token = loginResponse.data.token;
    console.log('✅ Authentication successful!\n');
    
    // Set up authenticated headers
    const authHeaders = { Authorization: `Bearer ${token}` };
    
    // Test 1: Active users stats
    console.log('1. Testing /active-users/active-stats...');
    const statsResponse = await axios.get(`${API_BASE}/active-users/active-stats`, { 
      headers: authHeaders,
      params: {
        latitude: 40.7128,
        longitude: -74.0060,
        radius: 20000000 // 20,000 km - worldwide
      }
    });
    console.log('Stats Response:', statsResponse.data);
    console.log('✅ Active stats endpoint working!\n');
    
    // Test 2: Active users nearby (worldwide)
    console.log('2. Testing /active-users/active-nearby (worldwide)...');
    const worldwideResponse = await axios.get(`${API_BASE}/active-users/active-nearby`, {
      headers: authHeaders,
      params: {
        latitude: 40.7128,
        longitude: -74.0060,
        radius: 20000000 // 20,000 km - worldwide
      }
    });
    console.log(`Found ${worldwideResponse.data.users.length} active users worldwide`);
    console.log('Sample users with profile images:');
    worldwideResponse.data.users.slice(0, 5).forEach(user => {
      console.log(`  - ${user.username} (${user.location?.name || 'Unknown location'}): ${user.profile_picture_url ? '✅ Has profile pic' : '❌ No profile pic'}`);
    });
    console.log('✅ Worldwide active users endpoint working!\n');
    
    // Test 3: Active users in Europe
    console.log('3. Testing /active-users/active-nearby (Europe)...');
    const europeResponse = await axios.get(`${API_BASE}/active-users/active-nearby`, {
      headers: authHeaders,
      params: {
        latitude: 50.1109,
        longitude: 8.6821,
        radius: 3000000 // 3,000 km - covers most of Europe
      }
    });
    console.log(`Found ${europeResponse.data.users.length} active users in Europe`);
    console.log('European users:');
    europeResponse.data.users.slice(0, 5).forEach(user => {
      console.log(`  - ${user.username} (${user.location?.name || 'Unknown location'}): lat=${user.location?.latitude}, lng=${user.location?.longitude}`);
    });
    console.log('✅ Europe active users endpoint working!\n');
    
    // Test 4: Active users in North America
    console.log('4. Testing /active-users/active-nearby (North America)...');
    const northAmericaResponse = await axios.get(`${API_BASE}/active-users/active-nearby`, {
      headers: authHeaders,
      params: {
        latitude: 39.8283,
        longitude: -98.5795,
        radius: 3000000 // 3,000 km - covers most of North America
      }
    });
    console.log(`Found ${northAmericaResponse.data.users.length} active users in North America`);
    console.log('North American users:');
    northAmericaResponse.data.users.slice(0, 5).forEach(user => {
      console.log(`  - ${user.username} (${user.location?.name || 'Unknown location'}): lat=${user.location?.latitude}, lng=${user.location?.longitude}`);
    });
    console.log('✅ North America active users endpoint working!\n');
    
    // Test 5: Active users in Asia
    console.log('5. Testing /active-users/active-nearby (Asia)...');
    const asiaResponse = await axios.get(`${API_BASE}/active-users/active-nearby`, {
      headers: authHeaders,
      params: {
        latitude: 35.6762,
        longitude: 139.6503,
        radius: 5000000 // 5,000 km - covers most of Asia
      }
    });
    console.log(`Found ${asiaResponse.data.users.length} active users in Asia`);
    console.log('Asian users:');
    asiaResponse.data.users.slice(0, 5).forEach(user => {
      console.log(`  - ${user.username} (${user.location?.name || 'Unknown location'}): lat=${user.location?.latitude}, lng=${user.location?.longitude}`);
    });
    console.log('✅ Asia active users endpoint working!\n');
    
    // Test 6: Verify profile image URLs are being returned correctly
    console.log('6. Verifying profile image URLs...');
    const allUsers = worldwideResponse.data.users;
    const usersWithProfilePics = allUsers.filter(user => user.profile_picture_url);
    const usersWithoutProfilePics = allUsers.filter(user => !user.profile_picture_url);
    
    console.log(`📊 Profile Image Statistics:`);
    console.log(`  Total active users: ${allUsers.length}`);
    console.log(`  Users with profile images: ${usersWithProfilePics.length}`);
    console.log(`  Users without profile images: ${usersWithoutProfilePics.length}`);
    
    if (usersWithProfilePics.length > 0) {
      console.log(`  Sample profile image URLs:`);
      usersWithProfilePics.slice(0, 3).forEach(user => {
        console.log(`    ${user.username}: ${user.profile_picture_url}`);
      });
    }
    
    console.log('\n🎉 All API endpoints are working correctly!');
    
  } catch (error) {
    console.error('❌ API Test Error:', error.response?.data || error.message);
  }
}

// Only run if axios is available
if (typeof require !== 'undefined') {
  testActiveUsersAPI();
}
