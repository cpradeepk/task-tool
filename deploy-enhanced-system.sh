#!/bin/bash

# Enhanced Project Management System - Automated Deployment Script
# Execute this script on the ai.swargfood.com server to deploy all enhanced features

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="/var/www/task"
BACKUP_DIR="/var/backups/task-management"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root or with sudo"
fi

echo "🚀 Enhanced Project Management System Deployment"
echo "=============================================="
echo "Deploying to: $PROJECT_ROOT"
echo "Backup location: $BACKUP_DIR"
echo "Timestamp: $TIMESTAMP"
echo ""

# Step 1: Create backup
log "Creating system backup..."
mkdir -p "$BACKUP_DIR"
tar -czf "$BACKUP_DIR/enhanced-backup-$TIMESTAMP.tar.gz" \
    -C "$PROJECT_ROOT" \
    --exclude="node_modules" \
    --exclude=".git" \
    --exclude="build" \
    --exclude="logs" \
    . || error "Failed to create backup"

success "Backup created: $BACKUP_DIR/enhanced-backup-$TIMESTAMP.tar.gz"

# Step 2: Stop services
log "Stopping services..."
systemctl stop task-management-backend || warning "Backend service not running"
systemctl stop nginx || error "Failed to stop nginx"

# Step 3: Verify enhanced files are in place
log "Verifying enhanced files..."
cd "$PROJECT_ROOT"

# Check backend controllers
BACKEND_CONTROLLERS=(
    "backend/src/controllers/projectAssignmentController.js"
    "backend/src/controllers/enhancedModuleController.js"
    "backend/src/controllers/priorityController.js"
    "backend/src/controllers/timelineController.js"
)

for controller in "${BACKEND_CONTROLLERS[@]}"; do
    if [ -f "$controller" ]; then
        success "Found: $controller"
    else
        error "Missing: $controller"
    fi
done

# Check backend routes
BACKEND_ROUTES=(
    "backend/src/routes/projectAssignmentRoutes.js"
    "backend/src/routes/enhancedModuleRoutes.js"
    "backend/src/routes/priorityRoutes.js"
    "backend/src/routes/timelineRoutes.js"
)

for route in "${BACKEND_ROUTES[@]}"; do
    if [ -f "$route" ]; then
        success "Found: $route"
    else
        error "Missing: $route"
    fi
done

# Check migration
if [ -f "backend/prisma/migrations/20250127_enhanced_project_management/migration.sql" ]; then
    success "Found: Enhanced project management migration"
else
    error "Missing: Enhanced project management migration"
fi

# Check frontend components
FRONTEND_COMPONENTS=(
    "frontend/lib/widgets/project_assignment_modal.dart"
    "frontend/lib/widgets/module_manager.dart"
    "frontend/lib/widgets/priority_editor.dart"
    "frontend/lib/widgets/timeline_view.dart"
    "frontend/lib/screens/enhanced_project_details_screen.dart"
)

for component in "${FRONTEND_COMPONENTS[@]}"; do
    if [ -f "$component" ]; then
        success "Found: $component"
    else
        error "Missing: $component"
    fi
done

# Step 4: Database migration
log "Running database migration..."
cd "$PROJECT_ROOT/backend"

# Install dependencies
log "Installing backend dependencies..."
npm ci || error "Failed to install backend dependencies"

# Run migration
log "Applying enhanced project management migration..."
npx prisma migrate deploy || error "Database migration failed"

# Generate Prisma client
log "Generating Prisma client..."
npx prisma generate || error "Prisma client generation failed"

success "Database migration completed"

# Step 5: Verify app.js has new routes
log "Verifying app.js configuration..."
if grep -q "projectAssignmentRoutes" src/app.js; then
    success "Project assignment routes registered"
else
    error "Project assignment routes not found in app.js"
fi

if grep -q "enhancedModuleRoutes" src/app.js; then
    success "Enhanced module routes registered"
else
    error "Enhanced module routes not found in app.js"
fi

if grep -q "priorityRoutes" src/app.js; then
    success "Priority routes registered"
else
    error "Priority routes not found in app.js"
fi

if grep -q "timelineRoutes" src/app.js; then
    success "Timeline routes registered"
else
    error "Timeline routes not found in app.js"
fi

# Step 6: Frontend deployment
log "Deploying frontend..."
cd "$PROJECT_ROOT/frontend"

# Install dependencies
log "Installing frontend dependencies..."
flutter pub get || error "Failed to install frontend dependencies"

# Build application
log "Building Flutter application..."
flutter build web --release \
    --dart-define=API_BASE_URL=https://ai.swargfood.com/task/api \
    --dart-define=SOCKET_URL=https://ai.swargfood.com/task \
    --web-renderer=html || error "Flutter build failed"

