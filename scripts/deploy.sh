#!/bin/bash

# SwargFood Task Management - Deployment Script
# Automated deployment script for server updates

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVER_USER="ubuntu"
SERVER_HOST="ip-172-26-1-195"
APP_DIR="/var/www/task"
BACKUP_DIR="/var/backups/swargfood"

# Default values
BRANCH="main"
SKIP_TESTS=false
SKIP_BACKUP=false
RESTART_SERVICES=true

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -b, --branch BRANCH   Git branch to deploy (default: main)"
    echo "  -t, --skip-tests      Skip running tests before deployment"
    echo "  -s, --skip-backup     Skip creating backup before deployment"
    echo "  -n, --no-restart      Don't restart services after deployment"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -b develop"
    echo "  $0 --skip-tests --no-restart"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--branch)
            BRANCH="$2"
            shift 2
            ;;
        -t|--skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        -s|--skip-backup)
            SKIP_BACKUP=true
            shift
            ;;
        -n|--no-restart)
            RESTART_SERVICES=false
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option $1"
            usage
            exit 1
            ;;
    esac
done

echo -e "${BLUE}🚀 SwargFood Task Management Deployment${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo -e "  Branch: ${GREEN}$BRANCH${NC}"
echo -e "  Skip Tests: ${GREEN}$SKIP_TESTS${NC}"
echo -e "  Skip Backup: ${GREEN}$SKIP_BACKUP${NC}"
echo -e "  Restart Services: ${GREEN}$RESTART_SERVICES${NC}"
echo ""

# Pre-deployment tests
if [ "$SKIP_TESTS" = false ]; then
    echo -e "${YELLOW}Running pre-deployment tests...${NC}"
    
    if ! npm test; then
        echo -e "${RED}❌ Tests failed! Deployment aborted.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ All tests passed!${NC}"
fi

# Create deployment script for server
DEPLOY_SCRIPT=$(cat << 'EOF'
#!/bin/bash

set -e

APP_DIR="/var/www/task"
BACKUP_DIR="/var/backups/swargfood"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "🔄 Starting deployment on server..."

# Create backup directory
sudo mkdir -p $BACKUP_DIR

# Backup current application (if not skipped)
if [ "$1" != "skip-backup" ]; then
    echo "📦 Creating backup..."
    sudo tar -czf $BACKUP_DIR/swargfood_backup_$TIMESTAMP.tar.gz -C $APP_DIR .
    echo "✅ Backup created: $BACKUP_DIR/swargfood_backup_$TIMESTAMP.tar.gz"
fi

# Navigate to application directory
cd $APP_DIR

# Stash any local changes
git stash

# Pull latest changes
echo "📥 Pulling latest changes from $2..."
git fetch origin
git checkout $2
git pull origin $2

# Update backend dependencies
echo "📦 Updating backend dependencies..."
cd backend
npm install --production

# Run database migrations
echo "🗄️ Running database migrations..."
npx prisma migrate deploy

# Generate Prisma client
npx prisma generate

# Build frontend
echo "🏗️ Building frontend..."
cd ../frontend
flutter build web --release --base-href="/task/"

# Restart services (if not skipped)
if [ "$3" = "restart" ]; then
    echo "🔄 Restarting services..."
    
    # Restart PM2 processes
    pm2 restart swargfood-task-management
    
    # Reload nginx
    sudo systemctl reload nginx
    
    echo "✅ Services restarted"
fi

# Health check
echo "🏥 Performing health check..."
sleep 5

if curl -f http://localhost:3003/task/health > /dev/null 2>&1; then
    echo "✅ Health check passed"
else
    echo "❌ Health check failed"
    exit 1
fi

echo "🎉 Deployment completed successfully!"
EOF
)

# Copy deployment script to server and execute
echo -e "${YELLOW}Deploying to server...${NC}"

# Prepare deployment parameters
BACKUP_PARAM="backup"
if [ "$SKIP_BACKUP" = true ]; then
    BACKUP_PARAM="skip-backup"
fi

RESTART_PARAM="no-restart"
if [ "$RESTART_SERVICES" = true ]; then
    RESTART_PARAM="restart"
fi

# Execute deployment on server
echo "$DEPLOY_SCRIPT" | ssh $SERVER_USER@$SERVER_HOST "cat > /tmp/deploy.sh && chmod +x /tmp/deploy.sh && /tmp/deploy.sh $BACKUP_PARAM $BRANCH $RESTART_PARAM"

# Post-deployment verification
echo -e "${YELLOW}Verifying deployment...${NC}"

# Test application endpoints
echo "Testing application endpoints..."

if curl -f https://ai.swargfood.com/task/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Health endpoint responding${NC}"
else
    echo -e "${RED}❌ Health endpoint not responding${NC}"
    exit 1
fi

if curl -f https://ai.swargfood.com/task/api > /dev/null 2>&1; then
    echo -e "${GREEN}✅ API endpoint responding${NC}"
else
    echo -e "${RED}❌ API endpoint not responding${NC}"
    exit 1
fi

if curl -f https://ai.swargfood.com/task/ > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Frontend responding${NC}"
else
    echo -e "${RED}❌ Frontend not responding${NC}"
    exit 1
fi

# Run post-deployment tests
if [ "$SKIP_TESTS" = false ]; then
    echo -e "${YELLOW}Running post-deployment tests...${NC}"
    
    # Run smoke tests
    npm run test:smoke || echo -e "${YELLOW}⚠️ Some smoke tests failed${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
echo -e "${GREEN}✅ Application is running at: https://ai.swargfood.com/task/${NC}"
echo ""
echo -e "${BLUE}Deployment Summary:${NC}"
echo -e "  Branch: $BRANCH"
echo -e "  Timestamp: $(date)"
echo -e "  Health: ✅ All endpoints responding"
echo ""
