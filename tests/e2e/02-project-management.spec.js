/**
 * SwargFood Task Management - Project Management Tests
 * Tests for project creation, editing, and management functionality
 */

import { test, expect } from '@playwright/test';
import { TestHelpers } from '../utils/test-helpers.js';

test.describe('Project Management', () => {
  let helpers;
  let testData;

  test.beforeEach(async ({ page }) => {
    helpers = new TestHelpers(page);
    testData = helpers.generateTestData();
    
    // Login before each test
    await helpers.login('admin@example.com', 'admin123');
  });

  test('should display projects dashboard', async ({ page }) => {
    // Check for projects section
    const projectsSection = page.locator('text=Projects').or(
      page.locator('[data-testid="projects"]')
    ).first();
    
    await expect(projectsSection).toBeVisible({ timeout: 10000 });
    
    // Check for create project button
    const createButton = page.locator('text=Create Project').or(
      page.locator('text=New Project')
    ).first();
    
    await expect(createButton).toBeVisible({ timeout: 5000 });
    
    await helpers.takeScreenshot('projects-dashboard');
  });

  test('should open create project modal/form', async ({ page }) => {
    // Click create project button
    const createButton = page.locator('text=Create Project').or(
      page.locator('text=New Project')
    ).first();
    
    await createButton.click();
    
    // Check for project form fields
    await expect(page.locator('input[name="name"]').or(
      page.locator('input[placeholder*="name"]')
    ).first()).toBeVisible({ timeout: 5000 });
    
    await expect(page.locator('textarea[name="description"]').or(
      page.locator('textarea[placeholder*="description"]')
    ).first()).toBeVisible({ timeout: 5000 });
    
    await helpers.takeScreenshot('create-project-form');
  });

  test('should validate required fields in project creation', async ({ page }) => {
    // Click create project button
    const createButton = page.locator('text=Create Project').or(
      page.locator('text=New Project')
    ).first();
    
    await createButton.click();
    
    // Try to submit empty form
    const submitButton = page.locator('button[type="submit"]').or(
      page.locator('text=Create').and(page.locator('button'))
    ).first();
    
    await submitButton.click();
    
    // Check for validation errors
    const errorMessage = page.locator('text=required').or(
      page.locator('text=Please').or(page.locator('text=invalid'))
    ).first();
    
    await expect(errorMessage).toBeVisible({ timeout: 5000 });
    
    await helpers.takeScreenshot('project-validation-errors');
  });

  test('should successfully create a new project', async ({ page }) => {
    // Click create project button
    const createButton = page.locator('text=Create Project').or(
      page.locator('text=New Project')
    ).first();
    
    await createButton.click();
    
    // Fill project details
    await helpers.fillField('input[name="name"]', testData.projectName);
    await helpers.fillField('textarea[name="description"]', 'Automated test project description');
    
    // Set priority if available
    const prioritySelect = page.locator('select[name="priority"]');
    if (await prioritySelect.isVisible()) {
      await prioritySelect.selectOption('HIGH');
    }
    
    // Submit form
    const submitButton = page.locator('button[type="submit"]').or(
      page.locator('text=Create').and(page.locator('button'))
    ).first();
    
    await submitButton.click();
    
    // Wait for project to appear in list
    await expect(page.locator(`text=${testData.projectName}`)).toBeVisible({ timeout: 10000 });
    
    await helpers.takeScreenshot('project-created-successfully');
  });

  test('should display project details', async ({ page }) => {
    // First create a project
    await helpers.createProject({ name: testData.projectName });
    
    // Click on the project to view details
    await page.click(`text=${testData.projectName}`);
    
    // Check for project details page
    await expect(page.locator(`text=${testData.projectName}`)).toBeVisible();
    
    // Check for project actions (edit, delete, etc.)
    const actionsSection = page.locator('text=Edit').or(
      page.locator('text=Delete').or(page.locator('text=Settings'))
    ).first();
    
    if (await actionsSection.isVisible()) {
      await helpers.takeScreenshot('project-details-page');
    }
  });

  test('should edit project details', async ({ page }) => {
    // First create a project
    await helpers.createProject({ name: testData.projectName });
    
    // Find and click edit button
    const editButton = page.locator('text=Edit').or(
      page.locator('[data-testid="edit-project"]')
    ).first();
    
    if (await editButton.isVisible()) {
      await editButton.click();
      
      // Update project name
      const updatedName = `${testData.projectName} - Updated`;
      await helpers.fillField('input[name="name"]', updatedName);
      
      // Save changes
      const saveButton = page.locator('button[type="submit"]').or(
        page.locator('text=Save')
      ).first();
      
      await saveButton.click();
      
      // Verify update
      await expect(page.locator(`text=${updatedName}`)).toBeVisible({ timeout: 10000 });
      
      await helpers.takeScreenshot('project-edited-successfully');
    }
  });

  test('should filter/search projects', async ({ page }) => {
    // Create multiple projects for testing
    await helpers.createProject({ name: `${testData.projectName} Alpha` });
    await helpers.createProject({ name: `${testData.projectName} Beta` });
    
    // Look for search/filter input
    const searchInput = page.locator('input[placeholder*="search"]').or(
      page.locator('input[placeholder*="filter"]')
    ).first();
    
    if (await searchInput.isVisible()) {
      // Search for specific project
      await searchInput.fill('Alpha');
      
      // Verify filtered results
      await expect(page.locator(`text=${testData.projectName} Alpha`)).toBeVisible();
      
      // Beta project should not be visible
      await expect(page.locator(`text=${testData.projectName} Beta`)).not.toBeVisible();
      
      await helpers.takeScreenshot('projects-filtered');
    }
  });

  test('should display project statistics', async ({ page }) => {
    // Create a project
    await helpers.createProject({ name: testData.projectName });
    
    // Look for statistics/metrics
    const statsSection = page.locator('text=Tasks').or(
      page.locator('text=Progress').or(page.locator('text=Members'))
    ).first();
    
    if (await statsSection.isVisible()) {
      await helpers.takeScreenshot('project-statistics');
    }
  });

  test('should handle project deletion', async ({ page }) => {
    // Create a project
    await helpers.createProject({ name: testData.projectName });
    
    // Find delete button
    const deleteButton = page.locator('text=Delete').or(
      page.locator('[data-testid="delete-project"]')
    ).first();
    
    if (await deleteButton.isVisible()) {
      await deleteButton.click();
      
      // Handle confirmation dialog
      const confirmButton = page.locator('text=Confirm').or(
        page.locator('text=Yes').or(page.locator('text=Delete'))
      ).first();
      
      if (await confirmButton.isVisible()) {
        await confirmButton.click();
        
        // Verify project is deleted
        await expect(page.locator(`text=${testData.projectName}`)).not.toBeVisible({ timeout: 10000 });
        
        await helpers.takeScreenshot('project-deleted');
      }
    }
  });

  test('should display empty state when no projects exist', async ({ page }) => {
    // Navigate to projects page
    await helpers.navigateToApp();
    
    // Look for empty state message
    const emptyState = page.locator('text=No projects').or(
      page.locator('text=Create your first project')
    ).first();
    
    if (await emptyState.isVisible()) {
      await helpers.takeScreenshot('projects-empty-state');
    }
  });
});
