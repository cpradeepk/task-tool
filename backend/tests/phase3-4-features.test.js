/**
 * Comprehensive Test Suite for Phase 3 & 4 Features
 * Margadarshi Task Management System
 */

import { describe, it, expect, beforeAll, afterAll, beforeEach } from '@jest/globals';
import request from 'supertest';
import { knex } from '../src/db/index.js';
import app from '../src/server.js';

// Test data
let testUser, testAdmin, testTask, testProject, testModule;
let userToken, adminToken;

describe('Phase 3 & 4 Features Integration Tests', () => {
  
  beforeAll(async () => {
    // Setup test database
    await knex.migrate.latest();
    
    // Create test users
    testUser = await knex('users').insert({
      email: 'testuser@example.com',
      name: 'Test User',
      password: 'hashedpassword',
      status: 'active'
    }).returning('*');
    
    testAdmin = await knex('users').insert({
      email: 'admin@example.com',
      name: 'Test Admin',
      password: 'hashedpassword',
      status: 'active'
    }).returning('*');
    
    // Create test project and module
    testProject = await knex('projects').insert({
      name: 'Test Project',
      description: 'Test project for Phase 3 & 4 features',
      created_by: testUser[0].id
    }).returning('*');
    
    testModule = await knex('modules').insert({
      name: 'Test Module',
      description: 'Test module',
      project_id: testProject[0].id
    }).returning('*');
    
    // Create test task
    testTask = await knex('tasks').insert({
      title: 'Test Task',
      description: 'Test task for Phase 3 & 4 features',
      module_id: testModule[0].id,
      assigned_to: testUser[0].id,
      status: 'Yet to Start',
      priority: 'Medium'
    }).returning('*');
    
    // Mock JWT tokens (you'll need to implement proper token generation)
    userToken = 'mock-user-token';
    adminToken = 'mock-admin-token';
  });
  
  afterAll(async () => {
    // Cleanup test data
    await knex('task_comments').del();
    await knex('task_history').del();
    await knex('task_support').del();
    await knex('user_warnings').del();
    await knex('task_templates').del();
    await knex('leaves').del();
    await knex('wfh_requests').del();
    await knex('tasks').del();
    await knex('modules').del();
    await knex('projects').del();
    await knex('users').del();
    
    await knex.destroy();
  });

  describe('Task Support Team Features', () => {
    
    it('should add support team members to a task', async () => {
      const response = await request(app)
        .put(`/task/api/projects/${testProject[0].id}/tasks/${testTask[0].id}/support`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          support_team: [testAdmin[0].id],
          action: 'add'
        });
      
      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      
      // Verify support team was added
      const supportMembers = await knex('task_support')
        .where('task_id', testTask[0].id)
        .where('is_active', true);
      
      expect(supportMembers).toHaveLength(1);
      expect(supportMembers[0].employee_id).toBe(testAdmin[0].id.toString());
    });
    
    it('should get tasks where user is support team member', async () => {
      const response = await request(app)
        .get(`/task/api/tasks/support/${testAdmin[0].id}`)
        .set('Authorization', `Bearer ${adminToken}`);
      
      expect(response.status).toBe(200);
      expect(response.body).toHaveLength(1);
      expect(response.body[0].id).toBe(testTask[0].id);
    });
    
    it('should remove support team members from a task', async () => {
      const response = await request(app)
        .put(`/task/api/projects/${testProject[0].id}/tasks/${testTask[0].id}/support`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          support_team: [testAdmin[0].id],
          action: 'remove'
        });
      
      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      
      // Verify support team was removed
      const supportMembers = await knex('task_support')
        .where('task_id', testTask[0].id)
        .where('is_active', true);
      
      expect(supportMembers).toHaveLength(0);
    });
  });

  describe('Task Comments System', () => {
    
    it('should add a comment to a task', async () => {
      const response = await request(app)
        .post(`/task/api/tasks/${testTask[0].id}/comments`)
        .set('Authorization', `Bearer ${userToken}`)
        .send({
          content: 'This is a test comment',
          is_internal: false
        });
      
      expect(response.status).toBe(201);
      expect(response.body.content).toBe('This is a test comment');
      expect(response.body.author_id).toBe(testUser[0].id.toString());
    });
    
    it('should get comments for a task', async () => {
      const response = await request(app)
        .get(`/task/api/tasks/${testTask[0].id}/comments`)
        .set('Authorization', `Bearer ${userToken}`);
      
      expect(response.status).toBe(200);
      expect(response.body).toHaveLength(1);
      expect(response.body[0].content).toBe('This is a test comment');
    });
    
    it('should get task history', async () => {
      const response = await request(app)
        .get(`/task/api/tasks/${testTask[0].id}/history`)
        .set('Authorization', `Bearer ${userToken}`);
      
      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
    });
  });

  describe('Task Templates System', () => {
    
    it('should create a task template', async () => {
      const response = await request(app)
        .post('/task/api/task-templates')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          name: 'Test Template',
          description: 'A test template',
          template_data: {
            title: 'Template Task',
            description: 'Template description',
            priority: 'High'
          },
          category: 'Testing',
          is_public: true
        });
      
      expect(response.status).toBe(201);
      expect(response.body.name).toBe('Test Template');
      expect(response.body.is_public).toBe(true);
    });
    
    it('should get all task templates', async () => {
      const response = await request(app)
        .get('/task/api/task-templates')
        .set('Authorization', `Bearer ${userToken}`);
      
      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
      expect(response.body.length).toBeGreaterThan(0);
    });
    
    it('should create task from template', async () => {
      // First get a template
      const templatesResponse = await request(app)
        .get('/task/api/task-templates')
        .set('Authorization', `Bearer ${userToken}`);
      
      const template = templatesResponse.body[0];
      
      const response = await request(app)
        .post(`/task/api/task-templates/${template.id}/create-task`)
        .set('Authorization', `Bearer ${userToken}`)
        .send({
          project_id: testProject[0].id,
          module_id: testModule[0].id,
          customizations: {
            title: 'Task from Template'
          }
        });
      
      expect(response.status).toBe(201);
      expect(response.body.title).toBe('Task from Template');
      expect(response.body.task_id_formatted).toMatch(/^JSR-\d{8}-\d{3}$/);
    });
  });

  describe('Leave Management System', () => {
    
    it('should apply for leave', async () => {
      const startDate = new Date();
      startDate.setDate(startDate.getDate() + 7);
      const endDate = new Date();
      endDate.setDate(endDate.getDate() + 9);
      
      const response = await request(app)
        .post('/task/api/leaves')
        .set('Authorization', `Bearer ${userToken}`)
        .send({
          leave_type: 'Annual Leave',
          start_date: startDate.toISOString().split('T')[0],
          end_date: endDate.toISOString().split('T')[0],
          reason: 'Family vacation'
        });
      
      expect(response.status).toBe(201);
      expect(response.body.leave_type).toBe('Annual Leave');
      expect(response.body.status).toBe('pending');
    });
    
    it('should get user leaves', async () => {
      const response = await request(app)
        .get('/task/api/leaves')
        .set('Authorization', `Bearer ${userToken}`);
      
      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
      expect(response.body.length).toBeGreaterThan(0);
    });
    
    it('should approve leave request', async () => {
      // Get the leave request
      const leavesResponse = await request(app)
        .get('/task/api/leaves')
        .set('Authorization', `Bearer ${userToken}`);
      
      const leave = leavesResponse.body[0];
      
      const response = await request(app)
        .put(`/task/api/leaves/${leave.id}/approve`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          comments: 'Approved for family vacation'
        });
      
      expect(response.status).toBe(200);
      expect(response.body.status).toBe('approved');
    });
    
    it('should get leave statistics', async () => {
      const response = await request(app)
        .get('/task/api/leaves/stats/summary')
        .set('Authorization', `Bearer ${userToken}`);
      
      expect(response.status).toBe(200);
      expect(response.body.total_requests).toBeGreaterThan(0);
      expect(response.body.approved_requests).toBeGreaterThan(0);
    });
  });

  describe('WFH Management System', () => {
    
    it('should apply for WFH', async () => {
      const wfhDate = new Date();
      wfhDate.setDate(wfhDate.getDate() + 3);
      
      const response = await request(app)
        .post('/task/api/wfh')
        .set('Authorization', `Bearer ${userToken}`)
        .send({
          date: wfhDate.toISOString().split('T')[0],
          reason: 'Home internet maintenance'
        });
      
      expect(response.status).toBe(201);
      expect(response.body.status).toBe('pending');
    });
    
    it('should get WFH requests', async () => {
      const response = await request(app)
        .get('/task/api/wfh')
        .set('Authorization', `Bearer ${userToken}`);
      
      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
      expect(response.body.length).toBeGreaterThan(0);
    });
    
    it('should approve WFH request', async () => {
      // Get the WFH request
      const wfhResponse = await request(app)
        .get('/task/api/wfh')
        .set('Authorization', `Bearer ${userToken}`);
      
      const wfhRequest = wfhResponse.body[0];
      
      const response = await request(app)
        .put(`/task/api/wfh/${wfhRequest.id}/approve`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          comments: 'Approved for maintenance'
        });
      
      expect(response.status).toBe(200);
      expect(response.body.status).toBe('approved');
    });
  });

  describe('Enhanced User Management', () => {
    
    it('should add warning to user', async () => {
      const response = await request(app)
        .put(`/task/api/enhanced-users/${testUser[0].id}/warning`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          warning_type: 'overdue_tasks',
          description: 'Multiple overdue tasks'
        });
      
      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.user.warning_count).toBe(1);
    });
    
    it('should get user warnings', async () => {
      const response = await request(app)
        .get(`/task/api/enhanced-users/${testUser[0].id}/warnings`)
        .set('Authorization', `Bearer ${adminToken}`);
      
      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
      expect(response.body.length).toBeGreaterThan(0);
    });
    
    it('should generate employee ID card', async () => {
      const response = await request(app)
        .get(`/task/api/enhanced-users/${testUser[0].id}/id-card`)
        .set('Authorization', `Bearer ${userToken}`);
      
      expect(response.status).toBe(200);
      expect(response.body.employee_id).toBe(testUser[0].id);
      expect(response.body.name).toBe(testUser[0].name);
      expect(response.body.email).toBe(testUser[0].email);
    });
    
    it('should get user statistics', async () => {
      const response = await request(app)
        .get(`/task/api/enhanced-users/${testUser[0].id}/stats`)
        .set('Authorization', `Bearer ${userToken}`);
      
      expect(response.status).toBe(200);
      expect(response.body.tasks).toBeDefined();
      expect(response.body.leaves).toBeDefined();
      expect(response.body.wfh).toBeDefined();
      expect(response.body.warnings).toBeDefined();
    });
  });

  describe('Dashboard Enhancements', () => {
    
    it('should get role-based dashboard stats', async () => {
      const response = await request(app)
        .get('/task/api/dashboard/stats/employee')
        .set('Authorization', `Bearer ${userToken}`);
      
      expect(response.status).toBe(200);
      expect(response.body.total_tasks).toBeDefined();
      expect(response.body.completion_rate).toBeDefined();
    });
    
    it('should get overdue tasks', async () => {
      const response = await request(app)
        .get('/task/api/dashboard/overdue-tasks')
        .set('Authorization', `Bearer ${userToken}`);
      
      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
    });
    
    it('should get this week tasks', async () => {
      const response = await request(app)
        .get('/task/api/dashboard/this-week')
        .set('Authorization', `Bearer ${userToken}`);
      
      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
    });
    
    it('should get task warnings', async () => {
      const response = await request(app)
        .get('/task/api/dashboard/warnings')
        .set('Authorization', `Bearer ${userToken}`);
      
      expect(response.status).toBe(200);
      expect(response.body.warning_level).toBeDefined();
      expect(response.body.has_warnings).toBeDefined();
    });
  });
});

