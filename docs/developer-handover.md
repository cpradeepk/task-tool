# SwargFood Task Management - Developer Handover Documentation

## 📋 Table of Contents

1. [Project Architecture Overview](#project-architecture-overview)
2. [Development Environment Setup](#development-environment-setup)
3. [Codebase Navigation Guide](#codebase-navigation-guide)
4. [Feature Implementation Guidelines](#feature-implementation-guidelines)
5. [Testing Requirements](#testing-requirements)
6. [Quality Assurance Checklist](#quality-assurance-checklist)
7. [Deployment and Monitoring](#deployment-and-monitoring)
8. [Common Issues and Solutions](#common-issues-and-solutions)
9. [Integration Points](#integration-points)

---

## 1. Project Architecture Overview

### Technology Stack

#### **Frontend - Flutter Web**
- **Framework**: Flutter 3.0+ with Dart
- **State Management**: Provider pattern
- **UI Components**: Material Design 3
- **Build Tool**: Flutter Web Compiler
- **Deployment**: Static files served via nginx

#### **Backend - Node.js**
- **Runtime**: Node.js 18+
- **Framework**: Express.js
- **Database ORM**: Prisma
- **Authentication**: JWT tokens
- **Real-time**: Socket.IO
- **File Upload**: Multer
- **Process Manager**: PM2

#### **Database - PostgreSQL**
- **Version**: PostgreSQL 13+
- **Hosting**: AWS RDS
- **Schema Management**: Prisma migrations
- **Backup**: Automated daily backups

#### **Infrastructure**
- **Server**: AWS Lightsail Ubuntu
- **Web Server**: Nginx (reverse proxy)
- **SSL**: Let's Encrypt certificates
- **Domain**: ai.swargfood.com/task/
- **Monitoring**: Custom health check scripts

### File Structure and Organization

```
task-tool/
├── backend/                     # Node.js backend application
│   ├── src/
│   │   ├── controllers/         # Business logic controllers
│   │   ├── routes/             # API route definitions
│   │   ├── middleware/         # Custom middleware
│   │   ├── services/           # Business services
│   │   ├── utils/              # Utility functions
│   │   ├── app.js              # Express app configuration
│   │   └── server.js           # Server entry point
│   ├── prisma/                 # Database schema and migrations
│   ├── uploads/                # File upload storage
│   └── package.json            # Dependencies and scripts
├── frontend/                   # Flutter web application
│   ├── lib/
│   │   ├── screens/            # UI screens/pages
│   │   ├── widgets/            # Reusable UI components
│   │   ├── providers/          # State management
│   │   ├── services/           # API and business services
│   │   ├── models/             # Data models
│   │   └── main.dart           # Application entry point
│   ├── web/                    # Web-specific files
│   └── pubspec.yaml            # Dependencies and configuration
├── tests/                      # Automated test suite
│   ├── e2e/                    # End-to-end tests
│   ├── api/                    # API tests
│   ├── smoke/                  # Smoke tests
│   └── utils/                  # Test utilities
├── scripts/                    # Management and deployment scripts
├── docs/                       # Project documentation
├── deployment/                 # Deployment configurations
└── nginx/                      # Nginx configuration files
```

### Key Dependencies and Their Purposes

#### **Backend Dependencies**
```json
{
  "express": "Web framework for Node.js",
  "prisma": "Database ORM and migration tool",
  "@prisma/client": "Database client",
  "jsonwebtoken": "JWT token handling",
  "bcrypt": "Password hashing",
  "socket.io": "Real-time communication",
  "multer": "File upload handling",
  "cors": "Cross-origin resource sharing",
  "helmet": "Security middleware",
  "express-rate-limit": "Rate limiting",
  "nodemailer": "Email sending",
  "winston": "Logging framework"
}
```

#### **Frontend Dependencies**
```yaml
dependencies:
  flutter: "UI framework"
  provider: "State management"
  http: "HTTP client for API calls"
  shared_preferences: "Local storage"
  file_picker: "File selection"
  image_picker: "Image selection"
  socket_io_client: "Real-time communication"
  intl: "Internationalization"
  flutter_secure_storage: "Secure token storage"
```

#### **Testing Dependencies**
```json
{
  "@playwright/test": "End-to-end testing framework",
  "jest": "Unit testing framework",
  "supertest": "API testing"
}
```

---

## 2. Development Environment Setup

### Prerequisites

#### **Required Software**
- **Node.js** 18+ with npm
- **Flutter SDK** 3.0+
- **PostgreSQL** 13+ (local development)
- **Git** for version control
- **VS Code** or preferred IDE

#### **Recommended Tools**
- **Postman** for API testing
- **pgAdmin** for database management
- **Flutter DevTools** for debugging
- **Docker** (optional, for containerized development)

### Installation Steps

#### **1. Clone Repository**
```bash
git clone https://github.com/cpradeepk/task-tool.git
cd task-tool
```

#### **2. Backend Setup**
```bash
cd backend

# Install dependencies
npm install

# Copy environment file
cp .env.example .env

# Edit .env with your database credentials
nano .env

# Run database migrations
npx prisma migrate dev

# Seed database with initial data
npx prisma db seed

# Start development server
npm run dev
```

#### **3. Frontend Setup**
```bash
cd frontend

# Get Flutter dependencies
flutter pub get

# Run on web (development)
flutter run -d web

# Or build for production
flutter build web --release --base-href="/task/"
```

#### **4. Testing Setup**
```bash
# Install test dependencies
npm install

# Install Playwright browsers
npx playwright install

# Run tests
npm test
```

### Local Development Server Setup

#### **Backend Development Server**
```bash
cd backend

# Development with hot reload
npm run dev

# Production mode
npm start

# Debug mode
npm run debug
```

**Available at**: `http://localhost:3003/task/`

#### **Frontend Development Server**
```bash
cd frontend

# Web development server
flutter run -d web

# With specific port
flutter run -d web --web-port 3000
```

**Available at**: `http://localhost:3000/`

### Database Configuration and Seeding

#### **Environment Variables (.env)**
```bash
# Database
DATABASE_URL="postgresql://username:password@localhost:5432/taskmanagement"

# JWT
JWT_SECRET="your-super-secret-jwt-key"
JWT_EXPIRES_IN="7d"

# Server
NODE_ENV="development"
PORT=3003

# Email (optional)
SMTP_HOST="smtp.gmail.com"
SMTP_PORT=587
SMTP_USER="your-email@gmail.com"
SMTP_PASS="your-app-password"

# File Upload
MAX_FILE_SIZE=10485760  # 10MB
UPLOAD_PATH="./uploads"
```

#### **Database Setup Commands**
```bash
# Create database
createdb taskmanagement

# Run migrations
npx prisma migrate dev

# Reset database (development only)
npx prisma migrate reset

# Seed with demo data
npx prisma db seed

# Open database browser
npx prisma studio
```

#### **Demo Users Created by Seeding**
- **Admin User**: `admin@example.com` / `admin123`
- **Demo User**: `demo@example.com` / `demo123`

---

## 3. Codebase Navigation Guide

### Frontend Structure (Flutter)

#### **Core Application Files**
- `lib/main.dart` - Application entry point with routing setup
- `lib/app.dart` - App configuration and theme setup

#### **Screens (UI Pages)**
```
lib/screens/
├── splash_screen.dart          # Initial loading screen
├── login_screen.dart           # User authentication
├── home_screen.dart            # Main dashboard
├── integrated_dashboard.dart   # Advanced dashboard
├── projects_screen.dart        # Project management
├── tasks_screen.dart           # Task management
├── time_tracking_screen.dart   # Time tracking interface
├── profile_screen.dart         # User profile
└── settings_screen.dart        # Application settings
```

#### **Widgets (Reusable Components)**
```
lib/widgets/
├── custom_app_bar.dart         # Application header
├── navigation_drawer.dart      # Side navigation
├── task_card.dart             # Task display component
├── project_card.dart          # Project display component
├── time_tracker_widget.dart   # Timer component
├── notification_center.dart   # Notifications
├── chat_interface.dart        # Real-time chat
└── file_upload_widget.dart    # File upload component
```

#### **Providers (State Management)**
```
lib/providers/
├── auth_provider.dart          # Authentication state
├── project_provider.dart      # Project data management
├── task_provider.dart         # Task data management
├── time_tracking_provider.dart # Time tracking state
├── notification_provider.dart # Notifications state
└── theme_provider.dart        # UI theme management
```

#### **Services (Business Logic)**
```
lib/services/
├── api_service.dart           # HTTP API client
├── auth_service.dart          # Authentication logic
├── socket_service.dart        # Real-time communication
├── notification_service.dart  # Push notifications
├── time_tracking_service.dart # Time tracking logic
├── chat_service.dart          # Chat functionality
└── file_service.dart          # File operations
```

#### **Models (Data Structures)**
```
lib/models/
├── user.dart                  # User data model
├── project.dart               # Project data model
├── task.dart                  # Task data model
├── time_entry.dart            # Time tracking model
├── notification.dart          # Notification model
└── chat_message.dart          # Chat message model
```

### Backend Structure (Node.js)

#### **Core Application Files**
- `src/server.js` - Server entry point
- `src/app.js` - Express application setup with middleware

#### **Controllers (Business Logic)**
```
src/controllers/
├── authController.js          # Authentication logic
├── userController.js          # User management
├── projectController.js       # Project operations
├── taskController.js          # Task operations
├── timeTrackingController.js  # Time tracking
├── notificationController.js  # Notifications
├── chatController.js          # Chat functionality
├── fileController.js          # File operations
└── analyticsController.js     # Analytics and reporting
```

#### **Routes (API Endpoints)**
```
src/routes/
├── auth.js                    # Authentication routes
├── users.js                   # User management routes
├── projects.js                # Project routes
├── tasks.js                   # Task routes
├── timeTracking.js            # Time tracking routes
├── notifications.js           # Notification routes
├── chat.js                    # Chat routes
├── files.js                   # File upload/download routes
└── analytics.js               # Analytics routes
```

#### **Middleware (Request Processing)**
```
src/middleware/
├── auth.js                    # JWT authentication
├── validation.js              # Input validation
├── upload.js                  # File upload handling
├── rateLimiting.js           # Rate limiting
├── errorHandler.js           # Error handling
└── logging.js                # Request logging
```

#### **Services (Business Services)**
```
src/services/
├── emailService.js           # Email notifications
├── socketService.js          # Real-time events
├── fileService.js            # File processing
├── notificationService.js    # Push notifications
├── analyticsService.js       # Data analytics
└── backupService.js          # Data backup
```

### Database Schema and Relationships

#### **Core Tables**
```sql
-- Users table
users (id, email, name, password, role, preferences, created_at, updated_at)

-- Projects table  
projects (id, name, description, status, priority, owner_id, created_at, updated_at)

-- Tasks table
tasks (id, title, description, status, priority, project_id, assignee_id, due_date, created_at, updated_at)

-- Time entries table
time_entries (id, task_id, user_id, start_time, end_time, duration, description, created_at)

-- Project members table
project_members (id, project_id, user_id, role, joined_at)

-- Task dependencies table
task_dependencies (id, task_id, depends_on_task_id, dependency_type, created_at)

-- Notifications table
notifications (id, user_id, type, title, message, read, created_at)

-- Chat channels table
chat_channels (id, name, type, project_id, created_by, created_at)

-- Chat messages table
chat_messages (id, channel_id, user_id, message, message_type, created_at)

-- File uploads table
file_uploads (id, filename, original_name, path, size, mime_type, uploaded_by, created_at)
```

#### **Key Relationships**
- **Users** → **Projects** (one-to-many via owner_id)
- **Projects** → **Tasks** (one-to-many)
- **Users** → **Tasks** (one-to-many via assignee_id)
- **Tasks** → **Time Entries** (one-to-many)
- **Tasks** → **Task Dependencies** (many-to-many)
- **Projects** → **Project Members** (many-to-many through junction table)
- **Projects** → **Chat Channels** (one-to-many)
- **Chat Channels** → **Chat Messages** (one-to-many)

---

## 4. Feature Implementation Guidelines

### Coding Standards and Conventions

#### **Backend (Node.js) Standards**
```javascript
// File naming: camelCase for files, PascalCase for classes
// userController.js, ProjectService.js

// Function naming: camelCase with descriptive names
const getUserProjects = async (userId) => {
  // Implementation
};

// Error handling: Always use try-catch for async operations
const createProject = async (req, res) => {
  try {
    const project = await projectService.create(req.body);
    res.status(201).json(project);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

// Validation: Use middleware for input validation
const validateProjectData = (req, res, next) => {
  const { name, description } = req.body;
  if (!name || name.trim().length === 0) {
    return res.status(400).json({ error: 'Project name is required' });
  }
  next();
};
```

#### **Frontend (Flutter) Standards**
```dart
// File naming: snake_case for files
// user_profile_screen.dart, project_card_widget.dart

// Class naming: PascalCase
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});
}

// Variable naming: camelCase
String userName = '';
List<Project> userProjects = [];

// Method naming: camelCase with descriptive names
Future<void> loadUserProjects() async {
  try {
    final projects = await apiService.getUserProjects();
    setState(() {
      userProjects = projects;
    });
  } catch (error) {
    // Handle error
  }
}

// Widget structure: Always use const constructors when possible
class ProjectCard extends StatelessWidget {
  final Project project;
  final VoidCallback? onTap;
  
  const ProjectCard({
    super.key,
    required this.project,
    this.onTap,
  });
}
```

### Component/Module Creation Patterns

#### **Creating a New Backend Route**
```javascript
// 1. Create controller (src/controllers/newFeatureController.js)
const newFeatureController = {
  async getAll(req, res) {
    try {
      const items = await prisma.newFeature.findMany();
      res.json(items);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  },

  async create(req, res) {
    try {
      const item = await prisma.newFeature.create({
        data: req.body
      });
      res.status(201).json(item);
    } catch (error) {
      res.status(400).json({ error: error.message });
    }
  }
};

// 2. Create route (src/routes/newFeature.js)
const express = require('express');
const router = express.Router();
const newFeatureController = require('../controllers/newFeatureController');
const auth = require('../middleware/auth');

router.get('/', auth, newFeatureController.getAll);
router.post('/', auth, newFeatureController.create);

module.exports = router;

// 3. Register route in app.js
app.use('/task/api/new-feature', require('./routes/newFeature'));
```

#### **Creating a New Flutter Screen**
```dart
// 1. Create screen file (lib/screens/new_feature_screen.dart)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/new_feature_provider.dart';

class NewFeatureScreen extends StatefulWidget {
  const NewFeatureScreen({super.key});

  @override
  State<NewFeatureScreen> createState() => _NewFeatureScreenState();
}

class _NewFeatureScreenState extends State<NewFeatureScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NewFeatureProvider>().loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Feature')),
      body: Consumer<NewFeatureProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          return ListView.builder(
            itemCount: provider.items.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(provider.items[index].name),
                onTap: () => provider.selectItem(provider.items[index]),
              );
            },
          );
        },
      ),
    );
  }
}

// 2. Create provider (lib/providers/new_feature_provider.dart)
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/new_feature.dart';

class NewFeatureProvider with ChangeNotifier {
  List<NewFeature> _items = [];
  bool _isLoading = false;

  List<NewFeature> get items => _items;
  bool get isLoading => _isLoading;

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _items = await ApiService.getNewFeatures();
    } catch (error) {
      // Handle error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

// 3. Register provider in main.dart
MultiProvider(
  providers: [
    // ... existing providers
    ChangeNotifierProvider(create: (_) => NewFeatureProvider()),
  ],
  // ... rest of app
)

// 4. Add route in main.dart
'/new-feature': (context) => const AuthGuard(child: NewFeatureScreen()),
```

### API Endpoint Development Process

#### **1. Define API Contract**
```javascript
// Document the endpoint first
/**
 * GET /task/api/projects/:id/tasks
 * Get all tasks for a specific project
 *
 * @param {string} id - Project ID
 * @query {string} status - Filter by task status (optional)
 * @query {number} page - Page number for pagination (optional)
 * @query {number} limit - Items per page (optional)
 *
 * @returns {Object} Response object
 * @returns {Task[]} response.data - Array of tasks
 * @returns {Object} response.pagination - Pagination info
 * @returns {number} response.pagination.total - Total count
 * @returns {number} response.pagination.page - Current page
 * @returns {number} response.pagination.pages - Total pages
 */
```

#### **2. Implement Controller Method**
```javascript
const getProjectTasks = async (req, res) => {
  try {
    const { id } = req.params;
    const { status, page = 1, limit = 10 } = req.query;

    // Validate project exists and user has access
    const project = await prisma.project.findFirst({
      where: {
        id,
        OR: [
          { ownerId: req.user.id },
          { members: { some: { userId: req.user.id } } }
        ]
      }
    });

    if (!project) {
      return res.status(404).json({ error: 'Project not found' });
    }

    // Build query conditions
    const where = { projectId: id };
    if (status) where.status = status;

    // Get tasks with pagination
    const [tasks, total] = await Promise.all([
      prisma.task.findMany({
        where,
        include: {
          assignee: { select: { id: true, name: true, email: true } },
          timeEntries: true
        },
        skip: (page - 1) * limit,
        take: parseInt(limit),
        orderBy: { createdAt: 'desc' }
      }),
      prisma.task.count({ where })
    ]);

    res.json({
      data: tasks,
      pagination: {
        total,
        page: parseInt(page),
        pages: Math.ceil(total / limit)
      }
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};
```

#### **3. Add Route with Middleware**
```javascript
const express = require('express');
const router = express.Router();
const { auth, validateProject } = require('../middleware');
const projectController = require('../controllers/projectController');

// Apply authentication to all routes
router.use(auth);

// Get project tasks with validation
router.get('/:id/tasks',
  validateProject,
  projectController.getProjectTasks
);

module.exports = router;
```

#### **4. Add Validation Middleware**
```javascript
const validateProject = async (req, res, next) => {
  const { id } = req.params;

  if (!id || !id.match(/^[a-zA-Z0-9_-]+$/)) {
    return res.status(400).json({ error: 'Invalid project ID' });
  }

  next();
};
```

### Database Migration Procedures

#### **1. Create Migration**
```bash
# Create new migration
npx prisma migrate dev --name add_task_priority_field

# This creates a new migration file in prisma/migrations/
```

#### **2. Migration File Structure**
```sql
-- Migration: 20240723000000_add_task_priority_field/migration.sql

-- Add priority field to tasks table
ALTER TABLE "tasks" ADD COLUMN "priority" TEXT NOT NULL DEFAULT 'MEDIUM';

-- Create index for better query performance
CREATE INDEX "tasks_priority_idx" ON "tasks"("priority");

-- Update existing tasks with default priority
UPDATE "tasks" SET "priority" = 'MEDIUM' WHERE "priority" IS NULL;
```

#### **3. Update Prisma Schema**
```prisma
// prisma/schema.prisma

model Task {
  id          String   @id @default(cuid())
  title       String
  description String?
  status      TaskStatus @default(OPEN)
  priority    Priority @default(MEDIUM)  // Add this field
  projectId   String
  assigneeId  String?
  dueDate     DateTime?
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  project     Project  @relation(fields: [projectId], references: [id])
  assignee    User?    @relation(fields: [assigneeId], references: [id])

  @@map("tasks")
  @@index([priority])  // Add index
}

enum Priority {
  LOW
  MEDIUM
  HIGH
  URGENT
}
```

#### **4. Deploy Migration**
```bash
# Deploy to production
npx prisma migrate deploy

# Generate updated Prisma client
npx prisma generate
```

---

## 5. Testing Requirements

### Mandatory Test Coverage for New Features

#### **Backend Testing Requirements**
- **Unit Tests**: All controller methods must have unit tests
- **Integration Tests**: API endpoints must have integration tests
- **Database Tests**: Database operations must be tested
- **Minimum Coverage**: 80% code coverage required

#### **Frontend Testing Requirements**
- **Widget Tests**: All custom widgets must have widget tests
- **Integration Tests**: Critical user flows must have integration tests
- **E2E Tests**: New features must have end-to-end tests
- **Accessibility Tests**: UI components must pass accessibility tests

### How to Run the Test Suite

#### **Run All Tests**
```bash
# Run complete test suite
npm test

# Run with coverage report
npm run test:coverage

# Run specific test suites
npm run test:smoke          # Quick health checks
npm run test:auth           # Authentication tests
npm run test:api            # API endpoint tests
npm run test:e2e            # End-to-end tests
```

#### **Run Tests by Browser**
```bash
npm run test:chrome         # Chrome only
npm run test:firefox        # Firefox only
npm run test:safari         # Safari only
npm run test:mobile         # Mobile devices
```

#### **Interactive Testing**
```bash
npm run test:headed         # Visual test execution
npm run test:debug          # Debug mode with breakpoints
npm run test:ui             # Interactive UI mode
```

#### **Backend Unit Tests**
```bash
cd backend

# Run backend unit tests
npm test

# Run with coverage
npm run test:coverage

# Run specific test file
npm test -- --testPathPattern=userController.test.js

# Watch mode for development
npm run test:watch
```

#### **Frontend Tests**
```bash
cd frontend

# Run Flutter tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test
flutter test test/widgets/task_card_test.dart
```

### Test Writing Guidelines and Patterns

#### **Backend API Test Pattern**
```javascript
// tests/api/projects.test.js
const request = require('supertest');
const app = require('../../src/app');
const { setupTestDb, cleanupTestDb } = require('../helpers/database');

describe('Projects API', () => {
  let authToken;
  let testUser;

  beforeAll(async () => {
    await setupTestDb();
    // Create test user and get auth token
    const response = await request(app)
      .post('/task/api/auth/register')
      .send({
        email: 'test@example.com',
        password: 'password123',
        name: 'Test User'
      });

    authToken = response.body.token;
    testUser = response.body.user;
  });

  afterAll(async () => {
    await cleanupTestDb();
  });

  describe('POST /task/api/projects', () => {
    it('should create a new project', async () => {
      const projectData = {
        name: 'Test Project',
        description: 'Test project description'
      };

      const response = await request(app)
        .post('/task/api/projects')
        .set('Authorization', `Bearer ${authToken}`)
        .send(projectData)
        .expect(201);

      expect(response.body).toHaveProperty('id');
      expect(response.body.name).toBe(projectData.name);
      expect(response.body.ownerId).toBe(testUser.id);
    });

    it('should return 400 for invalid project data', async () => {
      const response = await request(app)
        .post('/task/api/projects')
        .set('Authorization', `Bearer ${authToken}`)
        .send({}) // Empty data
        .expect(400);

      expect(response.body).toHaveProperty('error');
    });
  });
});
```

#### **Frontend Widget Test Pattern**
```dart
// test/widgets/task_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:task_management/widgets/task_card.dart';
import 'package:task_management/models/task.dart';
import 'package:task_management/providers/task_provider.dart';

void main() {
  group('TaskCard Widget', () {
    late Task testTask;

    setUp(() {
      testTask = Task(
        id: '1',
        title: 'Test Task',
        description: 'Test description',
        status: TaskStatus.open,
        priority: Priority.high,
        projectId: 'project1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });

    testWidgets('should display task information correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider(
              create: (_) => TaskProvider(),
              child: TaskCard(task: testTask),
            ),
          ),
        ),
      );

      // Verify task title is displayed
      expect(find.text('Test Task'), findsOneWidget);

      // Verify task description is displayed
      expect(find.text('Test description'), findsOneWidget);

      // Verify priority indicator is shown
      expect(find.byIcon(Icons.priority_high), findsOneWidget);
    });

    testWidgets('should handle tap events', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider(
              create: (_) => TaskProvider(),
              child: TaskCard(
                task: testTask,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      // Tap the card
      await tester.tap(find.byType(TaskCard));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
```

#### **E2E Test Pattern**
```javascript
// tests/e2e/task-management.spec.js
import { test, expect } from '@playwright/test';
import { TestHelpers } from '../utils/test-helpers.js';

test.describe('Task Management Flow', () => {
  let helpers;
  let testData;

  test.beforeEach(async ({ page }) => {
    helpers = new TestHelpers(page);
    testData = helpers.generateTestData();

    // Login before each test
    await helpers.login('admin@example.com', 'admin123');
  });

  test('should create and manage tasks', async ({ page }) => {
    // Create a project first
    await helpers.createProject({ name: testData.projectName });

    // Navigate to tasks
    await page.click('text=Tasks');

    // Create a new task
    await page.click('text=Create Task');
    await helpers.fillField('input[name="title"]', testData.taskTitle);
    await helpers.fillField('textarea[name="description"]', 'Test task description');
    await page.selectOption('select[name="priority"]', 'HIGH');
    await page.click('button[type="submit"]');

    // Verify task was created
    await expect(page.locator(`text=${testData.taskTitle}`)).toBeVisible();

    // Update task status
    await page.click(`text=${testData.taskTitle}`);
    await page.selectOption('select[name="status"]', 'IN_PROGRESS');
    await page.click('button:has-text("Save")');

    // Verify status update
    await expect(page.locator('text=In Progress')).toBeVisible();

    // Take screenshot for verification
    await helpers.takeScreenshot('task-management-complete');
  });
});
```

---

## 6. Quality Assurance Checklist

### Minor Changes Checklist (Bug fixes, small features)

#### **Before Making Changes**
- [ ] **Create feature branch** from main
- [ ] **Understand the issue** completely
- [ ] **Check existing tests** that might be affected
- [ ] **Plan the minimal change** required

#### **During Development**
- [ ] **Follow coding standards** (see section 4)
- [ ] **Write/update unit tests** for changed code
- [ ] **Test locally** in development environment
- [ ] **Check console** for any new errors or warnings

#### **Before Committing**
- [ ] **Run smoke tests**: `npm run test:smoke`
- [ ] **Check affected functionality** manually
- [ ] **Verify no console errors** in browser/server
- [ ] **Test on mobile and desktop** viewports
- [ ] **Run linting**: `npm run lint` (if available)
- [ ] **Check git diff** to ensure only intended changes

#### **Testing Checklist**
```bash
# Quick verification commands
npm run test:smoke                    # Run smoke tests
./scripts/health-check.sh -v         # Check application health
npm run test:auth                     # Test authentication if affected
```

#### **Manual Testing Steps**
1. **Login/Authentication** - Verify login still works
2. **Core Navigation** - Check main menu and routing
3. **Affected Feature** - Test the specific feature changed
4. **Related Features** - Test features that might be impacted
5. **Mobile Responsiveness** - Check on mobile viewport
6. **Browser Console** - Ensure no new errors

### Major Changes Checklist (New features, architectural changes)

#### **Planning Phase**
- [ ] **Create detailed design document**
- [ ] **Review with team/stakeholders**
- [ ] **Plan database migrations** if needed
- [ ] **Identify breaking changes**
- [ ] **Plan rollback strategy**

#### **Development Phase**
- [ ] **Create feature branch** with descriptive name
- [ ] **Implement backend changes** first
- [ ] **Write comprehensive tests** (unit + integration)
- [ ] **Implement frontend changes**
- [ ] **Add E2E tests** for new user flows
- [ ] **Update API documentation**

#### **Pre-Deployment Testing**
- [ ] **Run full test suite**: `npm test`
- [ ] **Performance testing** - Check for regressions
- [ ] **Security review** - Check for vulnerabilities
- [ ] **Database migration testing** on staging
- [ ] **Cross-browser compatibility** testing
- [ ] **Mobile device testing**
- [ ] **Load testing** if applicable

#### **Full Test Suite Commands**
```bash
# Complete testing workflow
npm test                              # Run all tests
npm run test:chrome                   # Chrome compatibility
npm run test:firefox                  # Firefox compatibility
npm run test:mobile                   # Mobile compatibility
./scripts/health-check.sh -j          # Health check with JSON output
./scripts/run-tests.sh -s all -r      # Full test suite with report
```

#### **Performance Testing**
```bash
# Check application performance
npm run test:performance              # If available
lighthouse https://ai.swargfood.com/task/ --output=json --output-path=./performance-report.json
```

#### **Security Review Checklist**
- [ ] **Input validation** on all new endpoints
- [ ] **Authentication checks** on protected routes
- [ ] **Authorization verification** for user actions
- [ ] **SQL injection prevention** (using Prisma helps)
- [ ] **XSS prevention** in frontend
- [ ] **CSRF protection** if needed
- [ ] **Rate limiting** on new endpoints
- [ ] **Sensitive data handling** (passwords, tokens)

#### **Database Migration Testing**
```bash
# Test migrations on staging
cd backend

# Backup current database
pg_dump $STAGING_DATABASE_URL > backup.sql

# Run migration
npx prisma migrate deploy

# Test application functionality
npm run test:api

# If issues, rollback
psql $STAGING_DATABASE_URL < backup.sql
```

#### **Documentation Updates**
- [ ] **API documentation** updated
- [ ] **README.md** updated if needed
- [ ] **Environment variables** documented
- [ ] **Deployment notes** added
- [ ] **Breaking changes** documented

---

## 7. Deployment and Monitoring

### How to Use Deployment Scripts

#### **Quick Deployment**
```bash
# Deploy main branch to production
./scripts/deploy.sh

# Deploy specific branch
./scripts/deploy.sh --branch develop

# Deploy without running tests (not recommended)
./scripts/deploy.sh --skip-tests

# Deploy without restarting services
./scripts/deploy.sh --no-restart
```

#### **Deployment Script Options**
```bash
./scripts/deploy.sh [OPTIONS]

Options:
  -b, --branch BRANCH   Git branch to deploy (default: main)
  -t, --skip-tests      Skip running tests before deployment
  -s, --skip-backup     Skip creating backup before deployment
  -n, --no-restart      Don't restart services after deployment
  -h, --help            Show help message
```

#### **Pre-Deployment Checklist**
```bash
# 1. Run tests locally
npm test

# 2. Check application health
./scripts/health-check.sh -v

# 3. Verify database migrations
cd backend && npx prisma migrate status

# 4. Check for uncommitted changes
git status

# 5. Deploy
./scripts/deploy.sh
```

### Health Monitoring Procedures

#### **Manual Health Checks**
```bash
# Basic health check
./scripts/health-check.sh

# Detailed health check with verbose output
./scripts/health-check.sh -v

# JSON output for automation/monitoring
./scripts/health-check.sh -j

# Custom timeout (default: 10 seconds)
./scripts/health-check.sh -t 30
```

#### **Continuous Monitoring**
```bash
# Start continuous monitoring (60-second intervals)
./scripts/monitor.sh

# Custom monitoring interval (30 seconds)
./scripts/monitor.sh -i 30

# Set alert threshold (3 consecutive failures)
./scripts/monitor.sh -t 3

# With Slack notifications
./scripts/monitor.sh -w https://hooks.slack.com/your-webhook-url

# Custom log file
./scripts/monitor.sh -l /var/log/swargfood-monitor.log
```

#### **Health Check Endpoints**
- **Application Health**: `https://ai.swargfood.com/task/health`
- **API Status**: `https://ai.swargfood.com/task/api`
- **Frontend**: `https://ai.swargfood.com/task/`

#### **Monitoring Dashboard Setup**
```bash
# Set up monitoring with alerts
./scripts/monitor.sh \
  --interval 60 \
  --threshold 3 \
  --webhook "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK" \
  --log "/var/log/swargfood-monitor.log"
```

### Rollback Procedures for Failed Deployments

#### **Automatic Rollback (if deployment fails)**
The deployment script automatically creates backups and can rollback on failure:

```bash
# The deploy script automatically:
# 1. Creates backup before deployment
# 2. Runs health checks after deployment
# 3. Rolls back if health checks fail
```

#### **Manual Rollback Process**
```bash
# 1. Stop current application
pm2 stop swargfood-task-management

# 2. Restore from backup
cd /var/www/task
sudo tar -xzf /var/backups/swargfood/swargfood_backup_TIMESTAMP.tar.gz

# 3. Restore database (if needed)
psql $DATABASE_URL < /var/backups/swargfood/database_backup_TIMESTAMP.sql

# 4. Restart application
pm2 start swargfood-task-management

# 5. Verify health
./scripts/health-check.sh -v
```

#### **Git-based Rollback**
```bash
# 1. Find the last working commit
git log --oneline -10

# 2. Reset to previous working state
git reset --hard PREVIOUS_COMMIT_HASH

# 3. Force push (be careful!)
git push --force-with-lease origin main

# 4. Redeploy
./scripts/deploy.sh
```

#### **Service-level Rollback**
```bash
# 1. Check PM2 process status
pm2 status

# 2. Restart specific service
pm2 restart swargfood-task-management

# 3. Check logs for issues
pm2 logs swargfood-task-management --lines 50

# 4. If issues persist, restore from backup
sudo systemctl stop nginx
# Restore files and database
sudo systemctl start nginx
```

---

## 8. Common Issues and Solutions

### Known Bugs and Workarounds

#### **Flutter Web Routing Issues**
**Problem**: App shows blank page or incorrect routes after authentication
**Solution**:
```dart
// Ensure proper route guards are implemented
class AuthGuard extends StatefulWidget {
  // Implementation in main.dart
}

// Clear browser cache and rebuild
flutter clean
flutter build web --release --base-href="/task/"
```

#### **CORS Issues in Development**
**Problem**: API calls blocked by CORS policy
**Solution**:
```javascript
// Backend: Ensure CORS is properly configured in app.js
app.use(cors({
  origin: function (origin, callback) {
    // Allow localhost and production domains
  }
}));

// Frontend: Use proper API base URL
const API_BASE_URL = process.env.NODE_ENV === 'production'
  ? 'https://ai.swargfood.com/task/api'
  : 'http://localhost:3003/task/api';
```

#### **Database Connection Issues**
**Problem**: "Connection refused" or timeout errors
**Solution**:
```bash
# Check database status
sudo systemctl status postgresql

# Check connection string
echo $DATABASE_URL

# Test connection
psql $DATABASE_URL -c "SELECT 1;"

# Restart database if needed
sudo systemctl restart postgresql
```

#### **PM2 Process Issues**
**Problem**: Application not starting or crashing
**Solution**:
```bash
# Check PM2 status
pm2 status

# View logs
pm2 logs swargfood-task-management

# Restart process
pm2 restart swargfood-task-management

# If still failing, check environment
pm2 env 0

# Delete and recreate process
pm2 delete swargfood-task-management
pm2 start ecosystem.config.js --env production
```

### Troubleshooting Guide for Development Issues

#### **Backend Development Issues**

**Issue**: "Module not found" errors
```bash
# Solution: Reinstall dependencies
cd backend
rm -rf node_modules package-lock.json
npm install
```

**Issue**: Database migration errors
```bash
# Solution: Reset and recreate migrations
npx prisma migrate reset
npx prisma migrate dev --name init
npx prisma db seed
```

**Issue**: JWT token errors
```bash
# Solution: Check environment variables
echo $JWT_SECRET
# Regenerate secret if needed
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
```

#### **Frontend Development Issues**

**Issue**: Flutter build errors
```bash
# Solution: Clean and rebuild
flutter clean
flutter pub get
flutter pub upgrade
flutter build web
```

**Issue**: Provider state not updating
```dart
// Solution: Ensure notifyListeners() is called
class MyProvider with ChangeNotifier {
  void updateData() {
    // Update data
    notifyListeners(); // Don't forget this!
  }
}
```

**Issue**: API calls failing
```dart
// Solution: Check API service configuration
class ApiService {
  static const String baseUrl = 'https://ai.swargfood.com/task/api';

  static Future<http.Response> get(String endpoint) async {
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    return response;
  }
}
```

#### **Testing Issues**

**Issue**: Playwright tests timing out
```javascript
// Solution: Increase timeouts and add better waits
test('should load page', async ({ page }) => {
  test.setTimeout(60000); // Increase timeout

  await page.goto('/task/');
  await page.waitForLoadState('networkidle'); // Better wait
  await page.waitForSelector('[data-testid="main-content"]'); // Wait for specific element
});
```

**Issue**: Tests failing in CI but passing locally
```bash
# Solution: Check environment differences
# 1. Ensure same Node.js version
# 2. Install dependencies in CI
npm ci
npx playwright install --with-deps

# 3. Use headless mode in CI
npx playwright test --project=chromium
```

### Performance Optimization Tips

#### **Backend Performance**

**Database Query Optimization**:
```javascript
// Use includes for related data
const projects = await prisma.project.findMany({
  include: {
    tasks: {
      select: { id: true, title: true, status: true } // Select only needed fields
    },
    members: {
      include: { user: { select: { id: true, name: true } } }
    }
  }
});

// Use pagination for large datasets
const tasks = await prisma.task.findMany({
  skip: (page - 1) * limit,
  take: limit,
  orderBy: { createdAt: 'desc' }
});

// Use database indexes
// Add to schema.prisma:
// @@index([status, projectId])
```

**API Response Optimization**:
```javascript
// Implement response caching
const cache = new Map();

app.get('/api/projects', (req, res) => {
  const cacheKey = `projects_${req.user.id}`;

  if (cache.has(cacheKey)) {
    return res.json(cache.get(cacheKey));
  }

  // Fetch data and cache
  const projects = await getProjects(req.user.id);
  cache.set(cacheKey, projects);

  res.json(projects);
});
```

#### **Frontend Performance**

**Widget Optimization**:
```dart
// Use const constructors
class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return const Card( // Use const when possible
      child: ListTile(
        title: Text('Task Title'),
      ),
    );
  }
}

// Use ListView.builder for large lists
ListView.builder(
  itemCount: tasks.length,
  itemBuilder: (context, index) {
    return TaskCard(task: tasks[index]);
  },
);
```

**State Management Optimization**:
```dart
// Use Selector for specific updates
Selector<TaskProvider, List<Task>>(
  selector: (context, provider) => provider.activeTasks,
  builder: (context, activeTasks, child) {
    return ListView.builder(
      itemCount: activeTasks.length,
      itemBuilder: (context, index) {
        return TaskCard(task: activeTasks[index]);
      },
    );
  },
);
```

**Image and Asset Optimization**:
```dart
// Use cached network images
CachedNetworkImage(
  imageUrl: user.profilePicture,
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.error),
);

// Optimize asset loading
Image.asset(
  'assets/images/logo.png',
  cacheWidth: 200, // Specify cache dimensions
  cacheHeight: 200,
);
```

---

## 9. Integration Points

### External Services and APIs

#### **Database Integration (AWS RDS PostgreSQL)**
```javascript
// Connection configuration
const DATABASE_URL = process.env.DATABASE_URL;
// Format: postgresql://username:password@host:port/database

// Connection pooling (handled by Prisma)
const prisma = new PrismaClient({
  datasources: {
    db: {
      url: DATABASE_URL,
    },
  },
});
```

#### **Email Service Integration**
```javascript
// Email service configuration (nodemailer)
const emailConfig = {
  host: process.env.SMTP_HOST,
  port: process.env.SMTP_PORT,
  secure: false,
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
};

// Send notification email
const sendNotificationEmail = async (to, subject, content) => {
  const transporter = nodemailer.createTransporter(emailConfig);

  await transporter.sendMail({
    from: process.env.SMTP_USER,
    to,
    subject,
    html: content,
  });
};
```

#### **File Storage Integration**
```javascript
// Local file storage configuration
const multer = require('multer');

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, process.env.UPLOAD_PATH || './uploads');
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({
  storage,
  limits: { fileSize: process.env.MAX_FILE_SIZE || 10485760 } // 10MB
});
```

### Authentication Flow Details

#### **JWT Token Authentication**
```javascript
// Token generation (backend)
const generateToken = (user) => {
  return jwt.sign(
    {
      id: user.id,
      email: user.email,
      role: user.role
    },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
  );
};

// Token verification middleware
const auth = async (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');

    if (!token) {
      return res.status(401).json({ error: 'Access denied. No token provided.' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const user = await prisma.user.findUnique({ where: { id: decoded.id } });

    if (!user || !user.isActive) {
      return res.status(401).json({ error: 'Invalid token.' });
    }

    req.user = user;
    next();
  } catch (error) {
    res.status(401).json({ error: 'Invalid token.' });
  }
};
```

#### **Frontend Authentication Flow**
```dart
// AuthProvider implementation
class AuthProvider with ChangeNotifier {
  User? _user;
  String? _token;
  bool _isLoading = true;

  // Login method
  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _token = data['token'];
        _user = User.fromJson(data['user']);

        // Store token securely
        await _storeToken(_token!);

        notifyListeners();
        return true;
      }
      return false;
    } catch (error) {
      return false;
    }
  }

  // Token storage
  Future<void> _storeToken(String token) async {
    const storage = FlutterSecureStorage();
    await storage.write(key: 'auth_token', value: token);
  }

  // Load token on app start
  Future<void> loadTokenFromStorage() async {
    const storage = FlutterSecureStorage();
    _token = await storage.read(key: 'auth_token');

    if (_token != null) {
      // Verify token with backend
      final isValid = await _verifyToken(_token!);
      if (!isValid) {
        await logout();
      }
    }

    _isLoading = false;
    notifyListeners();
  }
}
```

### Real-time Features (WebSocket Connections)

#### **Backend Socket.IO Setup**
```javascript
// Socket.IO server setup
const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');

const initializeSocket = (server) => {
  const io = new Server(server, {
    cors: {
      origin: process.env.FRONTEND_URL || "http://localhost:3000",
      methods: ["GET", "POST"]
    }
  });

  // Authentication middleware for sockets
  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth.token;
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      const user = await prisma.user.findUnique({ where: { id: decoded.id } });

      if (user) {
        socket.userId = user.id;
        socket.user = user;
        next();
      } else {
        next(new Error('Authentication error'));
      }
    } catch (error) {
      next(new Error('Authentication error'));
    }
  });

  // Connection handling
  io.on('connection', (socket) => {
    console.log(`User ${socket.user.name} connected`);

    // Join user to their personal room
    socket.join(`user_${socket.userId}`);

    // Join user to project rooms
    socket.on('join_project', (projectId) => {
      socket.join(`project_${projectId}`);
    });

    // Handle chat messages
    socket.on('send_message', async (data) => {
      const message = await createChatMessage(data);
      io.to(`project_${data.projectId}`).emit('new_message', message);
    });

    // Handle task updates
    socket.on('task_updated', (data) => {
      socket.to(`project_${data.projectId}`).emit('task_updated', data);
    });

    // Handle disconnection
    socket.on('disconnect', () => {
      console.log(`User ${socket.user.name} disconnected`);
    });
  });

  return io;
};
```

#### **Frontend Socket Integration**
```dart
// Socket service implementation
class SocketService {
  static IO.Socket? _socket;
  static bool _isConnected = false;

  static Future<void> connect(String token) async {
    try {
      _socket = IO.io('https://ai.swargfood.com', <String, dynamic>{
        'transports': ['websocket'],
        'auth': {'token': token},
      });

      _socket!.onConnect((_) {
        print('Connected to server');
        _isConnected = true;
      });

      _socket!.onDisconnect((_) {
        print('Disconnected from server');
        _isConnected = false;
      });

      // Listen for real-time updates
      _socket!.on('task_updated', (data) {
        // Update task in provider
        final taskProvider = Get.find<TaskProvider>();
        taskProvider.updateTaskFromSocket(data);
      });

      _socket!.on('new_message', (data) {
        // Update chat in provider
        final chatProvider = Get.find<ChatProvider>();
        chatProvider.addMessageFromSocket(data);
      });

    } catch (error) {
      print('Socket connection error: $error');
    }
  }

  static void joinProject(String projectId) {
    if (_isConnected) {
      _socket!.emit('join_project', projectId);
    }
  }

  static void sendMessage(Map<String, dynamic> messageData) {
    if (_isConnected) {
      _socket!.emit('send_message', messageData);
    }
  }

  static void disconnect() {
    _socket?.disconnect();
    _isConnected = false;
  }
}
```

#### **Real-time Update Patterns**
```dart
// Provider pattern for real-time updates
class TaskProvider with ChangeNotifier {
  List<Task> _tasks = [];

  // Update task from socket event
  void updateTaskFromSocket(Map<String, dynamic> data) {
    final updatedTask = Task.fromJson(data);
    final index = _tasks.indexWhere((task) => task.id == updatedTask.id);

    if (index != -1) {
      _tasks[index] = updatedTask;
      notifyListeners();
    }
  }

  // Send task update to other users
  Future<void> updateTask(Task task) async {
    // Update via API
    await ApiService.updateTask(task);

    // Emit socket event for real-time update
    SocketService.emit('task_updated', {
      'taskId': task.id,
      'projectId': task.projectId,
      'updates': task.toJson(),
    });

    // Update local state
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = task;
      notifyListeners();
    }
  }
}
```

---

## Conclusion

This developer handover document provides comprehensive guidance for working with the SwargFood Task Management application. The system is built with modern technologies and follows best practices for scalability, maintainability, and performance.

### Key Takeaways for New Developers

1. **Follow the established patterns** for consistency
2. **Write tests** for all new features
3. **Use the provided scripts** for deployment and monitoring
4. **Check the QA checklists** before deploying changes
5. **Monitor application health** regularly
6. **Document any new features** or changes

### Getting Help

- **Documentation**: Check the `docs/` directory for detailed guides
- **Testing**: Use the comprehensive test suite for validation
- **Monitoring**: Use health check scripts for diagnostics
- **Issues**: Refer to the troubleshooting section for common problems

### Next Steps

1. **Set up your development environment** following section 2
2. **Run the test suite** to ensure everything works
3. **Make a small change** to familiarize yourself with the workflow
4. **Review the codebase** using the navigation guide in section 3

The application is production-ready and actively maintained. Follow the guidelines in this document to ensure continued quality and reliability.

---

**Happy coding! 🚀**
