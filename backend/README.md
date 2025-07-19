# Task Management Backend

## Prerequisites

- Node.js 18+ 
- PostgreSQL 14+
- Google Cloud Project with Drive API enabled
- Google Service Account with Drive API access

## Setup Instructions

### 1. Environment Configuration

```bash
# Copy environment template
cp .env.example .env

# Edit .env with your configuration
```

### 2. Google Drive API Setup

1. Create a Google Cloud Project
2. Enable Google Drive API
3. Create a Service Account
4. Download service account key JSON file
5. Place the key file in `backend/config/service-account-key.json`
6. Create a shared Google Drive folder
7. Share the folder with your service account email (with Editor permissions)
8. Copy the folder ID from the URL and set it in `GOOGLE_DRIVE_ROOT_FOLDER_ID`

### 3. Database Setup

```bash
# Install dependencies
npm install

# Generate Prisma client
npx prisma generate

# Run database migrations
npx prisma migrate dev --name init

# (Optional) Seed database
npx prisma db seed
```

### 4. Start Development Server

```bash
# Development mode with auto-reload
npm run dev

# Production mode
npm start
```

## API Documentation

Once the server is running, visit:
- Swagger UI: `http://localhost:3000/api-docs`
- Health Check: `http://localhost:3000/health`

## Project Structure

```
backend/
├── src/
│   ├── config/          # Configuration files
│   │   ├── database.js  # Prisma database configuration
│   │   ├── googleDrive.js # Google Drive service
│   │   └── logger.js    # Winston logger configuration
│   ├── controllers/     # Route controllers
│   │   ├── authController.js
│   │   ├── userController.js
│   │   ├── projectController.js
│   │   ├── taskController.js
│   │   └── fileController.js
│   ├── middleware/      # Express middleware
│   │   ├── auth.js      # Authentication middleware
│   │   ├── errorHandler.js
│   │   ├── upload.js    # File upload middleware
│   │   └── validation.js
│   ├── routes/          # API routes
│   │   ├── auth.js
│   │   ├── users.js
│   │   ├── projects.js
│   │   ├── tasks.js
│   │   └── files.js
│   ├── app.js           # Express app configuration
│   └── server.js        # Server entry point
├── prisma/
│   ├── schema.prisma    # Database schema
│   └── seed.js          # Database seeding
├── logs/                # Application logs
├── config/              # Configuration files
├── .env.example         # Environment variables template
├── package.json
└── README.md
```

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `DATABASE_URL` | PostgreSQL connection string | Yes |
| `JWT_SECRET` | Secret for JWT token signing | Yes |
| `JWT_REFRESH_SECRET` | Secret for refresh token signing | Yes |
| `GOOGLE_CLIENT_ID` | Google OAuth client ID | Yes |
| `GOOGLE_CLIENT_SECRET` | Google OAuth client secret | Yes |
| `GOOGLE_SERVICE_ACCOUNT_KEY_FILE` | Path to service account key | Yes |
| `GOOGLE_DRIVE_ROOT_FOLDER_ID` | Shared Drive folder ID | Yes |
| `PORT` | Server port (default: 3000) | No |
| `NODE_ENV` | Environment (development/production) | No |

## Testing

```bash
# Run tests
npm test

# Run tests with coverage
npm run test:coverage
```

## API Endpoints

### Authentication
- `POST /api/auth/google` - Google OAuth login
- `POST /api/auth/refresh` - Refresh access token

### Users
- `GET /api/users/profile` - Get current user profile
- `PUT /api/users/profile` - Update user profile
- `GET /api/users` - Get all users (admin only)
- `PATCH /api/users/:id/toggle-status` - Toggle user status (admin only)

### Projects
- `POST /api/projects` - Create project
- `GET /api/projects` - Get user's projects
- `GET /api/projects/:id` - Get project details
- `PUT /api/projects/:id` - Update project
- `DELETE /api/projects/:id` - Delete project
- `POST /api/projects/:id/members` - Add project member
- `DELETE /api/projects/:id/members/:memberId` - Remove project member

### Tasks
- `POST /api/tasks` - Create task
- `GET /api/tasks` - Get tasks
- `GET /api/tasks/:id` - Get task details
- `PUT /api/tasks/:id` - Update task
- `DELETE /api/tasks/:id` - Delete task
- `POST /api/tasks/:id/comments` - Add task comment
- `POST /api/tasks/:id/time-entries` - Add time entry

### Files
- `POST /api/files/profile-picture` - Upload profile picture
- `POST /api/files/task-attachment` - Upload task attachment
- `GET /api/files/:id/download` - Download file
- `DELETE /api/files/:id` - Delete file
- `GET /api/files/user/:userId` - Get user files

## Development

```bash
# Start development server with auto-reload
npm run dev

# Run database migrations
npm run migrate

# Reset database
npm run db:reset

# Generate Prisma client
npm run generate

# Lint code
npm run lint

# Fix linting issues
npm run lint:fix
```

## Production Deployment

1. Set `NODE_ENV=production`
2. Configure production database
3. Set up Google Drive service account
4. Run production migrations: `npm run migrate:prod`
5. Start server: `npm start`

## Troubleshooting

### Common Issues

1. **Database connection failed**
   - Check PostgreSQL is running
   - Verify DATABASE_URL is correct
   - Ensure database exists

2. **Google Drive API errors**
   - Verify service account key file exists
   - Check Google Drive folder permissions
   - Ensure API is enabled in Google Cloud Console

3. **JWT token errors**
   - Verify JWT_SECRET is set
   - Check token expiration
   - Ensure refresh token is valid

### Logs

Application logs are stored in the `logs/` directory:
- `combined.log` - All logs
- `error.log` - Error logs only

Set `LOG_LEVEL` environment variable to control logging verbosity.
