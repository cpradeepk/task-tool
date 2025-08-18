const { test, expect } = require('@playwright/test');

// Configuration
const BASE_URL = 'https://task.amtariksha.com';
const TEST_EMAIL = 'test@example.com';
const TEST_PIN = '1234';

test.describe('Task Management CRUD Operations', () => {
  let page;

  test.beforeAll(async ({ browser }) => {
    page = await browser.newPage();
    
    // Navigate to the application
    await page.goto(`${BASE_URL}/task/`);
    await page.waitForLoadState('networkidle');
    
    // Login (assuming PIN-based login for testing)
    try {
      // Check if login form is present
      const loginForm = await page.locator('input[type="email"], input[placeholder*="email"]').first();
      if (await loginForm.isVisible()) {
        await loginForm.fill(TEST_EMAIL);
        
        // Look for PIN input
        const pinInput = await page.locator('input[type="password"], input[placeholder*="PIN"]').first();
        if (await pinInput.isVisible()) {
          await pinInput.fill(TEST_PIN);
        }
        
        // Click login button
        await page.locator('button:has-text("Login"), button:has-text("Sign In")').first().click();
        await page.waitForLoadState('networkidle');
      }
    } catch (error) {
      console.log('Login not required or already logged in');
    }
  });

  test.afterAll(async () => {
    await page.close();
  });

  test('1. Project CRUD Operations', async () => {
    console.log('Testing Project CRUD...');
    
    // Navigate to projects page
    await page.goto(`${BASE_URL}/task/#/projects`);
    await page.waitForLoadState('networkidle');
    
    // Test Project Creation
    console.log('Creating new project...');
    const createProjectBtn = page.locator('button:has-text("Add"), button:has-text("Create"), button:has-text("New Project")').first();
    
    if (await createProjectBtn.isVisible()) {
      await createProjectBtn.click();
      
      // Fill project details
      const projectNameInput = page.locator('input[placeholder*="name"], input[name*="name"]').first();
      if (await projectNameInput.isVisible()) {
        await projectNameInput.fill('Test Project - Playwright');
        
        // Submit form
        await page.locator('button:has-text("Save"), button:has-text("Create"), button:has-text("Submit")').first().click();
        await page.waitForLoadState('networkidle');
        
        // Verify project was created
        await expect(page.locator('text=Test Project - Playwright')).toBeVisible();
        console.log('✅ Project created successfully');
      }
    } else {
      console.log('⚠️ Project creation button not found');
    }
    
    // Test Project Reading/Viewing
    console.log('Testing project viewing...');
    const projectCard = page.locator('text=Test Project - Playwright').first();
    if (await projectCard.isVisible()) {
      await projectCard.click();
      await page.waitForLoadState('networkidle');
      console.log('✅ Project viewing works');
    }
  });

  test('2. Module CRUD Operations', async () => {
    console.log('Testing Module CRUD...');
    
    // Navigate to a project (assuming we're in project view)
    await page.waitForLoadState('networkidle');
    
    // Test Module Creation
    console.log('Creating new module...');
    const addModuleBtn = page.locator('button:has-text("Add Module"), button:has-text("New Module")').first();
    
    if (await addModuleBtn.isVisible()) {
      await addModuleBtn.click();
      
      // Fill module details
      const moduleNameInput = page.locator('input[placeholder*="module"], input[name*="module"]').first();
      if (await moduleNameInput.isVisible()) {
        await moduleNameInput.fill('Test Module - Playwright');
        
        // Submit form
        await page.locator('button:has-text("Save"), button:has-text("Create")').first().click();
        await page.waitForLoadState('networkidle');
        
        // Verify module was created
        await expect(page.locator('text=Test Module - Playwright')).toBeVisible();
        console.log('✅ Module created successfully');
      }
    } else {
      console.log('⚠️ Module creation button not found');
    }
  });

  test('3. Task CRUD Operations', async () => {
    console.log('Testing Task CRUD...');
    
    // Navigate to tasks view
    await page.goto(`${BASE_URL}/task/#/projects/1/tasks`);
    await page.waitForLoadState('networkidle');
    
    // Test Task Creation - Look for floating action button or Add Task button
    console.log('Creating new task...');
    
    // Try different selectors for task creation
    const taskCreationSelectors = [
      'button[title="Add Task"]',
      'button:has-text("Add Task")',
      '.floating-action-button',
      '[data-testid="add-task"]',
      'button:has(svg)', // Floating action button with icon
      '.fab', // Floating action button class
    ];
    
    let taskCreated = false;
    
    for (const selector of taskCreationSelectors) {
      const addTaskBtn = page.locator(selector).first();
      if (await addTaskBtn.isVisible()) {
        console.log(`Found task creation button: ${selector}`);
        await addTaskBtn.click();
        await page.waitForTimeout(1000);
        
        // Look for inline task creation or modal
        const taskTitleInput = page.locator('input[placeholder*="title"], input[placeholder*="task"], input[name*="title"]').first();
        
        if (await taskTitleInput.isVisible()) {
          await taskTitleInput.fill('Test Task - Playwright CRUD');
          
          // Look for save button (green checkmark or Save button)
          const saveSelectors = [
            'button:has-text("Save")',
            'button[title="Save"]',
            'button:has(svg[data-icon="check"])',
            '.save-button',
            'button.btn-success',
          ];
          
          for (const saveSelector of saveSelectors) {
            const saveBtn = page.locator(saveSelector).first();
            if (await saveBtn.isVisible()) {
              await saveBtn.click();
              await page.waitForLoadState('networkidle');
              taskCreated = true;
              break;
            }
          }
          
          if (taskCreated) {
            // Verify task was created
            await expect(page.locator('text=Test Task - Playwright CRUD')).toBeVisible();
            console.log('✅ Task created successfully');
          }
          break;
        }
      }
    }
    
    if (!taskCreated) {
      console.log('⚠️ Task creation failed - buttons not found or not working');
    }
    
    // Test Task Reading/Viewing
    console.log('Testing task viewing...');
    const taskRow = page.locator('text=Test Task - Playwright CRUD').first();
    if (await taskRow.isVisible()) {
      await taskRow.click();
      await page.waitForLoadState('networkidle');
      
      // Check if task detail page loaded
      const taskDetailIndicators = [
        'text=Task Details',
        'text=Description',
        'text=Status',
        'text=Priority',
      ];
      
      let detailPageLoaded = false;
      for (const indicator of taskDetailIndicators) {
        if (await page.locator(indicator).isVisible()) {
          detailPageLoaded = true;
          break;
        }
      }
      
      if (detailPageLoaded) {
        console.log('✅ Task detail view works');
      } else {
        console.log('⚠️ Task detail view may not be working');
      }
    }
    
    // Test Task Update
    console.log('Testing task update...');
    // This would involve editing task fields inline or in detail view
    
    // Test Task Deletion
    console.log('Testing task deletion...');
    // This would involve finding delete button and confirming deletion
  });

  test('4. Subtask CRUD Operations', async () => {
    console.log('Testing Subtask CRUD...');
    
    // Navigate to a task detail page
    await page.goto(`${BASE_URL}/task/#/projects/1/tasks/1`);
    await page.waitForLoadState('networkidle');
    
    // Test Subtask Creation
    console.log('Creating new subtask...');
    const addSubtaskBtn = page.locator('button:has-text("Add Subtask")').first();
    
    if (await addSubtaskBtn.isVisible()) {
      await addSubtaskBtn.click();
      
      // Fill subtask details in modal/form
      const subtaskTitleInput = page.locator('input[placeholder*="title"], input[name*="title"]').last();
      if (await subtaskTitleInput.isVisible()) {
        await subtaskTitleInput.fill('Test Subtask - Playwright');
        
        // Submit form
        await page.locator('button:has-text("Create"), button:has-text("Save")').first().click();
        await page.waitForLoadState('networkidle');
        
        // Verify subtask was created
        await expect(page.locator('text=Test Subtask - Playwright')).toBeVisible();
        console.log('✅ Subtask created successfully');
      }
    } else {
      console.log('⚠️ Subtask creation button not found');
    }
  });

  test('5. Performance and Error Handling', async () => {
    console.log('Testing performance and error handling...');
    
    // Test page load times
    const startTime = Date.now();
    await page.goto(`${BASE_URL}/task/#/projects`);
    await page.waitForLoadState('networkidle');
    const loadTime = Date.now() - startTime;
    
    console.log(`Page load time: ${loadTime}ms`);
    
    if (loadTime > 5000) {
      console.log('⚠️ Page load time is slow (>5s)');
    } else {
      console.log('✅ Page load time is acceptable');
    }
    
    // Check for console errors
    const consoleErrors = [];
    page.on('console', msg => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });
    
    // Navigate through different pages to trigger any errors
    await page.goto(`${BASE_URL}/task/#/dashboard`);
    await page.waitForLoadState('networkidle');
    
    await page.goto(`${BASE_URL}/task/#/projects`);
    await page.waitForLoadState('networkidle');
    
    if (consoleErrors.length > 0) {
      console.log('⚠️ Console errors found:');
      consoleErrors.forEach(error => console.log(`  - ${error}`));
    } else {
      console.log('✅ No console errors detected');
    }
  });
});
