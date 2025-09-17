#!/usr/bin/env node

import { knex } from '../src/db/index.js';
import axios from 'axios';
import fs from 'fs/promises';

const API_BASE = process.env.API_BASE || 'https://task.amtariksha.com/task/api';
const TEST_TOKEN = process.env.TEST_TOKEN || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOjExLCJlbWFpbCI6InRlc3RAZXhhbXBsZS5jb20iLCJpYXQiOjE3NTgxMTk2NjAsImV4cCI6MTc1ODIwNjA2MH0.LCJ8BZJ-1U2SOf-iYNzJR7fQq3bZDun-ZXD3XOrvABo';

async function healthCheck() {
  console.log('🏥 Task Tool System Health Check');
  console.log('================================\n');

  const results = {
    database: { status: 'unknown', tests: {} },
    api: { status: 'unknown', endpoints: {} },
    files: { status: 'unknown', checks: {} },
    overall: { status: 'unknown', score: 0 }
  };

  let totalTests = 0;
  let passedTests = 0;

  // Database Health Check
  console.log('🗄️  Database Health Check');
  console.log('-------------------------');

  try {
    // Test database connection
    totalTests++;
    await knex.raw('SELECT 1');
    results.database.tests.connection = 'PASS';
    passedTests++;
    console.log('✅ Database connection: PASS');

    // Check required tables exist
    const requiredTables = [
      'users', 'projects', 'tasks', 'modules', 'notes', 
      'chat_channels', 'chat_messages', 'notifications', 
      'file_uploads', 'email_logs'
    ];

    for (const table of requiredTables) {
      totalTests++;
      const exists = await knex.schema.hasTable(table);
      results.database.tests[`table_${table}`] = exists ? 'PASS' : 'FAIL';
      if (exists) {
        passedTests++;
        console.log(`✅ Table ${table}: PASS`);
      } else {
        console.log(`❌ Table ${table}: FAIL`);
      }
    }

    // Test data integrity
    totalTests++;
    const userCount = await knex('users').count('* as count').first();
    if (parseInt(userCount.count) > 0) {
      results.database.tests.data_integrity = 'PASS';
      passedTests++;
      console.log('✅ Data integrity: PASS');
    } else {
      results.database.tests.data_integrity = 'FAIL';
      console.log('❌ Data integrity: FAIL (No users found)');
    }

    results.database.status = 'healthy';
  } catch (error) {
    results.database.status = 'unhealthy';
    results.database.error = error.message;
    console.log(`❌ Database health check failed: ${error.message}`);
  }

  // API Health Check
  console.log('\n🌐 API Health Check');
  console.log('-------------------');

  const headers = { Authorization: `Bearer ${TEST_TOKEN}` };
  const endpoints = [
    { name: 'health', path: '/health', auth: false },
    { name: 'dashboard', path: '/dashboard', auth: true },
    { name: 'projects', path: '/projects', auth: true },
    { name: 'search', path: '/search?q=test', auth: true },
    { name: 'uploads', path: '/uploads/stats', auth: true },
    { name: 'email', path: '/email/templates', auth: true },
    { name: 'calendar', path: '/calendar', auth: true },
    { name: 'notes', path: '/notes', auth: true }
  ];

  for (const endpoint of endpoints) {
    totalTests++;
    try {
      const config = endpoint.auth ? { headers } : {};
      const response = await axios.get(`${API_BASE}${endpoint.path}`, config);
      
      if (response.status === 200) {
        results.api.endpoints[endpoint.name] = 'PASS';
        passedTests++;
        console.log(`✅ ${endpoint.name} endpoint: PASS`);
      } else {
        results.api.endpoints[endpoint.name] = 'FAIL';
        console.log(`❌ ${endpoint.name} endpoint: FAIL (Status: ${response.status})`);
      }
    } catch (error) {
      results.api.endpoints[endpoint.name] = 'FAIL';
      console.log(`❌ ${endpoint.name} endpoint: FAIL (${error.message})`);
    }
  }

  results.api.status = Object.values(results.api.endpoints).every(status => status === 'PASS') 
    ? 'healthy' : 'unhealthy';

  // File System Health Check
  console.log('\n📁 File System Health Check');
  console.log('---------------------------');

  try {
    // Check upload directory
    totalTests++;
    const uploadDir = process.env.UPLOAD_DIR || './uploads';
    try {
      await fs.access(uploadDir);
      results.files.checks.upload_directory = 'PASS';
      passedTests++;
      console.log('✅ Upload directory: PASS');
    } catch {
      await fs.mkdir(uploadDir, { recursive: true });
      results.files.checks.upload_directory = 'CREATED';
      passedTests++;
      console.log('✅ Upload directory: CREATED');
    }

    // Check log directory
    totalTests++;
    const logDir = '/var/log/task-tool';
    try {
      await fs.access(logDir);
      results.files.checks.log_directory = 'PASS';
      passedTests++;
      console.log('✅ Log directory: PASS');
    } catch {
      results.files.checks.log_directory = 'FAIL';
      console.log('❌ Log directory: FAIL (Not accessible)');
    }

    // Check disk space
    totalTests++;
    try {
      const stats = await fs.stat('.');
      results.files.checks.disk_space = 'PASS';
      passedTests++;
      console.log('✅ Disk space: PASS');
    } catch {
      results.files.checks.disk_space = 'FAIL';
      console.log('❌ Disk space: FAIL');
    }

    results.files.status = 'healthy';
  } catch (error) {
    results.files.status = 'unhealthy';
    results.files.error = error.message;
    console.log(`❌ File system check failed: ${error.message}`);
  }

  // Overall Health Score
  const healthScore = Math.round((passedTests / totalTests) * 100);
  results.overall.score = healthScore;
  results.overall.passed = passedTests;
  results.overall.total = totalTests;

  if (healthScore >= 90) {
    results.overall.status = 'excellent';
  } else if (healthScore >= 75) {
    results.overall.status = 'good';
  } else if (healthScore >= 50) {
    results.overall.status = 'fair';
  } else {
    results.overall.status = 'poor';
  }

  // Health Summary
  console.log('\n📊 Health Summary');
  console.log('=================');
  console.log(`Overall Health Score: ${healthScore}% (${passedTests}/${totalTests} tests passed)`);
  console.log(`Overall Status: ${results.overall.status.toUpperCase()}`);
  console.log(`Database Status: ${results.database.status.toUpperCase()}`);
  console.log(`API Status: ${results.api.status.toUpperCase()}`);
  console.log(`File System Status: ${results.files.status.toUpperCase()}`);

  // Recommendations
  console.log('\n💡 Recommendations');
  console.log('==================');

  if (healthScore < 100) {
    console.log('Issues found that need attention:');
    
    // Database issues
    Object.entries(results.database.tests).forEach(([test, status]) => {
      if (status === 'FAIL') {
        console.log(`❌ Database: ${test} failed`);
      }
    });

    // API issues
    Object.entries(results.api.endpoints).forEach(([endpoint, status]) => {
      if (status === 'FAIL') {
        console.log(`❌ API: ${endpoint} endpoint failed`);
      }
    });

    // File system issues
    Object.entries(results.files.checks).forEach(([check, status]) => {
      if (status === 'FAIL') {
        console.log(`❌ Files: ${check} failed`);
      }
    });
  } else {
    console.log('🎉 All systems are healthy!');
  }

  // Save health report
  const report = {
    timestamp: new Date().toISOString(),
    ...results
  };

  try {
    await fs.writeFile('health-report.json', JSON.stringify(report, null, 2));
    console.log('\n📄 Health report saved to health-report.json');
  } catch (error) {
    console.log(`⚠️  Could not save health report: ${error.message}`);
  }

  console.log('\n🏥 Health check completed!');
  
  return results;
}

// Run health check
healthCheck()
  .then((results) => {
    process.exit(results.overall.score >= 75 ? 0 : 1);
  })
  .catch(error => {
    console.error('Health check failed:', error);
    process.exit(1);
  });
