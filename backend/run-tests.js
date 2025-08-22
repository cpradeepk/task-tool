#!/usr/bin/env node

/**
 * Test Runner for Margadarshi Task Management System
 * Runs comprehensive tests for Phase 3 & 4 features
 */

import { spawn } from 'child_process';
import { knex } from './src/db/index.js';
import fs from 'fs';
import path from 'path';

const testResults = {
  passed: 0,
  failed: 0,
  total: 0,
  duration: 0,
  coverage: null
};

async function runTests() {
  console.log('🧪 Starting Margadarshi Test Suite');
  console.log('='.repeat(50));
  
  const startTime = Date.now();
  
  try {
    // Check if test database is available
    console.log('📡 Checking test database connection...');
    await checkTestDatabase();
    
    // Run migration for test database
    console.log('🗄️  Setting up test database...');
    await setupTestDatabase();
    
    // Run unit tests
    console.log('🔬 Running unit tests...');
    await runUnitTests();
    
    // Run integration tests
    console.log('🔗 Running integration tests...');
    await runIntegrationTests();
    
    // Run API tests
    console.log('🌐 Running API tests...');
    await runAPITests();
    
    // Run performance tests
    console.log('⚡ Running performance tests...');
    await runPerformanceTests();
    
    // Generate test report
    console.log('📊 Generating test report...');
    await generateTestReport();
    
    const endTime = Date.now();
    testResults.duration = endTime - startTime;
    
    console.log('✅ All tests completed successfully!');
    console.log(`📈 Results: ${testResults.passed}/${testResults.total} tests passed`);
    console.log(`⏱️  Duration: ${testResults.duration}ms`);
    
    if (testResults.failed > 0) {
      console.log(`❌ ${testResults.failed} tests failed`);
      process.exit(1);
    }
    
  } catch (error) {
    console.error('❌ Test suite failed:', error.message);
    process.exit(1);
  } finally {
    await knex.destroy();
  }
}

async function checkTestDatabase() {
  try {
    await knex.raw('SELECT 1');
    console.log('   ✅ Test database connection successful');
  } catch (error) {
    throw new Error(`Test database connection failed: ${error.message}`);
  }
}

async function setupTestDatabase() {
  try {
    // Run migrations
    await knex.migrate.latest();
    console.log('   ✅ Test database migrations completed');
    
    // Seed test data
    await seedTestData();
    console.log('   ✅ Test data seeded');
  } catch (error) {
    throw new Error(`Test database setup failed: ${error.message}`);
  }
}

async function seedTestData() {
  // Create test users
  await knex('users').insert([
    {
      id: 'test-user-1',
      email: 'testuser1@example.com',
      name: 'Test User 1',
      password: 'hashedpassword',
      status: 'active'
    },
    {
      id: 'test-admin-1',
      email: 'testadmin1@example.com',
      name: 'Test Admin 1',
      password: 'hashedpassword',
      status: 'active'
    }
  ]);
  
  // Create test project
  await knex('projects').insert({
    id: 1,
    name: 'Test Project',
    description: 'Test project for automated tests',
    created_by: 'test-user-1'
  });
  
  // Create test module
  await knex('modules').insert({
    id: 1,
    name: 'Test Module',
    description: 'Test module for automated tests',
    project_id: 1
  });
}

async function runUnitTests() {
  return new Promise((resolve, reject) => {
    const jest = spawn('npx', ['jest', '--testPathPattern=unit', '--verbose'], {
      stdio: 'pipe',
      cwd: process.cwd()
    });
    
    let output = '';
    
    jest.stdout.on('data', (data) => {
      output += data.toString();
      process.stdout.write(data);
    });
    
    jest.stderr.on('data', (data) => {
      output += data.toString();
      process.stderr.write(data);
    });
    
    jest.on('close', (code) => {
      parseTestResults(output);
      if (code === 0) {
        console.log('   ✅ Unit tests passed');
        resolve();
      } else {
        console.log('   ❌ Unit tests failed');
        reject(new Error('Unit tests failed'));
      }
    });
  });
}

async function runIntegrationTests() {
  return new Promise((resolve, reject) => {
    const jest = spawn('npx', ['jest', '--testPathPattern=integration', '--verbose'], {
      stdio: 'pipe',
      cwd: process.cwd()
    });
    
    let output = '';
    
    jest.stdout.on('data', (data) => {
      output += data.toString();
      process.stdout.write(data);
    });
    
    jest.stderr.on('data', (data) => {
      output += data.toString();
      process.stderr.write(data);
    });
    
    jest.on('close', (code) => {
      parseTestResults(output);
      if (code === 0) {
        console.log('   ✅ Integration tests passed');
        resolve();
      } else {
        console.log('   ❌ Integration tests failed');
        reject(new Error('Integration tests failed'));
      }
    });
  });
}

