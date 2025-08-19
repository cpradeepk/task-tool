#!/bin/bash

# Deploy Task Tool Fixes Script
# This script deploys the bug fixes for the task management system

echo "🚀 Starting deployment of task tool fixes..."

# Check if we're in the right directory
if [ ! -f "COMPREHENSIVE_PRD.md" ]; then
    echo "❌ Error: Please run this script from the project root directory"
    exit 1
fi

# Build frontend
echo "📦 Building frontend..."
cd frontend
flutter build web --release --base-href=/task/ --dart-define=API_BASE=https://task.amtariksha.com
if [ $? -ne 0 ]; then
    echo "❌ Frontend build failed"
    exit 1
fi
echo "✅ Frontend build completed"

# Copy frontend files to server
echo "📤 Deploying frontend..."
scp -r build/web/* root@task.amtariksha.com:/var/www/task/
if [ $? -ne 0 ]; then
    echo "❌ Frontend deployment failed"
    exit 1
fi
echo "✅ Frontend deployed successfully"

# Deploy backend
echo "📤 Deploying backend..."
cd ../backend

# Copy backend files
rsync -av --exclude node_modules --exclude .env src/ root@task.amtariksha.com:/var/www/api/src/
scp package.json root@task.amtariksha.com:/var/www/api/
scp fix-tasks-schema.js root@task.amtariksha.com:/var/www/api/

if [ $? -ne 0 ]; then
    echo "❌ Backend deployment failed"
    exit 1
fi

# Install dependencies and restart backend on server
echo "🔧 Installing dependencies and restarting backend..."
ssh root@task.amtariksha.com << 'EOF'
cd /var/www/api
npm install
pm2 restart task-tool-backend || pm2 start src/server.js --name task-tool-backend
echo "✅ Backend restarted successfully"
EOF

if [ $? -ne 0 ]; then
    echo "❌ Backend restart failed"
    exit 1
fi

echo "🎉 Deployment completed successfully!"
echo ""
echo "📋 Summary of fixes deployed:"
echo "  ✅ Fixed task creation and update API authorization"
echo "  ✅ Fixed user dropdown for task assignee"
echo "  ✅ Fixed task assignment functionality"
echo "  ✅ Fixed status update functionality"
echo "  ✅ Fixed project loading timeout issues"
echo "  ✅ Fixed task name click navigation"
echo "  ✅ Added better error handling and logging"
echo ""
echo "🔗 Application URL: https://task.amtariksha.com/task/"
echo ""
echo "📝 Next steps:"
echo "  1. Test the application in production"
echo "  2. Run database schema fix if needed: node fix-tasks-schema.js"
echo "  3. Monitor logs for any remaining issues"
