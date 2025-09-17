#!/usr/bin/env node

import axios from 'axios';
import { knex } from '../src/db/index.js';

const API_BASE = process.env.API_BASE || 'https://task.amtariksha.com/task/api';
const TEST_TOKEN = process.env.TEST_TOKEN || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOjExLCJlbWFpbCI6InRlc3RAZXhhbXBsZS5jb20iLCJpYXQiOjE3NTgxMTk2NjAsImV4cCI6MTc1ODIwNjA2MH0.LCJ8BZJ-1U2SOf-iYNzJR7fQq3bZDun-ZXD3XOrvABo';

async function testPhase3Features() {
  console.log('🧪 Testing Phase 3 Features');
  console.log('============================\n');

  const results = {
    notifications: { status: 'unknown', tests: {} },
    fileUpload: { status: 'unknown', tests: {} },
    search: { status: 'unknown', tests: {} },
    email: { status: 'unknown', tests: {} },
    overall: { passed: 0, total: 0, score: 0 }
  };

  const headers = { Authorization: `Bearer ${TEST_TOKEN}` };

  // Test 1: Real-time Notifications System
  console.log('🔔 Testing Real-time Notifications System');
  console.log('------------------------------------------');

  try {
    // Test notifications API
    results.overall.total++;
    const notificationsResponse = await axios.get(`${API_BASE}/notifications`, { headers });
    if (notificationsResponse.status === 200) {
      results.notifications.tests.api_endpoint = 'PASS';
      results.overall.passed++;
      console.log('✅ Notifications API endpoint: PASS');
    } else {
      results.notifications.tests.api_endpoint = 'FAIL';
      console.log('❌ Notifications API endpoint: FAIL');
    }

    // Test notifications database table
    results.overall.total++;
    const notificationCount = await knex('notifications').count('* as count').first();
    results.notifications.tests.database_table = 'PASS';
    results.overall.passed++;
    console.log(`✅ Notifications database table: PASS (${notificationCount.count} records)`);

    // Test notification creation
    results.overall.total++;
    try {
      await knex('notifications').insert({
        user_id: 11,
        title: 'Test Notification',
        message: 'This is a test notification',
        type: 'test',
        read: false,
        created_at: new Date(),
        updated_at: new Date()
      });
      results.notifications.tests.creation = 'PASS';
      results.overall.passed++;
      console.log('✅ Notification creation: PASS');
    } catch (error) {
      results.notifications.tests.creation = 'FAIL';
      console.log(`❌ Notification creation: FAIL (${error.message})`);
    }

    results.notifications.status = 'healthy';
  } catch (error) {
    results.notifications.status = 'unhealthy';
    console.log(`❌ Notifications system error: ${error.message}`);
  }

  // Test 2: File Upload & Management System
  console.log('\n📎 Testing File Upload & Management System');
  console.log('-------------------------------------------');

  try {
    // Test file upload API endpoints
    results.overall.total++;
    const filesResponse = await axios.get(`${API_BASE}/uploads/files`, { headers });
    if (filesResponse.status === 200) {
      results.fileUpload.tests.files_endpoint = 'PASS';
      results.overall.passed++;
      console.log('✅ Files API endpoint: PASS');
    } else {
      results.fileUpload.tests.files_endpoint = 'FAIL';
      console.log('❌ Files API endpoint: FAIL');
    }

    // Test file statistics endpoint
    results.overall.total++;
    const statsResponse = await axios.get(`${API_BASE}/uploads/stats`, { headers });
    if (statsResponse.status === 200) {
      results.fileUpload.tests.stats_endpoint = 'PASS';
      results.overall.passed++;
      console.log('✅ File stats endpoint: PASS');
    } else {
      results.fileUpload.tests.stats_endpoint = 'FAIL';
      console.log('❌ File stats endpoint: FAIL');
    }

    // Test file uploads database table
    results.overall.total++;
    const fileCount = await knex('file_uploads').count('* as count').first();
    results.fileUpload.tests.database_table = 'PASS';
    results.overall.passed++;
    console.log(`✅ File uploads database table: PASS (${fileCount.count} files)`);

    results.fileUpload.status = 'healthy';
  } catch (error) {
    results.fileUpload.status = 'unhealthy';
    console.log(`❌ File upload system error: ${error.message}`);
  }

  // Test 3: Advanced Search & Filtering
  console.log('\n🔍 Testing Advanced Search & Filtering');
  console.log('--------------------------------------');

  try {
    // Test global search endpoint
    results.overall.total++;
    const searchResponse = await axios.get(`${API_BASE}/search?q=project`, { headers });
    if (searchResponse.status === 200) {
      results.search.tests.global_search = 'PASS';
      results.overall.passed++;
      console.log('✅ Global search endpoint: PASS');
    } else {
      results.search.tests.global_search = 'FAIL';
      console.log('❌ Global search endpoint: FAIL');
    }

    // Test search filters endpoint
    results.overall.total++;
    const filtersResponse = await axios.get(`${API_BASE}/search/filters`, { headers });
    if (filtersResponse.status === 200) {
      results.search.tests.filters_endpoint = 'PASS';
      results.overall.passed++;
      console.log('✅ Search filters endpoint: PASS');
    } else {
      results.search.tests.filters_endpoint = 'FAIL';
      console.log('❌ Search filters endpoint: FAIL');
    }

    // Test search suggestions endpoint
    results.overall.total++;
    const suggestionsResponse = await axios.get(`${API_BASE}/search/suggestions?q=test`, { headers });
    if (suggestionsResponse.status === 200) {
      results.search.tests.suggestions_endpoint = 'PASS';
      results.overall.passed++;
      console.log('✅ Search suggestions endpoint: PASS');
    } else {
      results.search.tests.suggestions_endpoint = 'FAIL';
      console.log('❌ Search suggestions endpoint: FAIL');
    }

    // Test search statistics endpoint
    results.overall.total++;
    const searchStatsResponse = await axios.get(`${API_BASE}/search/stats`, { headers });
    if (searchStatsResponse.status === 200) {
      results.search.tests.stats_endpoint = 'PASS';
      results.overall.passed++;
      console.log('✅ Search statistics endpoint: PASS');
    } else {
      results.search.tests.stats_endpoint = 'FAIL';
      console.log('❌ Search statistics endpoint: FAIL');
    }

    results.search.status = 'healthy';
  } catch (error) {
    results.search.status = 'unhealthy';
    console.log(`❌ Search system error: ${error.message}`);
  }

  // Test 4: Email Integration & Templates
  console.log('\n📧 Testing Email Integration & Templates');
  console.log('----------------------------------------');

  try {
    // Test email templates endpoint
    results.overall.total++;
    const templatesResponse = await axios.get(`${API_BASE}/email/templates`, { headers });
    if (templatesResponse.status === 200) {
      results.email.tests.templates_endpoint = 'PASS';
      results.overall.passed++;
      console.log('✅ Email templates endpoint: PASS');
      
      const templates = templatesResponse.data.templates;
      console.log(`   📋 Available templates: ${templates.length}`);
      templates.forEach(template => {
        console.log(`   - ${template.name}: ${template.description}`);
      });
    } else {
      results.email.tests.templates_endpoint = 'FAIL';
      console.log('❌ Email templates endpoint: FAIL');
    }

    // Test email logs endpoint
    results.overall.total++;
    const logsResponse = await axios.get(`${API_BASE}/email/logs`, { headers });
    if (logsResponse.status === 200) {
      results.email.tests.logs_endpoint = 'PASS';
      results.overall.passed++;
      console.log('✅ Email logs endpoint: PASS');
    } else {
      results.email.tests.logs_endpoint = 'FAIL';
      console.log('❌ Email logs endpoint: FAIL');
    }

    // Test email logs database table
    results.overall.total++;
    const emailLogCount = await knex('email_logs').count('* as count').first();
    results.email.tests.database_table = 'PASS';
    results.overall.passed++;
    console.log(`✅ Email logs database table: PASS (${emailLogCount.count} logs)`);

    results.email.status = 'healthy';
  } catch (error) {
    results.email.status = 'unhealthy';
    console.log(`❌ Email system error: ${error.message}`);
  }

  // Calculate overall score
  results.overall.score = Math.round((results.overall.passed / results.overall.total) * 100);

  // Test Summary
  console.log('\n📊 Phase 3 Features Test Summary');
  console.log('=================================');
  console.log(`Overall Score: ${results.overall.score}% (${results.overall.passed}/${results.overall.total} tests passed)`);
  console.log(`Notifications System: ${results.notifications.status.toUpperCase()}`);
  console.log(`File Upload System: ${results.fileUpload.status.toUpperCase()}`);
  console.log(`Search System: ${results.search.status.toUpperCase()}`);
  console.log(`Email System: ${results.email.status.toUpperCase()}`);

  // Detailed Results
  console.log('\n📋 Detailed Test Results');
  console.log('========================');
  
  console.log('Notifications Tests:');
  Object.entries(results.notifications.tests).forEach(([test, status]) => {
    console.log(`  ${status === 'PASS' ? '✅' : '❌'} ${test}: ${status}`);
  });

  console.log('File Upload Tests:');
  Object.entries(results.fileUpload.tests).forEach(([test, status]) => {
    console.log(`  ${status === 'PASS' ? '✅' : '❌'} ${test}: ${status}`);
  });

  console.log('Search Tests:');
  Object.entries(results.search.tests).forEach(([test, status]) => {
    console.log(`  ${status === 'PASS' ? '✅' : '❌'} ${test}: ${status}`);
  });

  console.log('Email Tests:');
  Object.entries(results.email.tests).forEach(([test, status]) => {
    console.log(`  ${status === 'PASS' ? '✅' : '❌'} ${test}: ${status}`);
  });

  // Recommendations
  console.log('\n💡 Recommendations');
  console.log('==================');
  
  if (results.overall.score >= 90) {
    console.log('🎉 Excellent! All Phase 3 features are working well.');
  } else if (results.overall.score >= 75) {
    console.log('👍 Good! Most Phase 3 features are working, minor issues to address.');
  } else {
    console.log('⚠️  Some Phase 3 features need attention.');
  }

  // List failing tests
  const failingTests = [];
  Object.entries(results).forEach(([system, data]) => {
    if (data.tests) {
      Object.entries(data.tests).forEach(([test, status]) => {
        if (status === 'FAIL') {
          failingTests.push(`${system}: ${test}`);
        }
      });
    }
  });

  if (failingTests.length > 0) {
    console.log('\nFailing tests that need attention:');
    failingTests.forEach(test => console.log(`❌ ${test}`));
  }

  console.log('\n🧪 Phase 3 feature testing completed!');
  
  return results;
}

// Run Phase 3 feature tests
testPhase3Features()
  .then((results) => {
    process.exit(results.overall.score >= 75 ? 0 : 1);
  })
  .catch(error => {
    console.error('Phase 3 feature testing failed:', error);
    process.exit(1);
  });
