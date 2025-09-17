#!/usr/bin/env node

import axios from 'axios';
import { knex } from '../src/db/index.js';

const API_BASE = process.env.API_BASE || 'https://task.amtariksha.com/task/api';

async function endToEndTest() {
  console.log('🔄 End-to-End Testing - Task Tool Application');
  console.log('==============================================\n');

  const results = {
    authentication: { status: 'unknown', tests: {} },
    coreFeatures: { status: 'unknown', tests: {} },
    advancedFeatures: { status: 'unknown', tests: {} },
    integration: { status: 'unknown', tests: {} },
    overall: { passed: 0, total: 0, score: 0 }
  };

  let testToken = '';

  // Test 1: Authentication Flow
  console.log('🔐 Testing Authentication Flow');
  console.log('------------------------------');

  try {
    // Test PIN authentication
    results.overall.total++;
    const authResponse = await axios.post(`${API_BASE}/pin-auth/login`, {
      email: 'test@example.com',
      pin: '1234'
    });

    if (authResponse.status === 200 && authResponse.data.token) {
      results.authentication.tests.pin_auth = 'PASS';
      results.overall.passed++;
      testToken = authResponse.data.token;
      console.log('✅ PIN Authentication: PASS');
    } else {
      results.authentication.tests.pin_auth = 'FAIL';
      console.log('❌ PIN Authentication: FAIL');
    }

    // Test admin authentication
    results.overall.total++;
    const adminAuthResponse = await axios.post(`${API_BASE}/admin-auth/login`, {
      username: 'admin',
      password: '1234'
    });

    if (adminAuthResponse.status === 200 && adminAuthResponse.data.token) {
      results.authentication.tests.admin_auth = 'PASS';
      results.overall.passed++;
      console.log('✅ Admin Authentication: PASS');
    } else {
      results.authentication.tests.admin_auth = 'FAIL';
      console.log('❌ Admin Authentication: FAIL');
    }

    results.authentication.status = 'healthy';
  } catch (error) {
    results.authentication.status = 'unhealthy';
    console.log(`❌ Authentication error: ${error.message}`);
  }

  const headers = { Authorization: `Bearer ${testToken}` };

  // Test 2: Core Features
  console.log('\n📋 Testing Core Features');
  console.log('------------------------');

  try {
    // Test dashboard
    results.overall.total++;
    const dashboardResponse = await axios.get(`${API_BASE}/dashboard`, { headers });
    if (dashboardResponse.status === 200) {
      results.coreFeatures.tests.dashboard = 'PASS';
      results.overall.passed++;
      console.log('✅ Dashboard API: PASS');
    } else {
      results.coreFeatures.tests.dashboard = 'FAIL';
      console.log('❌ Dashboard API: FAIL');
    }

    // Test projects
    results.overall.total++;
    const projectsResponse = await axios.get(`${API_BASE}/projects`, { headers });
    if (projectsResponse.status === 200) {
      results.coreFeatures.tests.projects = 'PASS';
      results.overall.passed++;
      console.log(`✅ Projects API: PASS (${projectsResponse.data.length} projects)`);
    } else {
      results.coreFeatures.tests.projects = 'FAIL';
      console.log('❌ Projects API: FAIL');
    }

    // Test tasks (using first project if available)
    results.overall.total++;
    if (projectsResponse.data && projectsResponse.data.length > 0) {
      const firstProject = projectsResponse.data[0];
      const tasksResponse = await axios.get(`${API_BASE}/projects/${firstProject.id}/tasks`, { headers });
      if (tasksResponse.status === 200) {
        results.coreFeatures.tests.tasks = 'PASS';
        results.overall.passed++;
        console.log(`✅ Tasks API: PASS (${tasksResponse.data.length} tasks)`);
      } else {
        results.coreFeatures.tests.tasks = 'FAIL';
        console.log('❌ Tasks API: FAIL');
      }
    } else {
      results.coreFeatures.tests.tasks = 'SKIP';
      console.log('⏭️  Tasks API: SKIP (No projects available)');
    }

    // Test user profile
    results.overall.total++;
    const profileResponse = await axios.get(`${API_BASE}/me`, { headers });
    if (profileResponse.status === 200) {
      results.coreFeatures.tests.profile = 'PASS';
      results.overall.passed++;
      console.log('✅ User Profile API: PASS');
    } else {
      results.coreFeatures.tests.profile = 'FAIL';
      console.log('❌ User Profile API: FAIL');
    }

    results.coreFeatures.status = 'healthy';
  } catch (error) {
    results.coreFeatures.status = 'unhealthy';
    console.log(`❌ Core features error: ${error.message}`);
  }

  // Test 3: Advanced Features (Phase 3)
  console.log('\n🚀 Testing Advanced Features');
  console.log('----------------------------');

  try {
    // Test search functionality
    results.overall.total++;
    const searchResponse = await axios.get(`${API_BASE}/search?q=project`, { headers });
    if (searchResponse.status === 200) {
      results.advancedFeatures.tests.search = 'PASS';
      results.overall.passed++;
      console.log('✅ Advanced Search: PASS');
    } else {
      results.advancedFeatures.tests.search = 'FAIL';
      console.log('❌ Advanced Search: FAIL');
    }

    // Test file upload system
    results.overall.total++;
    const fileStatsResponse = await axios.get(`${API_BASE}/uploads/stats`, { headers });
    if (fileStatsResponse.status === 200) {
      results.advancedFeatures.tests.file_upload = 'PASS';
      results.overall.passed++;
      console.log('✅ File Upload System: PASS');
    } else {
      results.advancedFeatures.tests.file_upload = 'FAIL';
      console.log('❌ File Upload System: FAIL');
    }

    // Test notifications system
    results.overall.total++;
    const notificationsResponse = await axios.get(`${API_BASE}/notifications`, { headers });
    if (notificationsResponse.status === 200) {
      results.advancedFeatures.tests.notifications = 'PASS';
      results.overall.passed++;
      console.log('✅ Notifications System: PASS');
    } else {
      results.advancedFeatures.tests.notifications = 'FAIL';
      console.log('❌ Notifications System: FAIL');
    }

    // Test email templates
    results.overall.total++;
    const emailTemplatesResponse = await axios.get(`${API_BASE}/email/templates`, { headers });
    if (emailTemplatesResponse.status === 200) {
      results.advancedFeatures.tests.email_system = 'PASS';
      results.overall.passed++;
      console.log('✅ Email System: PASS');
    } else {
      results.advancedFeatures.tests.email_system = 'FAIL';
      console.log('❌ Email System: FAIL');
    }

    results.advancedFeatures.status = 'healthy';
  } catch (error) {
    results.advancedFeatures.status = 'unhealthy';
    console.log(`❌ Advanced features error: ${error.message}`);
  }

  // Test 4: System Integration
  console.log('\n🔗 Testing System Integration');
  console.log('-----------------------------');

  try {
    // Test database connectivity
    results.overall.total++;
    await knex.raw('SELECT 1');
    results.integration.tests.database = 'PASS';
    results.overall.passed++;
    console.log('✅ Database Integration: PASS');

    // Test API response times
    results.overall.total++;
    const start = Date.now();
    await axios.get(`${API_BASE}/dashboard`, { headers });
    const responseTime = Date.now() - start;
    
    if (responseTime < 1000) {
      results.integration.tests.response_time = 'PASS';
      results.overall.passed++;
      console.log(`✅ API Response Time: PASS (${responseTime}ms)`);
    } else {
      results.integration.tests.response_time = 'FAIL';
      console.log(`❌ API Response Time: FAIL (${responseTime}ms - too slow)`);
    }

    // Test concurrent requests
    results.overall.total++;
    const concurrentStart = Date.now();
    const promises = Array(5).fill().map(() => 
      axios.get(`${API_BASE}/projects`, { headers })
    );
    
    await Promise.all(promises);
    const concurrentTime = Date.now() - concurrentStart;
    
    if (concurrentTime < 2000) {
      results.integration.tests.concurrent_requests = 'PASS';
      results.overall.passed++;
      console.log(`✅ Concurrent Requests: PASS (${concurrentTime}ms for 5 requests)`);
    } else {
      results.integration.tests.concurrent_requests = 'FAIL';
      console.log(`❌ Concurrent Requests: FAIL (${concurrentTime}ms - too slow)`);
    }

    results.integration.status = 'healthy';
  } catch (error) {
    results.integration.status = 'unhealthy';
    console.log(`❌ Integration error: ${error.message}`);
  }

  // Calculate overall score
  results.overall.score = Math.round((results.overall.passed / results.overall.total) * 100);

  // Final Results
  console.log('\n🎯 End-to-End Test Results');
  console.log('==========================');
  console.log(`Overall Score: ${results.overall.score}% (${results.overall.passed}/${results.overall.total} tests passed)`);
  console.log(`Authentication: ${results.authentication.status.toUpperCase()}`);
  console.log(`Core Features: ${results.coreFeatures.status.toUpperCase()}`);
  console.log(`Advanced Features: ${results.advancedFeatures.status.toUpperCase()}`);
  console.log(`System Integration: ${results.integration.status.toUpperCase()}`);

  // Status Assessment
  console.log('\n📊 System Status Assessment');
  console.log('===========================');
  
  if (results.overall.score >= 95) {
    console.log('🎉 EXCELLENT: System is production-ready with all features working perfectly!');
  } else if (results.overall.score >= 85) {
    console.log('✅ GOOD: System is stable with minor issues that can be addressed post-deployment.');
  } else if (results.overall.score >= 70) {
    console.log('⚠️  FAIR: System has some issues that should be addressed before full production use.');
  } else {
    console.log('❌ POOR: System has significant issues that need immediate attention.');
  }

  // Production Readiness Checklist
  console.log('\n✅ Production Readiness Checklist');
  console.log('=================================');
  console.log(`${results.authentication.status === 'healthy' ? '✅' : '❌'} Authentication System`);
  console.log(`${results.coreFeatures.status === 'healthy' ? '✅' : '❌'} Core Features (Projects, Tasks, Dashboard)`);
  console.log(`${results.advancedFeatures.status === 'healthy' ? '✅' : '❌'} Advanced Features (Search, Files, Notifications, Email)`);
  console.log(`${results.integration.status === 'healthy' ? '✅' : '❌'} System Integration & Performance`);

  console.log('\n🔄 End-to-end testing completed!');
  
  return results;
}

// Run end-to-end tests
endToEndTest()
  .then((results) => {
    process.exit(results.overall.score >= 80 ? 0 : 1);
  })
  .catch(error => {
    console.error('End-to-end testing failed:', error);
    process.exit(1);
  });
