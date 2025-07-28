/**
 * SwargFood Task Management - Test Utilities
 * Common helper functions for testing
 */

import { expect } from '@playwright/test';

export class TestHelpers {
  constructor(page) {
    this.page = page;
  }

  /**
   * Navigate to the application and wait for it to load
   */
  async navigateToApp() {
    await this.page.goto('/task/');
    await this.page.waitForLoadState('networkidle');
    
    // Wait for Flutter app to initialize
    await this.page.waitForFunction(() => {
      return window.flutter && window.flutter.loader;
    }, { timeout: 30000 });
  }

  /**
   * Take a screenshot with timestamp
   */
  async takeScreenshot(name) {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    await this.page.screenshot({ 
      path: `test-results/screenshots/${name}-${timestamp}.png`,
      fullPage: true 
    });
  }

  /**
   * Wait for element to be visible with custom timeout
   */
  async waitForElement(selector, timeout = 10000) {
    await this.page.waitForSelector(selector, { 
      state: 'visible', 
      timeout 
    });
  }

  /**
   * Fill form field with validation
   */
  async fillField(selector, value, options = {}) {
    await this.waitForElement(selector);
    await this.page.fill(selector, value);
    
    if (options.validate) {
      const fieldValue = await this.page.inputValue(selector);
      expect(fieldValue).toBe(value);
    }
  }

  /**
   * Click element with retry logic
   */
  async clickElement(selector, options = {}) {
    await this.waitForElement(selector);
    
    const maxRetries = options.retries || 3;
    let attempt = 0;
    
    while (attempt < maxRetries) {
      try {
        await this.page.click(selector, { timeout: 5000 });
        break;
      } catch (error) {
        attempt++;
        if (attempt === maxRetries) throw error;
        await this.page.waitForTimeout(1000);
      }
    }
  }

  /**
   * Wait for API response
   */
  async waitForApiResponse(urlPattern, timeout = 10000) {
    return await this.page.waitForResponse(
      response => response.url().includes(urlPattern) && response.status() === 200,
      { timeout }
    );
  }

  /**
   * Check for console errors
   */
  async checkConsoleErrors() {
    const errors = [];
    
    this.page.on('console', msg => {
      if (msg.type() === 'error') {
        errors.push(msg.text());
      }
    });
    
    return errors;
  }

  /**
   * Generate random test data
   */
  generateTestData() {
    const timestamp = Date.now();
    return {
      email: `test-${timestamp}@example.com`,
      name: `Test User ${timestamp}`,
      projectName: `Test Project ${timestamp}`,
      taskTitle: `Test Task ${timestamp}`,
      password: 'TestPassword123!'
    };
  }

  /**
   * Login with credentials
   */
  async login(email = 'admin@example.com', password = 'admin123') {
    await this.navigateToApp();
    
    // Look for login form or button
    const loginButton = this.page.locator('text=Login').or(
      this.page.locator('text=Sign In')
    ).first();
    
    if (await loginButton.isVisible()) {
      await loginButton.click();
    }
    
    // Fill login form
    await this.fillField('input[type="email"]', email);
    await this.fillField('input[type="password"]', password);
    
    // Submit form
    await this.clickElement('button[type="submit"]');
    
    // Wait for successful login
    await this.page.waitForURL('**/task/**', { timeout: 10000 });
  }

  /**
   * Logout from application
   */
  async logout() {
    const logoutButton = this.page.locator('text=Logout').or(
      this.page.locator('text=Sign Out')
    ).first();
    
    if (await logoutButton.isVisible()) {
      await logoutButton.click();
    }
  }

  /**
   * Create a test project
   */
  async createProject(projectData) {
    const createButton = this.page.locator('text=Create Project').or(
      this.page.locator('text=New Project')
    ).first();
    
    await createButton.click();
    
    await this.fillField('input[name="name"]', projectData.name);
    await this.fillField('textarea[name="description"]', projectData.description || 'Test project description');
    
    await this.clickElement('button[type="submit"]');
    
    // Wait for project to be created
    await this.waitForElement(`text=${projectData.name}`);
  }

  /**
   * Create a test task
   */
  async createTask(taskData) {
    const createButton = this.page.locator('text=Create Task').or(
      this.page.locator('text=New Task')
    ).first();
    
    await createButton.click();
    
    await this.fillField('input[name="title"]', taskData.title);
    await this.fillField('textarea[name="description"]', taskData.description || 'Test task description');
    
    await this.clickElement('button[type="submit"]');
    
    // Wait for task to be created
    await this.waitForElement(`text=${taskData.title}`);
  }
}
