# Enhanced Project Management System - Deployment Guide

## 🚀 Complete Deployment Instructions

This guide will deploy the enhanced project management system to https://ai.swargfood.com/task/ with all advanced features.

## Prerequisites

- SSH access to ai.swargfood.com server
- Sudo privileges
- Node.js and npm installed
- Flutter SDK installed
- PostgreSQL database running

## Step 1: Connect to Server

```bash
ssh ubuntu@ai.swargfood.com
cd /var/www/task
```

## Step 2: Backup Current System

```bash
# Create backup directory
sudo mkdir -p /var/backups/task-management

# Create backup
sudo tar -czf /var/backups/task-management/backup-$(date +%Y%m%d_%H%M%S).tar.gz \
    --exclude="node_modules" \
    --exclude=".git" \
    --exclude="build" \
    /var/www/task

echo "✅ Backup created successfully"
```

## Step 3: Stop Services

```bash
# Stop backend service
sudo systemctl stop task-management-backend

# Stop nginx
sudo systemctl stop nginx

echo "✅ Services stopped"
```

## Step 4: Update Source Code

```bash
# Pull latest changes (if using git)
git pull origin main

# Or upload the enhanced files to the server
# Make sure all new files are in place:
# - backend/src/controllers/projectAssignmentController.js
# - backend/src/controllers/enhancedModuleController.js
# - backend/src/controllers/priorityController.js
# - backend/src/controllers/timelineController.js
# - backend/src/routes/projectAssignmentRoutes.js
# - backend/src/routes/enhancedModuleRoutes.js
# - backend/src/routes/priorityRoutes.js
# - backend/src/routes/timelineRoutes.js
# - backend/prisma/migrations/20250127_enhanced_project_management/migration.sql
# - frontend/lib/widgets/project_assignment_modal.dart
# - frontend/lib/widgets/module_manager.dart
# - frontend/lib/widgets/priority_editor.dart
# - frontend/lib/widgets/timeline_view.dart
# - frontend/lib/screens/enhanced_project_details_screen.dart

echo "✅ Source code updated"
```

## Step 5: Database Migration

```bash
cd /var/www/task/backend

# Install/update dependencies
npm ci

# Run Prisma migration
npx prisma migrate deploy

# Generate Prisma client
npx prisma generate

echo "✅ Database migration completed"
```

## Step 6: Backend Deployment

```bash
cd /var/www/task/backend

# Install production dependencies
npm ci --production

# Verify new routes are registered in app.js
grep -q "projectAssignmentRoutes" src/app.js && echo "✅ Project assignment routes found"
grep -q "enhancedModuleRoutes" src/app.js && echo "✅ Enhanced module routes found"
grep -q "priorityRoutes" src/app.js && echo "✅ Priority routes found"
grep -q "timelineRoutes" src/app.js && echo "✅ Timeline routes found"

echo "✅ Backend deployment completed"
```

## Step 7: Frontend Deployment

```bash
cd /var/www/task/frontend

# Install dependencies
flutter pub get

# Build for production
flutter build web --release \
    --dart-define=API_BASE_URL=https://ai.swargfood.com/task/api \
    --dart-define=SOCKET_URL=https://ai.swargfood.com/task \
    --web-renderer=html

# Deploy built files
sudo cp -r build/web/* /var/www/task/frontend/web/
sudo chown -R www-data:www-data /var/www/task/frontend/web/

echo "✅ Frontend deployment completed"
```

## Step 8: Start Services

```bash
# Start backend service
sudo systemctl start task-management-backend

# Start nginx
sudo systemctl start nginx

# Enable services
sudo systemctl enable task-management-backend
sudo systemctl enable nginx

echo "✅ Services started"
```

## Step 9: Health Checks

