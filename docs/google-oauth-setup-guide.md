# Google OAuth Setup Guide for SwargFood Task Management

This guide provides step-by-step instructions for setting up Google OAuth authentication for the SwargFood Task Management system.

## Prerequisites

- Google Cloud Console account
- Access to the SwargFood Task Management codebase
- Admin access to the server/deployment environment

## Step 1: Google Cloud Console Setup

### 1.1 Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click "Select a project" → "New Project"
3. Enter project name: `SwargFood Task Management`
4. Click "Create"

### 1.2 Enable Google+ API

1. In the Google Cloud Console, go to "APIs & Services" → "Library"
2. Search for "Google+ API"
3. Click on "Google+ API" and click "Enable"
4. Also enable "Google Sign-In API" if available

### 1.3 Configure OAuth Consent Screen

1. Go to "APIs & Services" → "OAuth consent screen"
2. Choose "External" user type (unless you have a Google Workspace)
3. Fill in the required information:
   - **App name**: SwargFood Task Management
   - **User support email**: Your admin email
   - **Developer contact information**: Your admin email
4. Add scopes:
   - `email`
   - `profile`
   - `openid`
5. Add test users (your admin email addresses)
6. Save and continue

### 1.4 Create OAuth 2.0 Credentials

1. Go to "APIs & Services" → "Credentials"
2. Click "Create Credentials" → "OAuth 2.0 Client IDs"
3. Choose "Web application"
4. Configure:
   - **Name**: SwargFood Task Management Web Client
   - **Authorized JavaScript origins**:
     - `http://localhost:3000` (for development)
     - `https://ai.swargfood.com` (for production)
   - **Authorized redirect URIs**:
     - `http://localhost:3000/task/` (for development)
     - `https://ai.swargfood.com/task/` (for production)
5. Click "Create"
6. **IMPORTANT**: Copy the Client ID and Client Secret

## Step 2: Backend Configuration

### 2.1 Update Environment Variables

Edit `backend/.env` file:

```env
# Google OAuth Configuration
GOOGLE_CLIENT_ID="your-actual-client-id.apps.googleusercontent.com"
GOOGLE_CLIENT_SECRET="your-actual-client-secret"
```

### 2.2 Verify Backend OAuth Implementation

The backend OAuth implementation is already in place:
- `src/controllers/authController.js` - Google login handler
- `src/routes/auth.js` - OAuth routes
- JWT token generation and user creation/update logic

## Step 3: Frontend Configuration

### 3.1 Update Environment Configuration

Edit `frontend/lib/config/environment.dart`:

```dart
static const String googleClientId = String.fromEnvironment(
  'GOOGLE_CLIENT_ID',
  defaultValue: 'your-actual-client-id.apps.googleusercontent.com',
);
```

### 3.2 Flutter Web Configuration

Create `frontend/web/index.html` meta tag (if not exists):

```html
<meta name="google-signin-client_id" content="your-actual-client-id.apps.googleusercontent.com">
```

## Step 4: Create Admin User

### 4.1 Run Admin User Creation Script

```bash
cd backend
npm run admin:create
```

Follow the prompts to create an admin user with your Google account email.

### 4.2 Alternative: Manual Database Update

If you prefer to update an existing user to admin:

```sql
UPDATE users 
SET "isAdmin" = true, "role" = 'ADMIN' 
WHERE email = 'your-admin-email@gmail.com';
```

## Step 5: Testing and Validation

### 5.1 Test Development Environment

1. Start the backend server:
   ```bash
   cd backend
   npm run dev
   ```

2. Start the frontend:
   ```bash
   cd frontend
   flutter run -d web --web-port 3000
   ```

3. Navigate to `http://localhost:3000/task/`
4. Click "Sign in with Google"
5. Complete the OAuth flow
6. Verify admin access in the application

### 5.2 Test Production Environment

1. Deploy the updated configuration
2. Navigate to `https://ai.swargfood.com/task/`
3. Test Google OAuth login
4. Verify admin functionality

## Step 6: Security Considerations

### 6.1 Environment Security

- Never commit actual OAuth credentials to version control
- Use different OAuth clients for development and production
- Regularly rotate OAuth client secrets

### 6.2 User Access Control

- Only add trusted email addresses as admin users
- Regularly review user permissions
- Monitor authentication logs

## Troubleshooting

### Common Issues

1. **"redirect_uri_mismatch" error**
   - Verify redirect URIs in Google Cloud Console match exactly
   - Check for trailing slashes and protocol (http vs https)

2. **"invalid_client" error**
   - Verify GOOGLE_CLIENT_ID in environment variables
   - Ensure the client ID matches the one from Google Cloud Console

3. **User not created as admin**
   - Run the admin creation script: `npm run admin:create`
   - Verify the email matches exactly with Google account

4. **CORS errors**
   - Verify authorized origins in Google Cloud Console
   - Check CORS configuration in backend

### Debug Steps

1. Check backend logs for authentication errors
2. Verify environment variables are loaded correctly
3. Test API endpoints directly using tools like Postman
4. Check browser console for frontend errors

## Next Steps

After successful setup:

1. Configure additional OAuth scopes if needed
2. Set up email notifications for new user registrations
3. Implement user role management interface
4. Configure backup authentication methods

## Support

For additional support:
- Check the main developer documentation in `docs/developer-handover.md`
- Review authentication test suite in `tests/e2e/01-authentication.spec.js`
- Contact the development team for assistance
