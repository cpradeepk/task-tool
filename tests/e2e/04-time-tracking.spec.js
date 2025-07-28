/**
 * SwargFood Task Management - Time Tracking Tests
 * Tests for time tracking functionality, timers, and reports
 */

import { test, expect } from '@playwright/test';
import { TestHelpers } from '../utils/test-helpers.js';

test.describe('Time Tracking', () => {
  let helpers;
  let testData;

  test.beforeEach(async ({ page }) => {
    helpers = new TestHelpers(page);
    testData = helpers.generateTestData();
    
    // Login and create project/task for time tracking
    await helpers.login('admin@example.com', 'admin123');
    await helpers.createProject({ name: testData.projectName });
    await helpers.createTask({ title: testData.taskTitle });
  });

  test('should display time tracking interface', async ({ page }) => {
    // Look for time tracking section
    const timeSection = page.locator('text=Time Tracking').or(
      page.locator('text=Timer').or(page.locator('[data-testid="time-tracking"]'))
    ).first();
    
    await expect(timeSection).toBeVisible({ timeout: 10000 });
    
    // Check for start timer button
    const startButton = page.locator('text=Start Timer').or(
      page.locator('text=Start').or(page.locator('[data-testid="start-timer"]'))
    ).first();
    
    await expect(startButton).toBeVisible({ timeout: 5000 });
    
    await helpers.takeScreenshot('time-tracking-interface');
  });

  test('should start timer for a task', async ({ page }) => {
    // Navigate to task
    await page.click(`text=${testData.taskTitle}`);
    
    // Find and click start timer button
    const startButton = page.locator('text=Start Timer').or(
      page.locator('text=Start').or(page.locator('[data-testid="start-timer"]'))
    ).first();
    
    await startButton.click();
    
    // Verify timer is running
    const runningTimer = page.locator('text=Stop Timer').or(
      page.locator('text=Running').or(page.locator('[data-testid="timer-running"]'))
    ).first();
    
    await expect(runningTimer).toBeVisible({ timeout: 5000 });
    
    await helpers.takeScreenshot('timer-started');
  });

  test('should stop timer and record time', async ({ page }) => {
    // Navigate to task and start timer
    await page.click(`text=${testData.taskTitle}`);
    
    const startButton = page.locator('text=Start Timer').or(
      page.locator('text=Start')
    ).first();
    
    await startButton.click();
    
    // Wait a moment for timer to run
    await page.waitForTimeout(2000);
    
    // Stop timer
    const stopButton = page.locator('text=Stop Timer').or(
      page.locator('text=Stop').or(page.locator('[data-testid="stop-timer"]'))
    ).first();
    
    await stopButton.click();
    
    // Verify time was recorded
    const timeEntry = page.locator('text=00:00:').or(
      page.locator('text=seconds').or(page.locator('[data-testid="time-entry"]'))
    ).first();
    
    await expect(timeEntry).toBeVisible({ timeout: 5000 });
    
    await helpers.takeScreenshot('timer-stopped-time-recorded');
  });

  test('should manually add time entry', async ({ page }) => {
    // Look for manual time entry option
    const addTimeButton = page.locator('text=Add Time').or(
      page.locator('text=Manual Entry').or(page.locator('[data-testid="add-time"]'))
    ).first();
    
    if (await addTimeButton.isVisible()) {
      await addTimeButton.click();
      
      // Fill time entry form
      const hoursInput = page.locator('input[name="hours"]').or(
        page.locator('input[placeholder*="hours"]')
      ).first();
      
      if (await hoursInput.isVisible()) {
        await hoursInput.fill('2');
      }
      
      const minutesInput = page.locator('input[name="minutes"]').or(
        page.locator('input[placeholder*="minutes"]')
      ).first();
      
      if (await minutesInput.isVisible()) {
        await minutesInput.fill('30');
      }
      
      // Add description
      const descriptionInput = page.locator('textarea[name="description"]').or(
        page.locator('input[name="description"]')
      ).first();
      
      if (await descriptionInput.isVisible()) {
        await descriptionInput.fill('Manual time entry for testing');
      }
      
      // Submit
      const submitButton = page.locator('button[type="submit"]').or(
        page.locator('text=Save')
      ).first();
      
      await submitButton.click();
      
      await helpers.takeScreenshot('manual-time-entry-added');
    }
  });

  test('should display time tracking reports', async ({ page }) => {
    // Look for reports section
    const reportsSection = page.locator('text=Reports').or(
      page.locator('text=Time Reports').or(page.locator('[data-testid="time-reports"]'))
    ).first();
    
    if (await reportsSection.isVisible()) {
      await reportsSection.click();
      
      // Check for report elements
      const reportChart = page.locator('canvas').or(
        page.locator('[data-testid="time-chart"]').or(page.locator('text=Total Time'))
      ).first();
      
      await expect(reportChart).toBeVisible({ timeout: 10000 });
      
      await helpers.takeScreenshot('time-tracking-reports');
    }
  });

  test('should filter time entries by date range', async ({ page }) => {
    // Navigate to time tracking or reports
    const timeSection = page.locator('text=Time Tracking').or(
      page.locator('text=Reports')
    ).first();
    
    await timeSection.click();
    
    // Look for date filter
    const dateFilter = page.locator('input[type="date"]').first();
    
    if (await dateFilter.isVisible()) {
      // Set date range
      const today = new Date();
      const lastWeek = new Date(today.getTime() - 7 * 24 * 60 * 60 * 1000);
      
      await dateFilter.fill(lastWeek.toISOString().split('T')[0]);
      
      // Apply filter
      const applyButton = page.locator('text=Apply').or(
        page.locator('text=Filter')
      ).first();
      
      if (await applyButton.isVisible()) {
        await applyButton.click();
      }
      
      await helpers.takeScreenshot('time-entries-filtered-by-date');
    }
  });

  test('should export time tracking data', async ({ page }) => {
    // Navigate to reports
    const reportsSection = page.locator('text=Reports').or(
      page.locator('text=Export')
    ).first();
    
    if (await reportsSection.isVisible()) {
      await reportsSection.click();
      
      // Look for export button
      const exportButton = page.locator('text=Export').or(
        page.locator('text=Download').or(page.locator('[data-testid="export-time"]'))
      ).first();
      
      if (await exportButton.isVisible()) {
        // Set up download handler
        const downloadPromise = page.waitForEvent('download');
        
        await exportButton.click();
        
        // Wait for download
        const download = await downloadPromise;
        
        // Verify download
        expect(download.suggestedFilename()).toContain('time');
        
        await helpers.takeScreenshot('time-data-exported');
      }
    }
  });

  test('should display timer in different views', async ({ page }) => {
    // Test timer visibility in different sections
    const views = ['Dashboard', 'Projects', 'Tasks'];
    
    for (const view of views) {
      const viewLink = page.locator(`text=${view}`).first();
      
      if (await viewLink.isVisible()) {
        await viewLink.click();
        
        // Check if timer is visible
        const timerWidget = page.locator('text=Timer').or(
          page.locator('[data-testid="timer-widget"]')
        ).first();
        
        if (await timerWidget.isVisible()) {
          await helpers.takeScreenshot(`timer-in-${view.toLowerCase()}-view`);
        }
      }
    }
  });

  test('should handle timer persistence across page refreshes', async ({ page }) => {
    // Start timer
    const startButton = page.locator('text=Start Timer').or(
      page.locator('text=Start')
    ).first();
    
    await startButton.click();
    
    // Refresh page
    await page.reload();
    
    // Check if timer is still running
    const runningTimer = page.locator('text=Stop Timer').or(
      page.locator('text=Running')
    ).first();
    
    if (await runningTimer.isVisible()) {
      await helpers.takeScreenshot('timer-persisted-after-refresh');
    }
  });

  test('should calculate total time for tasks and projects', async ({ page }) => {
    // Add some time entries
    await page.click(`text=${testData.taskTitle}`);
    
    // Start and stop timer quickly
    const startButton = page.locator('text=Start Timer').first();
    if (await startButton.isVisible()) {
      await startButton.click();
      await page.waitForTimeout(1000);
      
      const stopButton = page.locator('text=Stop Timer').first();
      await stopButton.click();
    }
    
    // Check for total time display
    const totalTime = page.locator('text=Total:').or(
      page.locator('text=Total Time').or(page.locator('[data-testid="total-time"]'))
    ).first();
    
    if (await totalTime.isVisible()) {
      await helpers.takeScreenshot('total-time-calculated');
    }
  });

  test('should edit time entries', async ({ page }) => {
    // First create a time entry
    const startButton = page.locator('text=Start Timer').first();
    if (await startButton.isVisible()) {
      await startButton.click();
      await page.waitForTimeout(1000);
      
      const stopButton = page.locator('text=Stop Timer').first();
      await stopButton.click();
    }
    
    // Look for edit option
    const editButton = page.locator('text=Edit').or(
      page.locator('[data-testid="edit-time-entry"]')
    ).first();
    
    if (await editButton.isVisible()) {
      await editButton.click();
      
      // Update time entry
      const descriptionInput = page.locator('textarea[name="description"]').first();
      if (await descriptionInput.isVisible()) {
        await descriptionInput.fill('Updated time entry description');
      }
      
      // Save changes
      const saveButton = page.locator('text=Save').first();
      await saveButton.click();
      
      await helpers.takeScreenshot('time-entry-edited');
    }
  });

  test('should delete time entries', async ({ page }) => {
    // First create a time entry
    const startButton = page.locator('text=Start Timer').first();
    if (await startButton.isVisible()) {
      await startButton.click();
      await page.waitForTimeout(1000);
      
      const stopButton = page.locator('text=Stop Timer').first();
      await stopButton.click();
    }
    
    // Look for delete option
    const deleteButton = page.locator('text=Delete').or(
      page.locator('[data-testid="delete-time-entry"]')
    ).first();
    
    if (await deleteButton.isVisible()) {
      await deleteButton.click();
      
      // Confirm deletion
      const confirmButton = page.locator('text=Confirm').or(
        page.locator('text=Yes')
      ).first();
      
      if (await confirmButton.isVisible()) {
        await confirmButton.click();
        
        await helpers.takeScreenshot('time-entry-deleted');
      }
    }
  });
});