```bash
# Wait for services to start
sleep 10

# Check backend health
curl -f https://ai.swargfood.com/task/api && echo "✅ Backend responding"

# Check frontend
curl -f https://ai.swargfood.com/task/ && echo "✅ Frontend accessible"

# Check new API endpoints
curl -f https://ai.swargfood.com/task/api/project-assignments && echo "✅ Project assignments endpoint available"
curl -f https://ai.swargfood.com/task/api/enhanced-modules && echo "✅ Enhanced modules endpoint available"
curl -f https://ai.swargfood.com/task/api/priority && echo "✅ Priority endpoint available"
curl -f https://ai.swargfood.com/task/api/timeline && echo "✅ Timeline endpoint available"

echo "✅ Health checks completed"
```

## Step 10: Verify Enhanced Features

```bash
# Check service status
sudo systemctl status task-management-backend
sudo systemctl status nginx

# Check logs for errors
sudo journalctl -u task-management-backend --since "5 minutes ago" | grep -i error || echo "✅ No errors in backend logs"

echo "✅ Enhanced features verification completed"
```

## Step 11: Test Enhanced Features

1. **Open the application**: https://ai.swargfood.com/task/
2. **Test Google OAuth login** (if working)
3. **Test Role-Based Access**:
   - Admin users should see all management options
   - Project managers should see project management features
   - Regular users should have limited access

4. **Test Project Assignment**:
   - Create a project
   - Assign users to the project
   - Verify assignment history

5. **Test Module Management**:
   - Create modules within a project
   - Reorder modules using drag-and-drop
   - View module statistics

6. **Test Priority Management**:
   - Change priority of a project/task
   - Verify approval workflow for regular users
   - Check priority change history

7. **Test Timeline Features**:
   - View project timeline
   - Check Gantt chart visualization
   - Verify critical path analysis

## Troubleshooting

### If Backend Fails to Start
```bash
# Check logs
sudo journalctl -u task-management-backend -f

# Check if port is in use
sudo netstat -tlnp | grep :3003

# Restart service
sudo systemctl restart task-management-backend
```

### If Frontend Doesn't Load
```bash
# Check nginx configuration
sudo nginx -t

# Check nginx logs
sudo tail -f /var/log/nginx/error.log

# Restart nginx
sudo systemctl restart nginx
```

### If Database Migration Fails
```bash
cd /var/www/task/backend

# Check database connection
npx prisma db pull

# Reset and reapply migrations (CAUTION: This will lose data)
# npx prisma migrate reset --force
# npx prisma migrate deploy
```

### If API Endpoints Return 404
```bash
# Verify routes are properly registered
grep -n "project-assignments" /var/www/task/backend/src/app.js
grep -n "enhanced-modules" /var/www/task/backend/src/app.js
grep -n "priority" /var/www/task/backend/src/app.js
grep -n "timeline" /var/www/task/backend/src/app.js

# Restart backend service
sudo systemctl restart task-management-backend
```

## Success Verification

After deployment, you should have:

✅ **Enhanced Project Management Features**:
- Role-based access control working
- User assignment interface functional
- Module management with drag-and-drop
- Priority management with approval workflow
- Timeline visualization with Gantt charts

✅ **New API Endpoints**:
- `/task/api/project-assignments/*` - User assignment management
- `/task/api/enhanced-modules/*` - Module management
- `/task/api/priority/*` - Priority management
- `/task/api/timeline/*` - Timeline functionality

✅ **Database Schema**:
- New tables for enhanced functionality
- Proper foreign key relationships
- Migration applied successfully

✅ **Frontend Components**:
- ProjectAssignmentModal for user management
- ModuleManager for hierarchical organization
- PriorityEditor for advanced priority setting
- TimelineView for Gantt chart visualization

## Post-Deployment

1. **Monitor logs** for any errors:
   ```bash
   sudo journalctl -u task-management-backend -f
   tail -f /var/log/nginx/access.log
   ```

2. **Test all functionality** with different user roles

3. **Create documentation** for end users on new features

4. **Set up monitoring** for the new endpoints

## Support

If you encounter any issues during deployment:

1. Check the logs first
2. Verify all files are in the correct locations
3. Ensure database migration completed successfully
4. Test API endpoints individually
5. Check frontend build for any errors

The enhanced project management system should now be fully functional at https://ai.swargfood.com/task/ with all advanced features operational!
