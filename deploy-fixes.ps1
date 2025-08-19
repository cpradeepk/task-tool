# Deploy Task Tool Fixes Script (PowerShell)
# This script deploys the bug fixes for the task management system

Write-Host "🚀 Starting deployment of task tool fixes..." -ForegroundColor Green

# Check if we're in the right directory
if (-not (Test-Path "COMPREHENSIVE_PRD.md")) {
    Write-Host "❌ Error: Please run this script from the project root directory" -ForegroundColor Red
    exit 1
}

# Build frontend
Write-Host "📦 Building frontend..." -ForegroundColor Yellow
Set-Location frontend
flutter build web --release --base-href=/task/ --dart-define=API_BASE=https://task.amtariksha.com

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Frontend build failed" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Frontend build completed" -ForegroundColor Green

# Deploy frontend using SCP (requires OpenSSH or similar)
Write-Host "📤 Deploying frontend..." -ForegroundColor Yellow
scp -r build/web/* root@task.amtariksha.com:/var/www/task/

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Frontend deployment failed" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Frontend deployed successfully" -ForegroundColor Green

# Deploy backend
Write-Host "📤 Deploying backend..." -ForegroundColor Yellow
Set-Location ../backend

# Copy backend files using rsync (or scp)
rsync -av --exclude node_modules --exclude .env src/ root@task.amtariksha.com:/var/www/api/src/
scp package.json root@task.amtariksha.com:/var/www/api/
scp fix-tasks-schema.js root@task.amtariksha.com:/var/www/api/

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Backend deployment failed" -ForegroundColor Red
    exit 1
}

# Install dependencies and restart backend on server
Write-Host "🔧 Installing dependencies and restarting backend..." -ForegroundColor Yellow
ssh root@task.amtariksha.com @"
cd /var/www/api
npm install
pm2 restart task-tool-backend || pm2 start src/server.js --name task-tool-backend
echo "✅ Backend restarted successfully"
"@

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Backend restart failed" -ForegroundColor Red
    exit 1
}

Write-Host "🎉 Deployment completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Summary of fixes deployed:" -ForegroundColor Cyan
Write-Host "  ✅ Fixed task creation and update API authorization" -ForegroundColor Green
Write-Host "  ✅ Fixed user dropdown for task assignee" -ForegroundColor Green
Write-Host "  ✅ Fixed task assignment functionality" -ForegroundColor Green
Write-Host "  ✅ Fixed status update functionality" -ForegroundColor Green
Write-Host "  ✅ Fixed project loading timeout issues" -ForegroundColor Green
Write-Host "  ✅ Fixed task name click navigation" -ForegroundColor Green
Write-Host "  ✅ Added better error handling and logging" -ForegroundColor Green
Write-Host ""
Write-Host "🔗 Application URL: https://task.amtariksha.com/task/" -ForegroundColor Cyan
Write-Host ""
Write-Host "📝 Next steps:" -ForegroundColor Yellow
Write-Host "  1. Test the application in production" -ForegroundColor White
Write-Host "  2. Run database schema fix if needed: node fix-tasks-schema.js" -ForegroundColor White
Write-Host "  3. Monitor logs for any remaining issues" -ForegroundColor White

Set-Location ..
