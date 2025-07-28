# Team Task Management Tool

A comprehensive team task management application with real-time collaboration features, built with Flutter (frontend) and Node.js (backend).

## 🚀 Features

### Core Features
- **User Authentication**: Google OAuth integration with JWT tokens
- **Project Management**: Create, manage, and organize projects with team members
- **Task Management**: Advanced task creation, assignment, and tracking
- **Team Collaboration**: Real-time chat, notifications, and activity feeds
- **File Management**: Upload, share, and organize files with team members
- **Time Tracking**: Log time spent on tasks and projects
- **Real-time Updates**: Live notifications and activity updates via WebSocket

### Advanced Features
- **Real-time Chat**: Team communication with channels and direct messages
- **Smart Notifications**: Customizable notification preferences (email, push, in-app)
- **Activity Tracking**: Comprehensive activity logs and team analytics
- **File Sharing**: Secure file uploads with preview capabilities
- **Responsive Design**: Optimized for mobile, tablet, and desktop
- **Team Dashboard**: Real-time insights and team performance metrics

## 🛠 Tech Stack

### Frontend
- **Flutter 3.x** - Cross-platform mobile and web framework
- **Dart** - Programming language
- **Material Design 3** - Modern UI components
- **Socket.IO Client** - Real-time communication
- **HTTP Package** - API communication

### Backend
- **Node.js 18+** - Runtime environment
- **Express.js** - Web framework
- **Prisma ORM** - Database toolkit
- **PostgreSQL** - Primary database
- **Socket.IO** - Real-time communication
- **JWT** - Authentication tokens
- **Multer** - File upload handling
- **Winston** - Logging

### Infrastructure
- **Google OAuth 2.0** - Authentication
- **Google Drive API** - File storage (optional)
- **PostgreSQL** - Data persistence
- **WebSocket** - Real-time features

## 📋 Prerequisites

- **Node.js 18+**
- **Flutter 3.x**
- **PostgreSQL 12+**
- **Google Cloud Console account** (for OAuth)
- **Git**

## 🚀 Quick Start

### 1. Clone the Repository
```bash
git clone <repository-url>
cd task-tool
```

### 2. Backend Setup

```bash
cd backend

# Install dependencies
npm install

# Set up environment variables
cp .env.example .env
```

Configure your `.env` file:
```env
# Database
DATABASE_URL="postgresql://username:password@localhost:5432/taskmanagement"

# JWT
JWT_SECRET="your-super-secret-jwt-key"
JWT_REFRESH_SECRET="your-super-secret-refresh-key"

# Google OAuth
GOOGLE_CLIENT_ID="your-google-client-id"
GOOGLE_CLIENT_SECRET="your-google-client-secret"

# Server
PORT=3000
NODE_ENV=development

# File Upload
UPLOAD_DIR="uploads"
MAX_FILE_SIZE=10485760

# Email (optional)
SMTP_HOST="smtp.gmail.com"
SMTP_PORT=587
SMTP_USER="your-email@gmail.com"
SMTP_PASS="your-app-password"
```

```bash
# Generate Prisma client
npm run generate

# Run database migrations
npm run migrate

# Seed the database (optional)
npm run db:seed

# Start development server
npm run dev
```

### 3. Frontend Setup

```bash
cd frontend

# Install dependencies
flutter pub get

# Configure environment
# Edit lib/config/environment.dart with your backend URL
```

```dart
// lib/config/environment.dart
class Environment {
  static const String apiBaseUrl = 'http://localhost:3000/api';
  static const String socketUrl = 'http://localhost:3000';
  static const String googleClientId = 'your-google-client-id';
}
```

```bash
# Run the app
flutter run
```

## 🔧 Configuration

### Google OAuth Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable Google+ API and Google Drive API
4. Create OAuth 2.0 credentials
5. Add authorized redirect URIs:
   - `http://localhost:3000/auth/google/callback` (backend)
   - Your frontend URLs

### Database Setup

```sql
-- Create database
CREATE DATABASE taskmanagement;

-- Create user (optional)
CREATE USER taskuser WITH PASSWORD 'your-password';
GRANT ALL PRIVILEGES ON DATABASE taskmanagement TO taskuser;
```

## 📚 API Documentation

The API documentation is available at `http://localhost:3000/api-docs` when running the backend server.

### Key Endpoints

- **Authentication**: `/api/auth/*`
- **Users**: `/api/users/*`
- **Projects**: `/api/projects/*`
- **Tasks**: `/api/tasks/*`
- **Chat**: `/api/chat/*`
- **Notifications**: `/api/notifications/*`
- **Files**: `/api/files/*`
- **Activity**: `/api/activity/*`

## 🧪 Testing

### Backend Tests
```bash
cd backend
npm test
npm run test:coverage
```

### Frontend Tests
```bash
cd frontend
flutter test
```

## 🚀 Deployment

### Backend Deployment

1. **Environment Setup**:
```bash
# Production environment variables
NODE_ENV=production
DATABASE_URL="your-production-database-url"
JWT_SECRET="your-production-jwt-secret"
```

2. **Build and Deploy**:
```bash
npm run migrate:prod
npm start
```

### Frontend Deployment

1. **Web Deployment**:
```bash
flutter build web
# Deploy the build/web directory to your hosting service
```

2. **Mobile App**:
```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

## 🔒 Security Features

- **JWT Authentication** with refresh tokens
- **Rate Limiting** on API endpoints
- **Input Validation** and sanitization
- **CORS Protection**
- **Helmet.js** security headers
- **File Upload Validation**
- **SQL Injection Protection** via Prisma

## 📱 Mobile Features

- **Responsive Design** for all screen sizes
- **Offline Support** for basic functionality
- **Push Notifications** (when configured)
- **File Upload** from camera/gallery
- **Real-time Sync** across devices

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

### Development Guidelines

- Follow the existing code style
- Add tests for new features
- Update documentation as needed
- Ensure all tests pass before submitting

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

If you encounter any issues or have questions:

1. Check the [Issues](../../issues) page
2. Review the API documentation
3. Check the console logs for error messages
4. Ensure all environment variables are properly configured

## 🎯 Roadmap

- [ ] Mobile push notifications
- [ ] Advanced reporting and analytics
- [ ] Integration with external tools (Slack, Trello, etc.)
- [ ] Advanced file management features
- [ ] Video calling integration
- [ ] Advanced project templates
- [ ] Time tracking improvements
- [ ] Advanced user permissions

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Prisma team for the excellent ORM
- Socket.IO for real-time capabilities
- Material Design team for the design system
