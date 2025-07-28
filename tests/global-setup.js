/**
 * SwargFood Task Management - Global Test Setup
 * Prepares the testing environment and creates test data
 */

const { chromium } = require('@playwright/test');

async function globalSetup() {
  console.log('🚀 Starting SwargFood Task Management Test Suite');
  console.log('📋 Setting up global test environment...');

  // Create a browser instance for setup
  const browser = await chromium.launch();
  const context = await browser.newContext();
  const page = await context.newPage();

  try {
    // Test if the application is accessible
    console.log('🌐 Testing application accessibility...');
    await page.goto('https://ai.swargfood.com/task/', { timeout: 30000 });
    
    // Check if the page loads
    await page.waitForLoadState('networkidle', { timeout: 30000 });
    
    // Test API health
    console.log('🔍 Testing API health...');
    const healthResponse = await page.request.get('https://ai.swargfood.com/task/health');
    
    if (healthResponse.ok()) {
      const healthData = await healthResponse.json();
      console.log('✅ API Health Check:', healthData.status);
    } else {
      console.warn('⚠️ API Health Check failed:', healthResponse.status());
    }

    // Test API base endpoint
    const apiResponse = await page.request.get('https://ai.swargfood.com/task/api');
    if (apiResponse.ok()) {
      const apiData = await apiResponse.json();
      console.log('✅ API Base Check:', apiData.message);
    } else {
      console.warn('⚠️ API Base Check failed:', apiResponse.status());
    }

    console.log('✅ Global setup completed successfully');

  } catch (error) {
    console.error('❌ Global setup failed:', error.message);
    throw error;
  } finally {
    await browser.close();
  }
}

module.exports = globalSetup;
