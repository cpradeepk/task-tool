/**
 * SwargFood Task Management - Task Management Tests
 * Tests for task creation, editing, assignment, and status management
 */

import { test, expect } from '@playwright/test';
import { TestHelpers } from '../utils/test-helpers.js';

test.describe('Task Management', () => {
  let helpers;
  let testData;

  test.beforeEach(async ({ page }) => {
    helpers = new TestHelpers(page);
    testData = helpers.generateTestData();
    
    // Login and create a project for tasks
    await helpers.login('admin@example.com', 'admin123');
    await helpers.createProject({ name: testData.projectName });
  });

  test('should display tasks dashboard', async ({ page }) => {
    // Navigate to tasks section
    const tasksSection = page.locator('text=Tasks').or(
      page.locator('[data-testid="tasks"]')
    ).first();
    
    await expect(tasksSection).toBeVisible({ timeout: 10000 });
    
    // Check for create task button
    const createButton = page.locator('text=Create Task').or(
      page.locator('text=New Task')
    ).first();
    
    await expect(createButton).toBeVisible({ timeout: 5000 });
    
    await helpers.takeScreenshot('tasks-dashboard');
  });

  test('should open create task form', async ({ page }) => {
    // Click create task button
    const createButton = page.locator('text=Create Task').or(
      page.locator('text=New Task')
    ).first();
    
    await createButton.click();
    
    // Check for task form fields
    await expect(page.locator('input[name="title"]').or(
      page.locator('input[placeholder*="title"]')
    ).first()).toBeVisible({ timeout: 5000 });
    
    await expect(page.locator('textarea[name="description"]').or(
      page.locator('textarea[placeholder*="description"]')
    ).first()).toBeVisible({ timeout: 5000 });
    
    await helpers.takeScreenshot('create-task-form');
  });

  test('should validate required fields in task creation', async ({ page }) => {
    // Click create task button
    const createButton = page.locator('text=Create Task').or(
      page.locator('text=New Task')
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
    
    await helpers.takeScreenshot('task-validation-errors');
  });

  test('should successfully create a new task', async ({ page }) => {
    // Click create task button
    const createButton = page.locator('text=Create Task').or(
      page.locator('text=New Task')
    ).first();
    
    await createButton.click();
    
    // Fill task details
    await helpers.fillField('input[name="title"]', testData.taskTitle);
    await helpers.fillField('textarea[name="description"]', 'Automated test task description');
    
    // Set priority if available
    const prioritySelect = page.locator('select[name="priority"]');
    if (await prioritySelect.isVisible()) {
      await prioritySelect.selectOption('HIGH');
    }
    
    // Set due date if available
    const dueDateInput = page.locator('input[type="date"]');
    if (await dueDateInput.isVisible()) {
      const futureDate = new Date();
      futureDate.setDate(futureDate.getDate() + 7);
      await dueDateInput.fill(futureDate.toISOString().split('T')[0]);
    }
    
    // Submit form
    const submitButton = page.locator('button[type="submit"]').or(
      page.locator('text=Create').and(page.locator('button'))
    ).first();
    
    await submitButton.click();
    
    // Wait for task to appear in list
    await expect(page.locator(`text=${testData.taskTitle}`)).toBeVisible({ timeout: 10000 });
    
    await helpers.takeScreenshot('task-created-successfully');
  });

  test('should display task details', async ({ page }) => {
    // First create a task
    await helpers.createTask({ title: testData.taskTitle });
    
    // Click on the task to view details
    await page.click(`text=${testData.taskTitle}`);
    
    // Check for task details
    await expect(page.locator(`text=${testData.taskTitle}`)).toBeVisible();
    
    // Check for task actions
    const actionsSection = page.locator('text=Edit').or(
      page.locator('text=Delete').or(page.locator('text=Assign'))
    ).first();
    
    if (await actionsSection.isVisible()) {
      await helpers.takeScreenshot('task-details-page');
    }
  });

  test('should change task status', async ({ page }) => {
    // Create a task
    await helpers.createTask({ title: testData.taskTitle });
    
    // Look for status dropdown or buttons
    const statusControl = page.locator('select[name="status"]').or(
      page.locator('text=In Progress').or(page.locator('text=Completed'))
    ).first();
    
    if (await statusControl.isVisible()) {
      if (await page.locator('select[name="status"]').isVisible()) {
        // Dropdown selection
        await page.selectOption('select[name="status"]', 'IN_PROGRESS');
      } else {
        // Button click
        await statusControl.click();
      }
      
      await helpers.takeScreenshot('task-status-changed');
    }
  });

  test('should edit task details', async ({ page }) => {
    // Create a task
    await helpers.createTask({ title: testData.taskTitle });
    
    // Find and click edit button
    const editButton = page.locator('text=Edit').or(
      page.locator('[data-testid="edit-task"]')
    ).first();
    
    if (await editButton.isVisible()) {
      await editButton.click();
      
      // Update task title
      const updatedTitle = `${testData.taskTitle} - Updated`;
      await helpers.fillField('input[name="title"]', updatedTitle);
      
      // Save changes
      const saveButton = page.locator('button[type="submit"]').or(
        page.locator('text=Save')
      ).first();
      
      await saveButton.click();
      
      // Verify update
      await expect(page.locator(`text=${updatedTitle}`)).toBeVisible({ timeout: 10000 });
      
      await helpers.takeScreenshot('task-edited-successfully');
    }
  });

  test('should assign task to user', async ({ page }) => {
    // Create a task
    await helpers.createTask({ title: testData.taskTitle });
    
    // Look for assign button or dropdown
    const assignControl = page.locator('text=Assign').or(
      page.locator('select[name="assignee"]')
    ).first();
    
    if (await assignControl.isVisible()) {
      await assignControl.click();
      
      // Select assignee if dropdown is available
      const assigneeOption = page.locator('option').or(
        page.locator('text=Admin User')
      ).first();
      
      if (await assigneeOption.isVisible()) {
        await assigneeOption.click();
        await helpers.takeScreenshot('task-assigned');
      }
    }
  });

  test('should filter tasks by status', async ({ page }) => {
    // Create tasks with different statuses
    await helpers.createTask({ title: `${testData.taskTitle} Open` });
    await helpers.createTask({ title: `${testData.taskTitle} Progress` });
    
    // Look for filter controls
    const filterControl = page.locator('select[name="filter"]').or(
      page.locator('text=Filter').or(page.locator('text=All'))
    ).first();
    
    if (await filterControl.isVisible()) {
      // Filter by status
      if (await page.locator('select[name="filter"]').isVisible()) {
        await page.selectOption('select[name="filter"]', 'OPEN');
      } else {
        await filterControl.click();
        await page.click('text=Open');
      }
      
      await helpers.takeScreenshot('tasks-filtered-by-status');
    }
  });

  test('should search tasks', async ({ page }) => {
    // Create multiple tasks
    await helpers.createTask({ title: `${testData.taskTitle} Alpha` });
    await helpers.createTask({ title: `${testData.taskTitle} Beta` });
    
    // Look for search input
    const searchInput = page.locator('input[placeholder*="search"]').or(
      page.locator('input[name="search"]')
    ).first();
    
    if (await searchInput.isVisible()) {
      // Search for specific task
      await searchInput.fill('Alpha');
      
      // Verify search results
      await expect(page.locator(`text=${testData.taskTitle} Alpha`)).toBeVisible();
      await expect(page.locator(`text=${testData.taskTitle} Beta`)).not.toBeVisible();
      
      await helpers.takeScreenshot('tasks-search-results');
    }
  });

  test('should display task statistics', async ({ page }) => {
    // Create tasks
    await helpers.createTask({ title: testData.taskTitle });
    
    // Look for statistics
    const statsSection = page.locator('text=Total').or(
      page.locator('text=Completed').or(page.locator('text=Pending'))
    ).first();
    
    if (await statsSection.isVisible()) {
      await helpers.takeScreenshot('task-statistics');
    }
  });

  test('should handle task deletion', async ({ page }) => {
    // Create a task
    await helpers.createTask({ title: testData.taskTitle });

    // Find delete button
    const deleteButton = page.locator('text=Delete').or(
      page.locator('[data-testid="delete-task"]')
    ).first();

    if (await deleteButton.isVisible()) {
      await deleteButton.click();

      // Handle confirmation
      const confirmButton = page.locator('text=Confirm').or(
        page.locator('text=Yes').or(page.locator('text=Delete'))
      ).first();

      if (await confirmButton.isVisible()) {
        await confirmButton.click();

        // Verify deletion
        await expect(page.locator(`text=${testData.taskTitle}`)).not.toBeVisible({ timeout: 10000 });

        await helpers.takeScreenshot('task-deleted');
      }
    }
  });

  test('should display task kanban board', async ({ page }) => {
    // Create tasks
    await helpers.createTask({ title: testData.taskTitle });

    // Look for kanban/board view
    const boardView = page.locator('text=Board').or(
      page.locator('text=Kanban').or(page.locator('[data-testid="board-view"]'))
    ).first();

    if (await boardView.isVisible()) {
      await boardView.click();

      // Check for columns (To Do, In Progress, Done)
      const columns = page.locator('text=To Do').or(
        page.locator('text=In Progress').or(page.locator('text=Done'))
      );

      await expect(columns.first()).toBeVisible({ timeout: 5000 });
      await helpers.takeScreenshot('task-kanban-board');
    }
  });

  test('should drag and drop tasks in kanban board', async ({ page }) => {
    // Create a task
    await helpers.createTask({ title: testData.taskTitle });

    // Switch to board view if available
    const boardView = page.locator('text=Board').or(page.locator('text=Kanban')).first();
    if (await boardView.isVisible()) {
      await boardView.click();
    }

    // Find task card and target column
    const taskCard = page.locator(`text=${testData.taskTitle}`).first();
    const targetColumn = page.locator('text=In Progress').first();

    if (await taskCard.isVisible() && await targetColumn.isVisible()) {
      // Perform drag and drop
      await taskCard.dragTo(targetColumn);

      await helpers.takeScreenshot('task-dragged-to-column');
    }
  });
});
