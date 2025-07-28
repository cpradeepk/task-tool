const request = require('supertest');
const app = require('../src/app');
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

describe('Enhanced Project Management System', () => {
  let adminToken, projectManagerToken, userToken;
  let testProject, testUser, testModule;

  beforeAll(async () => {
    // Setup test users and tokens
    const adminUser = await prisma.user.create({
      data: {
        email: 'admin@test.com',
        name: 'Admin User',
        role: 'ADMIN',
        isAdmin: true,
        isActive: true
      }
    });

    const projectManagerUser = await prisma.user.create({
      data: {
        email: 'pm@test.com',
        name: 'Project Manager',
        role: 'PROJECT_MANAGER',
        isActive: true
      }
    });

    const regularUser = await prisma.user.create({
      data: {
        email: 'user@test.com',
        name: 'Regular User',
        role: 'MEMBER',
        isActive: true
      }
    });

    // Create test tokens (simplified for testing)
    adminToken = 'test-admin-token';
    projectManagerToken = 'test-pm-token';
    userToken = 'test-user-token';

    // Create test project
    testProject = await prisma.project.create({
      data: {
        name: 'Test Enhanced Project',
        description: 'Test project for enhanced features',
        createdById: adminUser.id,
        priority: 'IMPORTANT_URGENT',
        priorityOrder: 1
      }
    });

    testUser = regularUser;
  });

  afterAll(async () => {
    // Cleanup
    await prisma.assignmentHistory.deleteMany();
    await prisma.priorityChangeLog.deleteMany();
    await prisma.projectTimeline.deleteMany();
    await prisma.enhancedTaskDependency.deleteMany();
    await prisma.enhancedModule.deleteMany();
    await prisma.userProjectAssignment.deleteMany();
    await prisma.task.deleteMany();
    await prisma.project.deleteMany();
    await prisma.user.deleteMany();
    await prisma.$disconnect();
  });

  describe('Project Assignment Management', () => {
    test('should assign users to project', async () => {
      const response = await request(app)
        .post(`/task/api/project-assignments/${testProject.id}/assignments`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          userIds: [testUser.id],
          role: 'MEMBER',
          notes: 'Test assignment'
        });

      expect(response.status).toBe(200);
      expect(response.body.assignments).toHaveLength(1);
      expect(response.body.assignments[0].role).toBe('MEMBER');
    });

    test('should get project assignments', async () => {
      const response = await request(app)
        .get(`/task/api/project-assignments/${testProject.id}/assignments`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
      expect(response.body.length).toBeGreaterThan(0);
    });

    test('should remove user from project', async () => {
      const response = await request(app)
        .delete(`/task/api/project-assignments/${testProject.id}/assignments/${testUser.id}`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          notes: 'Test removal'
        });

      expect(response.status).toBe(200);
      expect(response.body.message).toContain('removed');
    });

    test('should get assignment history', async () => {
      const response = await request(app)
        .get(`/task/api/project-assignments/${testProject.id}/assignment-history`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
    });

    test('should deny access to non-managers', async () => {
      const response = await request(app)
        .post(`/task/api/project-assignments/${testProject.id}/assignments`)
        .set('Authorization', `Bearer ${userToken}`)
        .send({
          userIds: [testUser.id],
          role: 'MEMBER'
        });

      expect(response.status).toBe(403);
    });
  });

  describe('Enhanced Module Management', () => {
    test('should create module', async () => {
      const response = await request(app)
        .post(`/task/api/enhanced-modules/${testProject.id}/modules`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          name: 'Test Module',
          description: 'Test module description',
          priority: 'IMPORTANT_NOT_URGENT',
          priorityNumber: 1,
          estimatedHours: 40
        });

      expect(response.status).toBe(201);
      expect(response.body.name).toBe('Test Module');
      expect(response.body.priority).toBe('IMPORTANT_NOT_URGENT');
      
      testModule = response.body;
    });

    test('should get project modules', async () => {
      const response = await request(app)
        .get(`/task/api/enhanced-modules/${testProject.id}/modules`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
      expect(response.body.length).toBeGreaterThan(0);
      expect(response.body[0]).toHaveProperty('statistics');
    });

    test('should update module', async () => {
      const response = await request(app)
        .put(`/task/api/enhanced-modules/modules/${testModule.id}`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          name: 'Updated Test Module',
          status: 'ACTIVE',
          completionPercentage: 25
        });

      expect(response.status).toBe(200);
      expect(response.body.name).toBe('Updated Test Module');
      expect(response.body.completionPercentage).toBe(25);
    });

    test('should reorder modules', async () => {
      const response = await request(app)
        .put(`/task/api/enhanced-modules/${testProject.id}/modules/reorder`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          moduleOrders: [
            { id: testModule.id, orderIndex: 0 }
          ]
        });

      expect(response.status).toBe(200);
    });

    test('should delete module', async () => {
      const response = await request(app)
        .delete(`/task/api/enhanced-modules/modules/${testModule.id}`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(response.status).toBe(200);
      expect(response.body.message).toContain('deleted');
    });
  });

  describe('Priority Management', () => {
    test('should update priority with approval for regular users', async () => {
      const response = await request(app)
        .put(`/task/api/priority/project/${testProject.id}/priority`)
        .set('Authorization', `Bearer ${userToken}`)
        .send({
          priority: 'NOT_IMPORTANT_URGENT',
          priorityNumber: 2,
          reason: 'Test priority change'
        });

      expect(response.status).toBe(200);
      expect(response.body.needsApproval).toBe(true);
      expect(response.body.priorityChangeLog.status).toBe('PENDING');
    });

    test('should auto-approve priority changes for admins', async () => {
      const response = await request(app)
        .put(`/task/api/priority/project/${testProject.id}/priority`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          priority: 'IMPORTANT_NOT_URGENT',
          priorityNumber: 1,
          reason: 'Admin priority change'
        });

      expect(response.status).toBe(200);
      expect(response.body.needsApproval).toBe(false);
      expect(response.body.priorityChangeLog.status).toBe('APPROVED');
    });

    test('should get priority change requests', async () => {
      const response = await request(app)
        .get('/task/api/priority/change-requests?status=PENDING')
        .set('Authorization', `Bearer ${adminToken}`);

      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
    });

    test('should approve priority change request', async () => {
      // First create a pending request
      const createResponse = await request(app)
        .put(`/task/api/priority/project/${testProject.id}/priority`)
        .set('Authorization', `Bearer ${userToken}`)
        .send({
          priority: 'NOT_IMPORTANT_NOT_URGENT',
          priorityNumber: 3,
          reason: 'Test approval'
        });

      const requestId = createResponse.body.priorityChangeLog.id;

      const response = await request(app)
        .put(`/task/api/priority/change-requests/${requestId}/review`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          action: 'APPROVE',
          notes: 'Approved for testing'
        });

      expect(response.status).toBe(200);
      expect(response.body.request.status).toBe('APPROVED');
    });

    test('should get priority statistics', async () => {
      const response = await request(app)
        .get(`/task/api/priority/projects/${testProject.id}/statistics`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('taskPriorityDistribution');
      expect(response.body).toHaveProperty('modulePriorityDistribution');
      expect(response.body).toHaveProperty('recentPriorityChanges');
    });
  });

  describe('Timeline Management', () => {
    test('should get project timeline', async () => {
      const response = await request(app)
        .get(`/task/api/timeline/${testProject.id}/timeline`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('project');
      expect(response.body).toHaveProperty('modules');
      expect(response.body).toHaveProperty('statistics');
    });

    test('should get project timeline with dependencies', async () => {
      const response = await request(app)
        .get(`/task/api/timeline/${testProject.id}/timeline?includeDependencies=true`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('dependencies');
    });

    test('should create timeline entry', async () => {
      const response = await request(app)
        .post(`/task/api/timeline/${testProject.id}/timeline`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          entityType: 'PROJECT',
          entityId: testProject.id,
          startDate: new Date().toISOString(),
          endDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
          isMilestone: false
        });

      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty('id');
      expect(response.body.entityType).toBe('PROJECT');
    });

    test('should get critical path', async () => {
      const response = await request(app)
        .get(`/task/api/timeline/${testProject.id}/critical-path`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('criticalPath');
      expect(response.body).toHaveProperty('totalDuration');
    });

    test('should get timeline issues', async () => {
      const response = await request(app)
        .get(`/task/api/timeline/${testProject.id}/timeline-issues`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('issues');
      expect(response.body).toHaveProperty('summary');
    });
  });

  describe('Role-Based Access Control', () => {
    test('should allow admin access to all features', async () => {
      const responses = await Promise.all([
        request(app).get(`/task/api/project-assignments/${testProject.id}/assignments`).set('Authorization', `Bearer ${adminToken}`),
        request(app).get(`/task/api/enhanced-modules/${testProject.id}/modules`).set('Authorization', `Bearer ${adminToken}`),
        request(app).get(`/task/api/priority/change-requests`).set('Authorization', `Bearer ${adminToken}`),
        request(app).get(`/task/api/timeline/${testProject.id}/timeline`).set('Authorization', `Bearer ${adminToken}`)
      ]);

      responses.forEach(response => {
        expect(response.status).toBe(200);
      });
    });

    test('should allow project manager access to management features', async () => {
      const responses = await Promise.all([
        request(app).get(`/task/api/enhanced-modules/${testProject.id}/modules`).set('Authorization', `Bearer ${projectManagerToken}`),
        request(app).get(`/task/api/priority/change-requests`).set('Authorization', `Bearer ${projectManagerToken}`)
      ]);

      responses.forEach(response => {
        expect(response.status).toBe(200);
      });
    });

    test('should restrict user access to read-only features', async () => {
      // Users should be able to view but not manage
      const viewResponse = await request(app)
        .get(`/task/api/enhanced-modules/${testProject.id}/modules`)
        .set('Authorization', `Bearer ${userToken}`);
      
      expect(viewResponse.status).toBe(200);

      // But not create modules
      const createResponse = await request(app)
        .post(`/task/api/enhanced-modules/${testProject.id}/modules`)
        .set('Authorization', `Bearer ${userToken}`)
        .send({
          name: 'Unauthorized Module'
        });

      expect(createResponse.status).toBe(403);
    });
  });

  describe('Data Validation and Error Handling', () => {
    test('should validate required fields for module creation', async () => {
      const response = await request(app)
        .post(`/task/api/enhanced-modules/${testProject.id}/modules`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          description: 'Module without name'
        });

      expect(response.status).toBe(400);
    });

    test('should handle non-existent project gracefully', async () => {
      const response = await request(app)
        .get('/task/api/enhanced-modules/non-existent-id/modules')
        .set('Authorization', `Bearer ${adminToken}`);

      expect(response.status).toBe(403); // No access to non-existent project
    });

    test('should validate priority values', async () => {
      const response = await request(app)
        .put(`/task/api/priority/project/${testProject.id}/priority`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          priority: 'INVALID_PRIORITY',
          priorityNumber: 1
        });

      expect(response.status).toBe(400);
    });
  });
});
