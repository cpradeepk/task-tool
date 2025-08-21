#!/bin/bash

# Quick deployment trigger script
# This script commits current changes and triggers deployment

echo "🚀 Quick Deploy Script"
echo "====================="

# Check if there are any changes to commit
if [ -n "$(git status --porcelain)" ]; then
    echo "📝 Found uncommitted changes. Committing them..."
    
    git add .
    
    # Get a commit message from user or use default
    if [ -z "$1" ]; then
        COMMIT_MSG="chore: Deploy latest changes - $(date '+%Y-%m-%d %H:%M:%S')"
    else
        COMMIT_MSG="$1"
    fi
    
    git commit -m "$COMMIT_MSG"
    echo "✅ Changes committed: $COMMIT_MSG"
else
    echo "ℹ️  No uncommitted changes found."
fi

# Push to trigger deployment
echo "📤 Pushing to main branch to trigger deployment..."
git push origin main

echo ""
echo "🎯 Deployment triggered!"
echo "📊 You can monitor the deployment at:"
echo "   https://github.com/cpradeepk/task-tool/actions"
echo ""
echo "🌐 Once deployed, the app will be available at:"
echo "   https://task.amtariksha.com/task/"
echo ""
echo "⏳ Deployment typically takes 3-5 minutes."
