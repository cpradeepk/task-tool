#!/usr/bin/env node

/**
 * SwargFood Task Management - OAuth Testing Script
 * Tests the Google OAuth implementation and admin user functionality
 */

const { PrismaClient } = require('@prisma/client');
const axios = require('axios');
const readline = require('readline');

const prisma = new PrismaClient();

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function question(query) {
  return new Promise(resolve => rl.question(query, resolve));
}

// Test configuration
const TEST_CONFIG = {
  baseUrl: process.env.API_BASE_URL || 'http://localhost:3000',
  testTimeout: 10000
};

async function testDatabaseConnection() {
  console.log('🔍 Testing database connection...');
  try {
    await prisma.$connect();
    console.log('✅ Database connection successful');
    return true;
  } catch (error) {
    console.log('❌ Database connection failed:', error.message);
    return false;
  }
}

async function testServerHealth() {
  console.log('🔍 Testing server health...');
  try {
    const response = await axios.get(`${TEST_CONFIG.baseUrl}/task/health`, {
      timeout: TEST_CONFIG.testTimeout
    });
    
    if (response.status === 200 && response.data.status === 'OK') {
      console.log('✅ Server health check passed');
      return true;
    } else {
      console.log('❌ Server health check failed:', response.data);
      return false;
    }
  } catch (error) {
    console.log('❌ Server health check failed:', error.message);
    return false;
  }
}

async function testApiEndpoints() {
  console.log('🔍 Testing API endpoints...');
  try {
    const response = await axios.get(`${TEST_CONFIG.baseUrl}/task/api`, {
      timeout: TEST_CONFIG.testTimeout
    });
    
    if (response.status === 200 && response.data.message) {
      console.log('✅ API endpoints accessible');
      console.log(`📋 API Version: ${response.data.version}`);
      return true;
    } else {
      console.log('❌ API endpoints test failed');
      return false;
    }
  } catch (error) {
    console.log('❌ API endpoints test failed:', error.message);
    return false;
  }
}

async function testAdminUsers() {
  console.log('🔍 Testing admin users...');
  try {
    const adminUsers = await prisma.user.findMany({
      where: { isAdmin: true },
      select: { id: true, email: true, name: true, role: true, isActive: true }
    });

    if (adminUsers.length === 0) {
      console.log('❌ No admin users found!');
      return false;
    }

    console.log('✅ Admin users found:');
    adminUsers.forEach((user, index) => {
      console.log(`   ${index + 1}. ${user.name} (${user.email}) - ${user.role}`);
    });

    return true;
  } catch (error) {
    console.log('❌ Admin users test failed:', error.message);
    return false;
  }
}

async function testGoogleOAuthEndpoint() {
  console.log('🔍 Testing Google OAuth endpoint...');
  try {
    // Test with invalid token to check endpoint availability
    const response = await axios.post(`${TEST_CONFIG.baseUrl}/task/api/auth/google`, {
      token: 'invalid-test-token'
    }, {
      timeout: TEST_CONFIG.testTimeout,
      validateStatus: function (status) {
        // Accept 400 and 401 as valid responses (endpoint is working)
        return status >= 200 && status < 500;
      }
    });

    if (response.status === 400 || response.status === 401) {
      console.log('✅ Google OAuth endpoint is accessible');
      console.log('📝 Note: Endpoint correctly rejects invalid tokens');
      return true;
    } else {
      console.log('❌ Unexpected response from OAuth endpoint:', response.status);
      return false;
    }
  } catch (error) {
    console.log('❌ Google OAuth endpoint test failed:', error.message);
    return false;
  }
}

