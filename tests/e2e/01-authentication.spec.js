/**
 * SwargFood Task Management - Authentication Tests
 * Tests for user login, registration, and authentication flows
 */

import { test, expect } from '@playwright/test';
import { TestHelpers } from '../utils/test-helpers.js';

test.describe('Authentication Flow', () => {
  let helpers;

  test.beforeEach(async ({ page }) => {
    helpers = new TestHelpers(page);
  });

  test('should load the application homepage', async ({ page }) => {
    await helpers.navigateToApp();
    
    // Take screenshot of homepage
    await helpers.takeScreenshot('homepage-loaded');
    
    // Check if page title is correct
    await expect(page).toHaveTitle(/SwargFood|Task Management/i);
    
    // Check for key elements
    const loginElement = page.locator('text=Login').or(page.locator('text=Sign In')).first();
    await expect(loginElement).toBeVisible({ timeout: 10000 });
  });

  test('should display login form', async ({ page }) => {
    await helpers.navigateToApp();
    
    // Click login button
    const loginButton = page.locator('text=Login').or(page.locator('text=Sign In')).first();
    await loginButton.click();
    
    // Check for login form elements
    await expect(page.locator('input[type="email"]')).toBeVisible();
    await expect(page.locator('input[type="password"]')).toBeVisible();
    await expect(page.locator('button[type="submit"]')).toBeVisible();
    
    await helpers.takeScreenshot('login-form-displayed');
  });

  test('should show validation errors for empty login form', async ({ page }) => {
    await helpers.navigateToApp();
    
    // Click login button
    const loginButton = page.locator('text=Login').or(page.locator('text=Sign In')).first();
    await loginButton.click();
    
    // Try to submit empty form
    await page.click('button[type="submit"]');
    
    // Check for validation errors
    const errorMessages = page.locator('text=required').or(page.locator('text=invalid'));
    await expect(errorMessages.first()).toBeVisible({ timeout: 5000 });
    
    await helpers.takeScreenshot('login-validation-errors');
  });

  test('should show error for invalid credentials', async ({ page }) => {
    await helpers.navigateToApp();
    
    // Click login button
    const loginButton = page.locator('text=Login').or(page.locator('text=Sign In')).first();
    await loginButton.click();
    
    // Fill invalid credentials
    await helpers.fillField('input[type="email"]', 'invalid@example.com');
    await helpers.fillField('input[type="password"]', 'wrongpassword');
    
    // Submit form
    await helpers.clickElement('button[type="submit"]');
    
    // Check for error message
    const errorMessage = page.locator('text=Invalid').or(page.locator('text=incorrect'));
    await expect(errorMessage.first()).toBeVisible({ timeout: 10000 });
    
    await helpers.takeScreenshot('invalid-credentials-error');
  });

  test('should successfully login with admin credentials', async ({ page }) => {
    await helpers.navigateToApp();
    
    // Click login button
    const loginButton = page.locator('text=Login').or(page.locator('text=Sign In')).first();
    await loginButton.click();
    
    // Fill admin credentials
    await helpers.fillField('input[type="email"]', 'admin@example.com');
    await helpers.fillField('input[type="password"]', 'admin123');
    
    // Submit form
    await helpers.clickElement('button[type="submit"]');
    
    // Wait for successful login (URL change or dashboard elements)
    await page.waitForURL('**/task/**', { timeout: 15000 });
    
    // Check for dashboard elements
    const dashboardElement = page.locator('text=Dashboard').or(
      page.locator('text=Projects')
    ).first();
    await expect(dashboardElement).toBeVisible({ timeout: 10000 });
    
    await helpers.takeScreenshot('successful-login');
  });

  test('should successfully login with demo credentials', async ({ page }) => {
    await helpers.navigateToApp();
    
    // Click login button
    const loginButton = page.locator('text=Login').or(page.locator('text=Sign In')).first();
    await loginButton.click();
    
    // Fill demo credentials
    await helpers.fillField('input[type="email"]', 'demo@example.com');
    await helpers.fillField('input[type="password"]', 'demo123');
    
    // Submit form
    await helpers.clickElement('button[type="submit"]');
    
    // Wait for successful login
    await page.waitForURL('**/task/**', { timeout: 15000 });
    
    await helpers.takeScreenshot('demo-login-success');
  });

  test('should display registration form', async ({ page }) => {
    await helpers.navigateToApp();
    
    // Look for registration link
    const registerLink = page.locator('text=Register').or(
      page.locator('text=Sign Up')
    ).first();
    
    if (await registerLink.isVisible()) {
      await registerLink.click();
      
      // Check for registration form elements
      await expect(page.locator('input[type="email"]')).toBeVisible();
      await expect(page.locator('input[type="password"]')).toBeVisible();
      await expect(page.locator('input[name="name"]')).toBeVisible();
      
      await helpers.takeScreenshot('registration-form');
    } else {
      console.log('Registration form not found - may be disabled');
    }
  });

  test('should logout successfully', async ({ page }) => {
    // First login
    await helpers.login('admin@example.com', 'admin123');
    
    // Find and click logout
    const logoutButton = page.locator('text=Logout').or(
      page.locator('text=Sign Out')
    ).first();
    
    if (await logoutButton.isVisible()) {
      await logoutButton.click();
      
      // Verify logout (should redirect to login page)
      const loginElement = page.locator('text=Login').or(
        page.locator('text=Sign In')
      ).first();
      await expect(loginElement).toBeVisible({ timeout: 10000 });
      
      await helpers.takeScreenshot('successful-logout');
    } else {
      console.log('Logout button not found');
    }
  });

  test('should handle session timeout', async ({ page }) => {
    // Login first
    await helpers.login('admin@example.com', 'admin123');
    
    // Simulate session timeout by clearing storage
    await page.evaluate(() => {
      localStorage.clear();
      sessionStorage.clear();
    });
    
    // Try to access a protected page
    await page.reload();
    
    // Should redirect to login
    const loginElement = page.locator('text=Login').or(
      page.locator('text=Sign In')
    ).first();
    await expect(loginElement).toBeVisible({ timeout: 10000 });
    
    await helpers.takeScreenshot('session-timeout');
  });
});
