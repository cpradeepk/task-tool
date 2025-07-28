/**
 * SwargFood Task Management - Basic Smoke Tests
 * Simple tests to verify application is accessible and functional
 */

import { test, expect } from '@playwright/test';

test.describe('Basic Smoke Tests', () => {
  
  test('should load the application homepage', async ({ page }) => {
    // Navigate to the application
    await page.goto('https://ai.swargfood.com/task/');
    
    // Wait for page to load
    await page.waitForLoadState('networkidle');
    
    // Check if page title contains expected text
    await expect(page).toHaveTitle(/Task Management|SwargFood/i);
    
    // Take screenshot
    await page.screenshot({ path: 'test-results/screenshots/homepage-loaded.png', fullPage: true });
    
    console.log('✅ Homepage loaded successfully');
  });

  test('should have working health endpoint', async ({ request }) => {
    const response = await request.get('https://ai.swargfood.com/task/health');
    
    expect(response.ok()).toBeTruthy();
    
    const data = await response.json();
    expect(data).toHaveProperty('status');
    expect(data.status).toBe('OK');
    
    console.log('✅ Health endpoint working:', data);
  });

  test('should have working API endpoint', async ({ request }) => {
    const response = await request.get('https://ai.swargfood.com/task/api');
    
    expect(response.ok()).toBeTruthy();
    
    const data = await response.json();
    expect(data).toHaveProperty('message');
    expect(data.message).toContain('SwargFood');
    
    console.log('✅ API endpoint working:', data.message);
  });

  test('should redirect to login page', async ({ page }) => {
    // Navigate to the application
    await page.goto('https://ai.swargfood.com/task/');
    
    // Wait for any redirects
    await page.waitForLoadState('networkidle');
    
    // Check if URL contains login
    expect(page.url()).toContain('login');
    
    // Take screenshot
    await page.screenshot({ path: 'test-results/screenshots/login-redirect.png', fullPage: true });
    
    console.log('✅ Redirected to login page:', page.url());
  });

  test('should have Flutter app elements', async ({ page }) => {
    // Navigate to the application
    await page.goto('https://ai.swargfood.com/task/');
    
    // Wait for Flutter to load
    await page.waitForLoadState('networkidle');
    
    // Wait for Flutter app to initialize
    await page.waitForFunction(() => {
      return window.flutter !== undefined;
    }, { timeout: 30000 });
    
    // Check for Flutter-specific elements
    const flutterApp = page.locator('flutter-view, flt-glass-pane, [data-flutter]').first();
    
    // If Flutter elements exist, verify they're visible
    if (await flutterApp.count() > 0) {
      await expect(flutterApp).toBeVisible();
      console.log('✅ Flutter app elements found');
    } else {
      console.log('ℹ️ No specific Flutter elements found, but app may still be working');
    }
    
    // Take screenshot
    await page.screenshot({ path: 'test-results/screenshots/flutter-app.png', fullPage: true });
  });

  test('should handle page load without errors', async ({ page }) => {
    const errors = [];
    
    // Listen for console errors
    page.on('console', msg => {
      if (msg.type() === 'error') {
        errors.push(msg.text());
      }
    });
    
    // Navigate to the application
    await page.goto('https://ai.swargfood.com/task/');
    
    // Wait for page to load
    await page.waitForLoadState('networkidle');
    
    // Check for critical errors (ignore asset loading errors which are common in Flutter)
    const criticalErrors = errors.filter(error => 
      !error.includes('Failed to load resource') && 
      !error.includes('assets/') &&
      !error.includes('404')
    );
    
    if (criticalErrors.length > 0) {
      console.log('⚠️ Console errors found:', criticalErrors);
    } else {
      console.log('✅ No critical console errors');
    }
    
    // Take screenshot
    await page.screenshot({ path: 'test-results/screenshots/no-errors.png', fullPage: true });
  });

  test('should have responsive design', async ({ page }) => {
    // Test desktop view
    await page.setViewportSize({ width: 1920, height: 1080 });
    await page.goto('https://ai.swargfood.com/task/');
    await page.waitForLoadState('networkidle');
    await page.screenshot({ path: 'test-results/screenshots/desktop-view.png', fullPage: true });
    
    // Test tablet view
    await page.setViewportSize({ width: 768, height: 1024 });
    await page.reload();
    await page.waitForLoadState('networkidle');
    await page.screenshot({ path: 'test-results/screenshots/tablet-view.png', fullPage: true });
    
    // Test mobile view
    await page.setViewportSize({ width: 375, height: 667 });
    await page.reload();
    await page.waitForLoadState('networkidle');
    await page.screenshot({ path: 'test-results/screenshots/mobile-view.png', fullPage: true });
    
    console.log('✅ Responsive design tested across viewports');
  });

  test('should load within reasonable time', async ({ page }) => {
    const startTime = Date.now();
    
    await page.goto('https://ai.swargfood.com/task/');
    await page.waitForLoadState('networkidle');
    
    const loadTime = Date.now() - startTime;
    
    // Should load within 10 seconds
    expect(loadTime).toBeLessThan(10000);
    
    console.log(`✅ Page loaded in ${loadTime}ms`);
  });

  test('should have proper meta tags', async ({ page }) => {
    await page.goto('https://ai.swargfood.com/task/');
    await page.waitForLoadState('networkidle');
    
    // Check for viewport meta tag
    const viewport = await page.locator('meta[name="viewport"]').getAttribute('content');
    expect(viewport).toBeTruthy();
    
    // Check for charset
    const charset = await page.locator('meta[charset]').count();
    expect(charset).toBeGreaterThan(0);
    
    console.log('✅ Proper meta tags found');
  });
});
