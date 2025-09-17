#!/usr/bin/env node

import { knex } from '../src/db/index.js';
import axios from 'axios';

const API_BASE = process.env.API_BASE || 'https://task.amtariksha.com/task/api';
const TEST_TOKEN = process.env.TEST_TOKEN || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOjExLCJlbWFpbCI6InRlc3RAZXhhbXBsZS5jb20iLCJpYXQiOjE3NTgxMTk2NjAsImV4cCI6MTc1ODIwNjA2MH0.LCJ8BZJ-1U2SOf-iYNzJR7fQq3bZDun-ZXD3XOrvABo';

async function performanceTest() {
  console.log('🚀 Starting Performance Tests...\n');

  const results = {
    database: {},
    api: {},
    overall: {}
  };

  // Database Performance Tests
  console.log('📊 Database Performance Tests');
  console.log('================================');

  try {
    // Test database connection speed
    const dbStart = Date.now();
    await knex.raw('SELECT 1');
    const dbTime = Date.now() - dbStart;
    results.database.connection = `${dbTime}ms`;
    console.log(`✅ Database Connection: ${dbTime}ms`);

    // Test complex query performance
    const queryStart = Date.now();
    await knex('tasks')
      .leftJoin('projects', 'tasks.project_id', 'projects.id')
      .leftJoin('users', 'tasks.assigned_to', 'users.id')
      .select('tasks.*', 'projects.name as project_name', 'users.name as user_name')
      .limit(100);
    const queryTime = Date.now() - queryStart;
    results.database.complex_query = `${queryTime}ms`;
    console.log(`✅ Complex Query (100 tasks): ${queryTime}ms`);

    // Test aggregation performance
    const aggStart = Date.now();
    await knex('tasks')
      .select('status')
      .count('* as count')
      .groupBy('status');
    const aggTime = Date.now() - aggStart;
    results.database.aggregation = `${aggTime}ms`;
    console.log(`✅ Aggregation Query: ${aggTime}ms`);

  } catch (error) {
    console.error('❌ Database test error:', error.message);
  }

  // API Performance Tests
  console.log('\n🌐 API Performance Tests');
  console.log('========================');

  const headers = { Authorization: `Bearer ${TEST_TOKEN}` };

  try {
    // Test dashboard API
    const dashStart = Date.now();
    await axios.get(`${API_BASE}/dashboard`, { headers });
    const dashTime = Date.now() - dashStart;
    results.api.dashboard = `${dashTime}ms`;
    console.log(`✅ Dashboard API: ${dashTime}ms`);

    // Test projects API
    const projStart = Date.now();
    await axios.get(`${API_BASE}/projects`, { headers });
    const projTime = Date.now() - projStart;
    results.api.projects = `${projTime}ms`;
    console.log(`✅ Projects API: ${projTime}ms`);

    // Test search API
    const searchStart = Date.now();
    await axios.get(`${API_BASE}/search?q=test`, { headers });
    const searchTime = Date.now() - searchStart;
    results.api.search = `${searchTime}ms`;
    console.log(`✅ Search API: ${searchTime}ms`);

    // Test file upload stats
    const fileStart = Date.now();
    await axios.get(`${API_BASE}/uploads/stats`, { headers });
    const fileTime = Date.now() - fileStart;
    results.api.file_stats = `${fileTime}ms`;
    console.log(`✅ File Stats API: ${fileTime}ms`);

    // Test email templates
    const emailStart = Date.now();
    await axios.get(`${API_BASE}/email/templates`, { headers });
    const emailTime = Date.now() - emailStart;
    results.api.email_templates = `${emailTime}ms`;
    console.log(`✅ Email Templates API: ${emailTime}ms`);

  } catch (error) {
    console.error('❌ API test error:', error.message);
  }

  // Load Testing
  console.log('\n⚡ Load Testing');
  console.log('===============');

  try {
    const concurrentRequests = 10;
    const promises = [];

    const loadStart = Date.now();
    for (let i = 0; i < concurrentRequests; i++) {
      promises.push(axios.get(`${API_BASE}/dashboard`, { headers }));
    }

    await Promise.all(promises);
    const loadTime = Date.now() - loadStart;
    results.overall.concurrent_requests = `${concurrentRequests} requests in ${loadTime}ms`;
    console.log(`✅ ${concurrentRequests} concurrent requests: ${loadTime}ms`);
    console.log(`✅ Average per request: ${Math.round(loadTime / concurrentRequests)}ms`);

  } catch (error) {
    console.error('❌ Load test error:', error.message);
  }

  // Database Statistics
  console.log('\n📈 Database Statistics');
  console.log('======================');

  try {
    const stats = await Promise.all([
      knex('users').count('* as count').first(),
      knex('projects').count('* as count').first(),
      knex('tasks').count('* as count').first(),
      knex('notes').count('* as count').first(),
      knex('chat_messages').count('* as count').first(),
      knex('file_uploads').count('* as count').first(),
      knex('notifications').count('* as count').first(),
      knex('email_logs').count('* as count').first()
    ]);

    console.log(`👥 Users: ${stats[0].count}`);
    console.log(`📁 Projects: ${stats[1].count}`);
    console.log(`✅ Tasks: ${stats[2].count}`);
    console.log(`📝 Notes: ${stats[3].count}`);
    console.log(`💬 Chat Messages: ${stats[4].count}`);
    console.log(`📎 Files: ${stats[5].count}`);
    console.log(`🔔 Notifications: ${stats[6].count}`);
    console.log(`📧 Email Logs: ${stats[7].count}`);

  } catch (error) {
    console.error('❌ Statistics error:', error.message);
  }

  // Performance Summary
  console.log('\n🎯 Performance Summary');
  console.log('======================');
  console.log('Database Performance:');
  Object.entries(results.database).forEach(([key, value]) => {
    console.log(`  ${key}: ${value}`);
  });

  console.log('\nAPI Performance:');
  Object.entries(results.api).forEach(([key, value]) => {
    console.log(`  ${key}: ${value}`);
  });

  console.log('\nOverall Performance:');
  Object.entries(results.overall).forEach(([key, value]) => {
    console.log(`  ${key}: ${value}`);
  });

  // Performance Recommendations
  console.log('\n💡 Performance Recommendations');
  console.log('===============================');

  const dbAvg = Object.values(results.database)
    .map(v => parseInt(v.replace('ms', '')))
    .reduce((a, b) => a + b, 0) / Object.keys(results.database).length;

  const apiAvg = Object.values(results.api)
    .map(v => parseInt(v.replace('ms', '')))
    .reduce((a, b) => a + b, 0) / Object.keys(results.api).length;

  if (dbAvg > 100) {
    console.log('⚠️  Database queries are slow. Consider adding indexes.');
  } else {
    console.log('✅ Database performance is good.');
  }

  if (apiAvg > 500) {
    console.log('⚠️  API responses are slow. Consider caching and optimization.');
  } else {
    console.log('✅ API performance is good.');
  }

  console.log('\n🎉 Performance testing completed!');
}

// Run performance tests
performanceTest()
  .then(() => process.exit(0))
  .catch(error => {
    console.error('Performance test failed:', error);
    process.exit(1);
  });