async function runAPITests() {
  return new Promise((resolve, reject) => {
    const jest = spawn('npx', ['jest', 'tests/phase3-4-features.test.js', '--verbose'], {
      stdio: 'pipe',
      cwd: process.cwd()
    });
    
    let output = '';
    
    jest.stdout.on('data', (data) => {
      output += data.toString();
      process.stdout.write(data);
    });
    
    jest.stderr.on('data', (data) => {
      output += data.toString();
      process.stderr.write(data);
    });
    
    jest.on('close', (code) => {
      parseTestResults(output);
      if (code === 0) {
        console.log('   ✅ API tests passed');
        resolve();
      } else {
        console.log('   ❌ API tests failed');
        reject(new Error('API tests failed'));
      }
    });
  });
}

async function runPerformanceTests() {
  return new Promise((resolve, reject) => {
    const jest = spawn('npx', ['jest', '--testPathPattern=performance', '--verbose'], {
      stdio: 'pipe',
      cwd: process.cwd()
    });
    
    let output = '';
    
    jest.stdout.on('data', (data) => {
      output += data.toString();
      process.stdout.write(data);
    });
    
    jest.stderr.on('data', (data) => {
      output += data.toString();
      process.stderr.write(data);
    });
    
    jest.on('close', (code) => {
      parseTestResults(output);
      if (code === 0) {
        console.log('   ✅ Performance tests passed');
        resolve();
      } else {
        console.log('   ❌ Performance tests failed');
        reject(new Error('Performance tests failed'));
      }
    });
  });
}

function parseTestResults(output) {
  // Parse Jest output to extract test results
  const passedMatch = output.match(/(\d+) passed/);
  const failedMatch = output.match(/(\d+) failed/);
  const totalMatch = output.match(/Tests:\s+(\d+)/);
  
  if (passedMatch) testResults.passed += parseInt(passedMatch[1]);
  if (failedMatch) testResults.failed += parseInt(failedMatch[1]);
  if (totalMatch) testResults.total += parseInt(totalMatch[1]);
}

async function generateTestReport() {
  const report = {
    timestamp: new Date().toISOString(),
    results: testResults,
    environment: {
      node_version: process.version,
      platform: process.platform,
      arch: process.arch
    },
    features_tested: [
      'Task Support Team Management',
      'Task Comments and History',
      'Task Templates System',
      'Leave Management',
      'WFH Management',
      'Enhanced User Management',
      'Employee ID Cards',
      'Dashboard Enhancements',
      'Performance Optimization'
    ]
  };
  
  const reportPath = path.join(process.cwd(), 'test-report.json');
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
  
  console.log(`   ✅ Test report generated: ${reportPath}`);
  
  // Generate HTML report
  const htmlReport = generateHTMLReport(report);
  const htmlPath = path.join(process.cwd(), 'test-report.html');
  fs.writeFileSync(htmlPath, htmlReport);
  
  console.log(`   ✅ HTML test report generated: ${htmlPath}`);
}

function generateHTMLReport(report) {
  return `
<!DOCTYPE html>
<html>
<head>
    <title>Margadarshi Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f39c12; color: white; padding: 20px; border-radius: 8px; }
        .summary { display: flex; gap: 20px; margin: 20px 0; }
        .stat { background: #ecf0f1; padding: 15px; border-radius: 8px; flex: 1; text-align: center; }
        .passed { background: #2ecc71; color: white; }
        .failed { background: #e74c3c; color: white; }
        .features { margin: 20px 0; }
        .feature { background: #3498db; color: white; padding: 10px; margin: 5px 0; border-radius: 4px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🧪 Margadarshi Test Report</h1>
        <p>Generated: ${report.timestamp}</p>
    </div>
    
    <div class="summary">
        <div class="stat passed">
            <h3>${report.results.passed}</h3>
            <p>Tests Passed</p>
        </div>
        <div class="stat ${report.results.failed > 0 ? 'failed' : ''}">
            <h3>${report.results.failed}</h3>
            <p>Tests Failed</p>
        </div>
        <div class="stat">
            <h3>${report.results.total}</h3>
            <p>Total Tests</p>
        </div>
        <div class="stat">
            <h3>${report.results.duration}ms</h3>
            <p>Duration</p>
        </div>
    </div>
    
    <div class="features">
        <h2>✅ Features Tested</h2>
        ${report.features_tested.map(feature => `<div class="feature">${feature}</div>`).join('')}
    </div>
    
    <div class="environment">
        <h2>🔧 Environment</h2>
        <p><strong>Node.js:</strong> ${report.environment.node_version}</p>
        <p><strong>Platform:</strong> ${report.environment.platform}</p>
        <p><strong>Architecture:</strong> ${report.environment.arch}</p>
    </div>
</body>
</html>
  `;
}

// Run tests if this file is executed directly
if (import.meta.url === `file://${process.argv[1]}`) {
  runTests();
}

export { runTests };