# Deploy built files
log "Deploying built files..."
cp -r build/web/* "$PROJECT_ROOT/frontend/web/" || error "Failed to copy built files"
chown -R www-data:www-data "$PROJECT_ROOT/frontend/web/" || error "Failed to set permissions"

success "Frontend deployment completed"

# Step 7: Start services
log "Starting services..."
systemctl start task-management-backend || error "Failed to start backend service"
systemctl start nginx || error "Failed to start nginx"

# Enable services
systemctl enable task-management-backend || warning "Failed to enable backend service"
systemctl enable nginx || warning "Failed to enable nginx"

success "Services started"

# Step 8: Health checks
log "Performing health checks..."
sleep 10

# Check backend
log "Checking backend health..."
if curl -f -s "https://ai.swargfood.com/task/api" > /dev/null; then
    success "Backend is responding"
else
    error "Backend health check failed"
fi

# Check frontend
log "Checking frontend accessibility..."
if curl -f -s "https://ai.swargfood.com/task/" > /dev/null; then
    success "Frontend is accessible"
else
    error "Frontend health check failed"
fi

# Check new API endpoints
log "Checking enhanced API endpoints..."
ENDPOINTS=(
    "https://ai.swargfood.com/task/api/project-assignments"
    "https://ai.swargfood.com/task/api/enhanced-modules"
    "https://ai.swargfood.com/task/api/priority"
    "https://ai.swargfood.com/task/api/timeline"
)

for endpoint in "${ENDPOINTS[@]}"; do
    if curl -f -s "$endpoint" > /dev/null; then
        success "Endpoint available: $endpoint"
    else
        warning "Endpoint may require authentication: $endpoint"
    fi
done

# Step 9: Final verification
log "Performing final verification..."

# Check service status
if systemctl is-active --quiet task-management-backend; then
    success "Backend service is active"
else
    error "Backend service is not active"
fi

if systemctl is-active --quiet nginx; then
    success "Nginx service is active"
else
    error "Nginx service is not active"
fi

# Check for recent errors
log "Checking for recent errors..."
if journalctl -u task-management-backend --since "2 minutes ago" | grep -i error; then
    warning "Found errors in backend logs, please review"
else
    success "No recent errors in backend logs"
fi

# Step 10: Cleanup old backups
log "Cleaning up old backups..."
cd "$BACKUP_DIR"
ls -t enhanced-backup-*.tar.gz | tail -n +6 | xargs -r rm || true

success "Cleanup completed"

# Deployment summary
echo ""
echo "=============================================="
echo -e "${GREEN}🎉 ENHANCED DEPLOYMENT COMPLETE!${NC}"
echo "=============================================="
echo ""
echo "📊 Deployment Summary:"
echo "  ✅ System backup created"
echo "  ✅ Database migration applied"
echo "  ✅ Backend controllers deployed"
echo "  ✅ Frontend components deployed"
echo "  ✅ Services restarted"
echo "  ✅ Health checks passed"
echo ""
echo "🌐 Application URLs:"
echo "  • Frontend: https://ai.swargfood.com/task/"
echo "  • API: https://ai.swargfood.com/task/api"
echo ""
echo "🔧 Enhanced Features Now Available:"
echo "  • Role-based access control (Admin > Project Manager > User)"
echo "  • User assignment and project access management"
echo "  • Hierarchical project structure (Project → Module → Task)"
echo "  • Advanced priority management with dual-level system"
echo "  • Comprehensive time management with Gantt charts"
echo ""
echo "📋 New API Endpoints:"
echo "  • /task/api/project-assignments/* - User assignment management"
echo "  • /task/api/enhanced-modules/* - Module management"
echo "  • /task/api/priority/* - Priority management"
echo "  • /task/api/timeline/* - Timeline functionality"
echo ""
echo "🧪 Testing Checklist:"
echo "  1. Open https://ai.swargfood.com/task/"
echo "  2. Test user login and role-based access"
echo "  3. Create a project and assign users"
echo "  4. Create modules and organize tasks"
echo "  5. Test priority management workflow"
echo "  6. View timeline and Gantt charts"
echo ""
echo "📚 Documentation:"
echo "  • Enhanced features guide: docs/enhanced-project-management.md"
echo "  • Deployment guide: ENHANCED_DEPLOYMENT_GUIDE.md"
echo ""
echo "🔍 Monitoring Commands:"
echo "  • Backend logs: journalctl -u task-management-backend -f"
echo "  • Nginx logs: tail -f /var/log/nginx/access.log"
echo "  • Service status: systemctl status task-management-backend"
echo ""

success "Enhanced Project Management System is now live!"
echo "🚀 Ready for testing and production use!"

exit 0
