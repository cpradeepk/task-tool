/**
 * SwargFood Task Management - API Tests
 * Tests for backend API endpoints and functionality
 */

import { test, expect } from '@playwright/test';

test.describe('API Endpoints', () => {
  const baseURL = 'https://ai.swargfood.com/task';
  let authToken;

  test.beforeAll(async ({ request }) => {
    // Attempt to get auth token (if login endpoint exists)
    try {
      const loginResponse = await request.post(`${baseURL}/api/auth/login`, {
        data: {
          email: 'admin@example.com',
          password: 'admin123'
        }
      });
      
      if (loginResponse.ok()) {
        const loginData = await loginResponse.json();
        authToken = loginData.token || loginData.accessToken;
      }
    } catch (error) {
      console.log('Login endpoint not available or failed:', error.message);
    }
  });

  test('should respond to health check', async ({ request }) => {
    const response = await request.get(`${baseURL}/health`);
    
    expect(response.ok()).toBeTruthy();
    
    const data = await response.json();
    expect(data).toHaveProperty('status');
    expect(data.status).toBe('OK');
    
    console.log('Health check response:', data);
  });

  test('should respond to API base endpoint', async ({ request }) => {
    const response = await request.get(`${baseURL}/api`);
    
    expect(response.ok()).toBeTruthy();
    
    const data = await response.json();
    expect(data).toHaveProperty('message');
    expect(data.message).toContain('SwargFood');
    
    console.log('API base response:', data);
  });

  test('should handle projects endpoint', async ({ request }) => {
    const headers = authToken ? { 'Authorization': `Bearer ${authToken}` } : {};
    
    const response = await request.get(`${baseURL}/api/projects`, { headers });
    
    // Should either return data or require authentication
    if (response.ok()) {
      const data = await response.json();
      expect(Array.isArray(data)).toBeTruthy();
      console.log('Projects endpoint response:', data.length, 'projects');
    } else {
      expect([401, 403]).toContain(response.status());
      console.log('Projects endpoint requires authentication:', response.status());
    }
  });

  test('should handle tasks endpoint', async ({ request }) => {
    const headers = authToken ? { 'Authorization': `Bearer ${authToken}` } : {};
    
    const response = await request.get(`${baseURL}/api/tasks`, { headers });
    
    if (response.ok()) {
      const data = await response.json();
      expect(Array.isArray(data)).toBeTruthy();
      console.log('Tasks endpoint response:', data.length, 'tasks');
    } else {
      expect([401, 403]).toContain(response.status());
      console.log('Tasks endpoint requires authentication:', response.status());
    }
  });

  test('should handle users endpoint', async ({ request }) => {
    const headers = authToken ? { 'Authorization': `Bearer ${authToken}` } : {};
    
    const response = await request.get(`${baseURL}/api/users`, { headers });
    
    if (response.ok()) {
      const data = await response.json();
      expect(Array.isArray(data)).toBeTruthy();
      console.log('Users endpoint response:', data.length, 'users');
    } else {
      expect([401, 403]).toContain(response.status());
      console.log('Users endpoint requires authentication:', response.status());
    }
  });

  test('should handle time tracking endpoint', async ({ request }) => {
    const headers = authToken ? { 'Authorization': `Bearer ${authToken}` } : {};
    
    const response = await request.get(`${baseURL}/api/time-tracking`, { headers });
    
    if (response.ok()) {
      const data = await response.json();
      console.log('Time tracking endpoint accessible');
    } else {
      expect([401, 403, 404]).toContain(response.status());
      console.log('Time tracking endpoint status:', response.status());
    }
  });

  test('should handle task dependencies endpoint', async ({ request }) => {
    const headers = authToken ? { 'Authorization': `Bearer ${authToken}` } : {};
    
    const response = await request.get(`${baseURL}/api/task-dependencies`, { headers });
    
    if (response.ok()) {
      const data = await response.json();
      console.log('Task dependencies endpoint accessible');
    } else {
      expect([401, 403, 404]).toContain(response.status());
      console.log('Task dependencies endpoint status:', response.status());
    }
  });

  test('should handle task templates endpoint', async ({ request }) => {
    const headers = authToken ? { 'Authorization': `Bearer ${authToken}` } : {};
    
    const response = await request.get(`${baseURL}/api/task-templates`, { headers });
    
    if (response.ok()) {
      const data = await response.json();
      console.log('Task templates endpoint accessible');
    } else {
      expect([401, 403, 404]).toContain(response.status());
      console.log('Task templates endpoint status:', response.status());
    }
  });

  test('should handle notifications endpoint', async ({ request }) => {
    const headers = authToken ? { 'Authorization': `Bearer ${authToken}` } : {};
    
    const response = await request.get(`${baseURL}/api/notifications`, { headers });
    
    if (response.ok()) {
      const data = await response.json();
      console.log('Notifications endpoint accessible');
    } else {
      expect([401, 403, 404]).toContain(response.status());
      console.log('Notifications endpoint status:', response.status());
    }
  });

  test('should handle files endpoint', async ({ request }) => {
    const headers = authToken ? { 'Authorization': `Bearer ${authToken}` } : {};
    
    const response = await request.get(`${baseURL}/api/files`, { headers });
    
    if (response.ok()) {
      const data = await response.json();
      console.log('Files endpoint accessible');
    } else {
      expect([401, 403, 404]).toContain(response.status());
      console.log('Files endpoint status:', response.status());
    }
  });

  test('should handle chat endpoint', async ({ request }) => {
    const headers = authToken ? { 'Authorization': `Bearer ${authToken}` } : {};
    
    const response = await request.get(`${baseURL}/api/chat`, { headers });
    
    if (response.ok()) {
      const data = await response.json();
      console.log('Chat endpoint accessible');
    } else {
      expect([401, 403, 404]).toContain(response.status());
      console.log('Chat endpoint status:', response.status());
    }
  });

  test('should handle activity endpoint', async ({ request }) => {
    const headers = authToken ? { 'Authorization': `Bearer ${authToken}` } : {};
    
    const response = await request.get(`${baseURL}/api/activity`, { headers });
    
    if (response.ok()) {
      const data = await response.json();
      console.log('Activity endpoint accessible');
    } else {
      expect([401, 403, 404]).toContain(response.status());
      console.log('Activity endpoint status:', response.status());
    }
  });

  test('should return 404 for non-existent endpoints', async ({ request }) => {
    const response = await request.get(`${baseURL}/api/non-existent-endpoint`);
    
    expect(response.status()).toBe(404);
    
    const data = await response.json();
    expect(data).toHaveProperty('error');
    expect(data.error).toContain('not found');
  });

  test('should handle CORS properly', async ({ request }) => {
    const response = await request.options(`${baseURL}/api`, {
      headers: {
        'Origin': 'https://ai.swargfood.com',
        'Access-Control-Request-Method': 'GET',
        'Access-Control-Request-Headers': 'Content-Type'
      }
    });
    
    // Should either handle CORS or return method not allowed
    expect([200, 204, 405]).toContain(response.status());
  });

  test('should validate request content types', async ({ request }) => {
    const headers = authToken ? { 'Authorization': `Bearer ${authToken}` } : {};
    
    // Test with invalid content type
    const response = await request.post(`${baseURL}/api/projects`, {
      headers: {
        ...headers,
        'Content-Type': 'text/plain'
      },
      data: 'invalid data'
    });
    
    // Should return 400 or 415 for invalid content type
    expect([400, 401, 403, 415]).toContain(response.status());
  });

  test('should handle rate limiting', async ({ request }) => {
    const headers = authToken ? { 'Authorization': `Bearer ${authToken}` } : {};
    
    // Make multiple rapid requests
    const promises = Array(10).fill().map(() => 
      request.get(`${baseURL}/api`, { headers })
    );
    
    const responses = await Promise.all(promises);
    
    // Check if any requests were rate limited
    const rateLimited = responses.some(response => response.status() === 429);
    
    if (rateLimited) {
      console.log('Rate limiting is active');
    } else {
      console.log('No rate limiting detected');
    }
  });

  test('should handle large request payloads', async ({ request }) => {
    const headers = authToken ? { 
      'Authorization': `Bearer ${authToken}`,
      'Content-Type': 'application/json'
    } : {
      'Content-Type': 'application/json'
    };
    
    // Create large payload
    const largeData = {
      name: 'A'.repeat(10000),
      description: 'B'.repeat(50000)
    };
    
    const response = await request.post(`${baseURL}/api/projects`, {
      headers,
      data: largeData
    });
    
    // Should handle large payloads appropriately
    expect([400, 401, 403, 413]).toContain(response.status());
  });
});
