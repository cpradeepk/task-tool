# Comprehensive Task Management Application Requirements

## Project Overview
A comprehensive task management application for teams using Flutter (supporting web, Android, and iOS) with a secure scalable Node.js backend. The application features responsive UI design that adapts to different screen sizes and device orientations.

## Core Features

### Authentication & User Management
- **Gmail OAuth Integration**: Secure user login via Google OAuth
- **Admin-Only User Management**: Add/remove users (admin exclusive)
- **User Profiles**: Customizable settings including:
  - Color themes
  - Fonts
  - Profile picture
  - Name and short name
  - Email
  - Phone number
  - Telegram number
  - WhatsApp number
- **Default Theme**: Light blue as primary focus color

### Task Hierarchy & Structure
- **4-Level Hierarchy**: Project → Sub Project → Task → Subtask (optional)
- **Admin-Only Project Management**: 
  - Create/delete projects
  - Configure project settings
- **Task Dependencies**: 
  - Within and across projects
  - Pre-dependencies (tasks that need completion before starting)
  - Post-dependencies (tasks that can start after completion)
- **Task Milestones**: Custom milestone tracking
- **Custom Labels**: Flexible labeling system
- **Task History**: Complete audit trail for all changes

### Task Status Management
Status options with color coding:
- **Open** (white)
- **In Progress** (yellow) - auto-populates start date
- **Completed** (green) - auto-populates end date
- **Cancelled** (grey)
- **Hold** (brown)
- **Delayed** (red)

### Priority System (Eisenhower Matrix)
- **Important & Urgent** (Orange)
- **Important & Not Urgent** (Yellow)
- **Not Important & Urgent** (White)
- **Not Important & Not Urgent** (White)

### Task Fields & Properties
- **Task Type**: Requirement, Design, Coding, Testing, Learning, Documentation
- **Start Date**: Auto-populated when status changes to "In Progress"
- **Planned End Date**: Manual entry
- **End Date**: Auto-populated when status changes to "Completed"
- **Time Tracking**: Start/stop timer + manual edit capability
- **Multiple User Assignment**: Main responsible + support roles
- **PERT Time Estimates**: Optimistic, pessimistic, most likely

### Views & Visualization
- **Calendar View**: Task integration with calendar interface
- **PERT Chart View**:
  - Auto-generated task dependencies visualization
  - Critical path highlighting
  - Clickable task nodes for view/edit
  - Summary comparison tables and flow charts
  - PDF and Excel export functionality
- **Team Member Overview**: View other members' current tasks

### Communication & Collaboration
- **Project/Sub-project Group Chats** (admin-configurable):
  - Voice notes
  - Text messages
  - Photos/videos
  - Links with descriptions
  - Document attachments
  - Task mentions and tagging
- **Task-Specific Comments**: Comments and mentions on individual tasks
- **Voice Command**: Task creation/editing via voice commands

### Notifications & Reminders
- **High-Priority Notifications**: App and email notifications for:
  - Task assignments
  - Status changes
  - Chat mentions
- **Daily Morning Email Summaries**:
  - Overdue tasks
  - Current day tasks
- **Custom Task Reminders**: Via email
- **Device Calendar Integration**: With reminders
- **Future Integration**: Telegram/WhatsApp notifications

### Personal Features
- **Private Notes Section**: 
  - Voice notes
  - Text notes
  - Photos/videos
  - Links
  - Documents
- **Personal Availability Tracking**: Track personal availability
- **Learning Repository**: Text and voice notes for learning

## Technical Requirements

### Architecture
- **Frontend**: Flutter (web, Android, iOS)
- **Backend**: Node.js with JavaScript
- **Database**: PostgreSQL with Prisma ORM (already implemented)
- **Authentication**: Google OAuth 2.0
- **File Storage**: Google Drive integration
- **Real-time Features**: WebSocket for chat and notifications

### Design Requirements
- **Responsive Design**: All screen sizes and orientations
- **Cross-Platform Compatibility**: Flutter web, Android, iOS
- **Scalable Backend Architecture**: Microservices-ready
- **Real-Time Synchronization**: Live updates across devices
- **Offline Capability**: Consider offline functionality

### Development Approach
- **Phased Implementation**: Clear task breakdown by phases
- **Detailed Documentation**: Comprehensive docs for continuity
- **Explicit Approval Required**: No modifications without permission
- **Repository Structure**:
  - `./backend` for backend files
  - `./frontend` for frontend files (renamed from frontend_flutter)
  - Single git repository for both
- **Deployment**: Ubuntu server on AWS with deployment scripts

## Current Status (Phase 1 Complete)
✅ **Completed Features**:
- Express.js server with security middleware
- PostgreSQL database with Prisma ORM
- Google OAuth 2.0 authentication
- JWT token management
- User profile management
- Google Drive integration
- File upload/download system
- Admin user management
- Basic Flutter project structure

## Development Phases

### Phase 2: Core Task Management System
- Project management API and UI
- Task CRUD operations
- Status management with auto-dates
- Priority system implementation
- Task assignment system
- Basic task list views

### Phase 3: Advanced Task Features
- Task dependencies (pre/post)
- PERT time estimates
- Time tracking system
- Task milestones
- Custom labels
- Task history/audit trail

### Phase 4: Communication & Collaboration
- Group chat system
- Task comments and mentions
- Voice notes integration
- File attachments in chats
- Real-time messaging

### Phase 5: Views & Visualization
- Calendar view implementation
- PERT chart visualization
- Team member task overview
- Export functionality (PDF/Excel)
- Advanced filtering and sorting

### Phase 6: Personal Features & Polish
- Private notes system
- Voice command integration
- Personal availability tracking
- Learning notes repository
- UI/UX polish and optimization

### Phase 7: Deployment & Documentation
- AWS deployment scripts
- Production environment setup
- Comprehensive documentation
- Performance optimization
- Security hardening

## Important Notes
- **No Implementation Without Permission**: All features must be explicitly approved
- **Maintain Existing Structure**: Build upon Phase 1 foundation
- **Documentation First**: Create detailed specs before implementation
- **Testing Required**: Comprehensive testing for each phase
- **Responsive Design**: All features must work across all screen sizes