// Performance tests
describe('Performance Tests', () => {
  
  it('should handle bulk task operations efficiently', async () => {
    const startTime = Date.now();
    
    // Create multiple tasks
    const taskPromises = [];
    for (let i = 0; i < 10; i++) {
      taskPromises.push(
        knex('tasks').insert({
          title: `Bulk Task ${i}`,
          description: `Bulk task ${i} for performance testing`,
          module_id: testModule[0].id,
          assigned_to: testUser[0].id,
          status: 'Yet to Start',
          priority: 'Medium'
        })
      );
    }
    
    await Promise.all(taskPromises);
    
    const endTime = Date.now();
    const duration = endTime - startTime;
    
    expect(duration).toBeLessThan(5000); // Should complete within 5 seconds
  });
  
  it('should handle concurrent leave applications', async () => {
    const startTime = Date.now();
    
    const leavePromises = [];
    for (let i = 0; i < 5; i++) {
      const startDate = new Date();
      startDate.setDate(startDate.getDate() + 10 + i);
      const endDate = new Date();
      endDate.setDate(endDate.getDate() + 12 + i);
      
      leavePromises.push(
        request(app)
          .post('/task/api/leaves')
          .set('Authorization', `Bearer ${userToken}`)
          .send({
            leave_type: 'Annual Leave',
            start_date: startDate.toISOString().split('T')[0],
            end_date: endDate.toISOString().split('T')[0],
            reason: `Concurrent test leave ${i}`
          })
      );
    }
    
    const responses = await Promise.all(leavePromises);
    const endTime = Date.now();
    const duration = endTime - startTime;
    
    responses.forEach(response => {
      expect(response.status).toBe(201);
    });
    
    expect(duration).toBeLessThan(3000); // Should complete within 3 seconds
  });
});

export default describe;
