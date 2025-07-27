# Deploy Google OAuth to Production - Quick Guide

## 🚨 Issue: Login Screen Still Shows "Coming Soon"

The Google OAuth implementation has been committed to Git, but the production server needs to be updated with the new frontend build.

## 🔧 Solution: Deploy Updated Frontend

### Option 1: SSH to Production Server (Recommended)

1. **SSH to your production server:**
   ```bash
   ssh root@ai.swargfood.com
   ```

2. **Navigate to the application directory:**
   ```bash
   cd /var/www/task
   ```

3. **Pull the latest changes:**
   ```bash
   git stash push -m "Auto-stash before OAuth deployment"
   git fetch origin
   git checkout main
   git pull origin main
   ```

4. **Update backend environment (if not already done):**
   ```bash
   # Edit the backend .env file
   nano backend/.env
   
   # Ensure these lines are present:
   GOOGLE_CLIENT_ID="792432621176-nrigk87pmes9f28db8oj49dgc6obh24m.apps.googleusercontent.com"
   GOOGLE_CLIENT_SECRET="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"
   ```

5. **Rebuild the Flutter frontend:**
   ```bash
   cd frontend
   flutter clean
   flutter pub get
   flutter build web --release --base-href="/task/"
   ```

6. **Deploy to Nginx:**
   ```bash
   # Backup current build
   mv build/web build/web.backup.$(date +%Y%m%d-%H%M%S) || true
   
   # Copy new build to nginx directory
   rm -rf /var/www/task/frontend/build/web
   cp -r build/web /var/www/task/frontend/build/web
   chown -R www-data:www-data /var/www/task/frontend/build/web
   chmod -R 755 /var/www/task/frontend/build/web
   ```

7. **Restart services:**
   ```bash
   # Reload Nginx
   systemctl reload nginx
   
   # Restart backend to pick up new environment variables
   cd ../backend
   pm2 restart swargfood-task-management
   ```

### Option 2: Use Existing Deployment Script

If you have the existing deployment script:

```bash
ssh root@ai.swargfood.com
cd /var/www/task
./scripts/deploy.sh production main
```

## 🧪 Verification Steps

1. **Check if deployment was successful:**
   ```bash
   curl -s https://ai.swargfood.com/task/ | grep -o "apps.googleusercontent.com"
   ```
   If this returns the domain, OAuth is deployed.

2. **Test in browser:**
   - Clear browser cache (Ctrl+F5 or Cmd+Shift+R)
   - Or use incognito/private mode
   - Navigate to https://ai.swargfood.com/task/
   - You should see "Sign in with Google" button instead of "coming soon"

## 🔍 Troubleshooting

### If you still see "Google Sign-In coming soon":

1. **Hard refresh the browser multiple times**
2. **Clear all browser data for ai.swargfood.com**
3. **Check if the build was successful:**
   ```bash
   ls -la /var/www/task/frontend/build/web/
   grep -r "Sign in with Google" /var/www/task/frontend/build/web/
   ```

4. **Check Nginx configuration:**
   ```bash
   nginx -t
   systemctl status nginx
   ```

5. **Check if files are being served correctly:**
   ```bash
   curl -I https://ai.swargfood.com/task/
   ```

### If OAuth button appears but doesn't work:

1. **Check backend logs:**
   ```bash
   pm2 logs swargfood-task-management
   ```

2. **Verify environment variables:**
   ```bash
   cd /var/www/task/backend
   grep GOOGLE .env
   ```

3. **Test OAuth endpoint:**
   ```bash
   curl https://ai.swargfood.com/task/api/auth/google -X POST -H "Content-Type: application/json" -d '{"token":"test"}'
   ```

## 📋 Expected Results

After successful deployment:

✅ **Login screen shows:** "Sign in with Google" button  
✅ **Browser console:** No errors related to Google OAuth  
✅ **Network tab:** Requests to Google OAuth APIs  
✅ **Backend logs:** OAuth endpoint accessible  

## 🚀 Quick Commands Summary

```bash
# SSH to server
ssh root@ai.swargfood.com

# Deploy OAuth
cd /var/www/task
git pull origin main
cd frontend
flutter build web --release --base-href="/task/"
rm -rf /var/www/task/frontend/build/web
cp -r build/web /var/www/task/frontend/build/web
chown -R www-data:www-data /var/www/task/frontend/build/web
systemctl reload nginx
cd ../backend && pm2 restart swargfood-task-management

# Verify
curl -s https://ai.swargfood.com/task/ | grep "apps.googleusercontent.com"
```

## 📞 Support

If you continue to experience issues:

1. Check the browser developer tools for JavaScript errors
2. Verify the Google Cloud Console OAuth configuration
3. Ensure the production server has the latest code
4. Test the OAuth flow in incognito mode

The Google OAuth implementation is complete and ready - it just needs to be deployed to production with a fresh Flutter build.