async function testEnvironmentVariables() {
  console.log('🔍 Testing environment variables...');
  
  const requiredVars = [
    'DATABASE_URL',
    'JWT_SECRET',
    'GOOGLE_CLIENT_ID',
    'GOOGLE_CLIENT_SECRET'
  ];

  const missingVars = [];
  const placeholderVars = [];

  requiredVars.forEach(varName => {
    const value = process.env[varName];
    if (!value) {
      missingVars.push(varName);
    } else if (value.includes('your-') || value.includes('replace-this')) {
      placeholderVars.push(varName);
    }
  });

  if (missingVars.length > 0) {
    console.log('❌ Missing environment variables:');
    missingVars.forEach(varName => console.log(`   - ${varName}`));
    return false;
  }

  if (placeholderVars.length > 0) {
    console.log('⚠️  Placeholder values detected:');
    placeholderVars.forEach(varName => console.log(`   - ${varName}`));
    console.log('📝 Please update these with actual values');
    return false;
  }

  console.log('✅ Environment variables configured');
  return true;
}

async function runInteractiveOAuthTest() {
  console.log('\n🧪 Interactive OAuth Test');
  console.log('========================');
  console.log('This test requires manual Google OAuth token generation.');
  console.log('1. Go to https://developers.google.com/oauthplayground/');
  console.log('2. Select "Google+ API v1" → "https://www.googleapis.com/auth/userinfo.email"');
  console.log('3. Click "Authorize APIs" and complete OAuth flow');
  console.log('4. Click "Exchange authorization code for tokens"');
  console.log('5. Copy the "id_token" value\n');

  const runTest = await question('Do you want to run the interactive OAuth test? (y/N): ');
  
  if (runTest.toLowerCase() !== 'y' && runTest.toLowerCase() !== 'yes') {
    console.log('⏭️  Skipping interactive OAuth test');
    return true;
  }

  const idToken = await question('Enter the Google ID token: ');
  
  if (!idToken) {
    console.log('❌ No token provided, skipping test');
    return false;
  }

  try {
    const response = await axios.post(`${TEST_CONFIG.baseUrl}/task/api/auth/google`, {
      token: idToken
    }, {
      timeout: TEST_CONFIG.testTimeout
    });

    if (response.status === 200 && response.data.tokens) {
      console.log('✅ Google OAuth test successful!');
      console.log(`👤 User: ${response.data.user.name} (${response.data.user.email})`);
      console.log(`🔑 Admin: ${response.data.user.isAdmin}`);
      return true;
    } else {
      console.log('❌ OAuth test failed:', response.data);
      return false;
    }
  } catch (error) {
    console.log('❌ OAuth test failed:', error.response?.data || error.message);
    return false;
  }
}

async function main() {
  console.log('🧪 SwargFood Task Management - OAuth Testing Suite');
  console.log('==================================================\n');

  const tests = [
    { name: 'Database Connection', fn: testDatabaseConnection },
    { name: 'Server Health', fn: testServerHealth },
    { name: 'API Endpoints', fn: testApiEndpoints },
    { name: 'Environment Variables', fn: testEnvironmentVariables },
    { name: 'Admin Users', fn: testAdminUsers },
    { name: 'Google OAuth Endpoint', fn: testGoogleOAuthEndpoint }
  ];

  let passedTests = 0;
  let totalTests = tests.length;

  for (const test of tests) {
    console.log(`\n🔄 Running: ${test.name}`);
    const result = await test.fn();
    if (result) {
      passedTests++;
    }
  }

  // Interactive OAuth test
  await runInteractiveOAuthTest();

  console.log('\n📊 Test Results Summary');
  console.log('=======================');
  console.log(`✅ Passed: ${passedTests}/${totalTests}`);
  console.log(`❌ Failed: ${totalTests - passedTests}/${totalTests}`);

  if (passedTests === totalTests) {
    console.log('\n🎉 All tests passed! OAuth setup is ready.');
    console.log('\n📝 Next Steps:');
    console.log('1. Update Google OAuth credentials with real values');
    console.log('2. Test the frontend Google Sign-In button');
    console.log('3. Verify admin access in the application');
  } else {
    console.log('\n⚠️  Some tests failed. Please address the issues above.');
  }

  await prisma.$disconnect();
  rl.close();
}

// Handle script execution
if (require.main === module) {
  main().catch(console.error);
}

module.exports = { main };
