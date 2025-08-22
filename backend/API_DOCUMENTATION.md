# 📚 Margadarshi Task Management System - API Documentation

## Phase 3 & 4 Enhanced Features

### 🔐 Authentication
All API endpoints require JWT authentication via the `Authorization: Bearer <token>` header.

### 🎯 Base URL
```
Production: https://task.amtariksha.com/task/api
Development: http://localhost:3000/task/api
```

---

## 🤝 Task Support Team Management

### Add/Remove Support Team Members
```http
PUT /projects/{projectId}/tasks/{taskId}/support
```

**Headers:**
- `Authorization: Bearer <token>`
- `Content-Type: application/json`

**Body:**
```json
{
  "support_team": ["user_id_1", "user_id_2"],
  "action": "add" // or "remove"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Support team added successfully"
}
```

### Get Tasks Where User is Support Team Member
```http
GET /tasks/support/{employeeId}
```

**Response:**
```json
[
  {
    "id": 1,
    "title": "Task Title",
    "status": "In Progress",
    "project_name": "Project Name",
    "module_name": "Module Name",
    "assigned_to_email": "user@example.com"
  }
]
```

---

## 💬 Task Comments & History

### Get Task Comments
```http
GET /tasks/{taskId}/comments
```

**Response:**
```json
[
  {
    "id": 1,
    "content": "This is a comment",
    "author_email": "user@example.com",
    "author_name": "User Name",
    "is_internal": false,
    "created_at": "2024-01-15T10:30:00Z"
  }
]
```

### Add Task Comment
```http
POST /tasks/{taskId}/comments
```

**Body:**
```json
{
  "content": "Comment text",
  "is_internal": false,
  "attachments": ["file1.pdf", "file2.jpg"]
}
```

### Get Task History
```http
GET /tasks/{taskId}/history
```

**Response:**
```json
[
  {
    "id": 1,
    "change_type": "status_changed",
    "old_values": {"status": "Yet to Start"},
    "new_values": {"status": "In Progress"},
    "comment": "Status updated",
    "changed_by_name": "User Name",
    "changed_at": "2024-01-15T10:30:00Z"
  }
]
```

### Get Task Activity Feed
```http
GET /tasks/{taskId}/activity
```

**Response:** Combined comments and history in chronological order.

---

## 📋 Task Templates

### Get All Templates
```http
GET /task-templates
```

**Query Parameters:**
- `category` (optional): Filter by category
- `search` (optional): Search in name/description

**Response:**
```json
[
  {
    "id": 1,
    "name": "Bug Fix Template",
    "description": "Standard template for bug fixing",
    "category": "Development",
    "is_public": true,
    "created_by_name": "Admin User"
  }
]
```

### Create Template
```http
POST /task-templates
```

**Body:**
```json
{
  "name": "Template Name",
  "description": "Template description",
  "template_data": {
    "title": "Default Title",
    "description": "Default description",
    "priority": "Medium"
  },
  "category": "Development",
  "is_public": true
}
```

### Create Task from Template
```http
POST /task-templates/{templateId}/create-task
```

**Body:**
```json
{
  "project_id": 1,
  "module_id": 1,
  "customizations": {
    "title": "Custom Task Title",
    "assigned_to": "user_id"
  }
}
```

---

## 🏖️ Leave Management

### Apply for Leave
```http
POST /leaves
```

**Body:**
```json
{
  "leave_type": "Annual Leave",
  "start_date": "2024-02-01",
  "end_date": "2024-02-03",
  "reason": "Family vacation"
}
```

**Response:**
```json
{
  "id": 1,
  "leave_type": "Annual Leave",
  "start_date": "2024-02-01",
  "end_date": "2024-02-03",
  "status": "pending",
  "employee_email": "user@example.com"
}
```

### Get Leave Requests
```http
GET /leaves
```

**Query Parameters:**
- `status`: pending, approved, rejected
- `employee_id`: Filter by employee
- `start_date`, `end_date`: Date range filter

### Approve/Reject Leave
```http
PUT /leaves/{leaveId}/approve
PUT /leaves/{leaveId}/reject
```

**Body:**
```json
{
  "comments": "Approval/rejection reason"
}
```

### Get Leave Statistics
```http
GET /leaves/stats/summary
```

**Query Parameters:**
- `employee_id` (optional): Get stats for specific employee

**Response:**
```json
{
  "year": 2024,
  "total_requests": 5,
  "approved_requests": 4,
  "pending_requests": 1,
  "total_days_taken": 12,
  "remaining_days": 18
}
```

---

## 🏠 Work From Home Management

### Apply for WFH
```http
POST /wfh
```

**Body:**
```json
{
  "date": "2024-02-15",
  "reason": "Home internet maintenance"
}
```

### Get WFH Requests
```http
GET /wfh
```

**Query Parameters:**
- `status`: pending, approved, rejected
- `employee_id`: Filter by employee
- `date`: Specific date
- `start_date`, `end_date`: Date range

### Approve/Reject WFH
```http
PUT /wfh/{wfhId}/approve
PUT /wfh/{wfhId}/reject
```

### Bulk Approve/Reject WFH
```http
PUT /wfh/bulk/approve
PUT /wfh/bulk/reject
```

**Body:**
```json
{
  "request_ids": [1, 2, 3],
  "comments": "Bulk approval reason"
}
```

### Get WFH Statistics
```http
GET /wfh/stats/summary
```

**Response:**
```json
{
  "month": 2,
  "year": 2024,
  "total_requests": 8,
  "approved_requests": 7,
  "pending_requests": 1,
  "upcoming_wfh_days": [
    {
      "date": "2024-02-20",
      "reason": "Doctor appointment"
    }
  ]
}
```

---

## 👥 Enhanced User Management

### Import Users
```http
POST /enhanced-users/import
```

**Body:**
```json
{
  "users": [
    {
      "email": "newuser@example.com",
      "name": "New User",
      "role": "Team Member",
      "manager_id": "manager_user_id",
      "hire_date": "2024-01-15"
    }
  ]
}
```

**Response:**
```json
{
  "success": [
    {
      "row": 1,
      "user_id": "new_user_id",
      "email": "newuser@example.com"
    }
  ],
  "errors": [],
  "total": 1
}
```

### Export Users
```http
GET /enhanced-users/export?format=csv
```

**Query Parameters:**
- `format`: json (default) or csv

### Get Team Members
```http
GET /enhanced-users/team/{managerId}
```

**Response:**
```json
[
  {
    "id": "user_id",
    "name": "Team Member",
    "email": "member@example.com",
    "total_tasks": 15,
    "completed_tasks": 12,
    "overdue_tasks": 1
  }
]
```

### Add User Warning
```http
PUT /enhanced-users/{userId}/warning
```

**Body:**
```json
{
  "warning_type": "overdue_tasks",
  "description": "Multiple overdue tasks"
}
```

### Get User Warnings
```http
GET /enhanced-users/{userId}/warnings
```

### Generate Employee ID Card
```http
GET /enhanced-users/{userId}/id-card
```

**Response:**
```json
{
  "employee_id": "user_id",
  "name": "Employee Name",
  "email": "employee@example.com",
  "roles": ["Team Member"],
  "hire_date": "2024-01-15",
  "manager": "Manager Name",
  "photo": "base64_encoded_photo",
  "status": "active",
  "generated_at": "2024-01-15T10:30:00Z",
  "company": "Margadarshi"
}
```

### Update User Photo
```http
PUT /enhanced-users/{userId}/photo
```

**Body:**
```json
{
  "photo": "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQ..."
}
```

### Get User Statistics
```http
GET /enhanced-users/{userId}/stats
```

**Response:**
```json
{
  "tasks": {
    "total": 25,
    "completed": 20,
    "in_progress": 3,
    "overdue": 2,
    "completion_rate": 80
  },
  "leaves": {
    "total": 5,
    "approved": 4,
    "pending": 1
  },
  "wfh": {
    "total": 8,
    "approved": 7,
    "pending": 1
  },
  "warnings": {
    "count": 1,
    "last_warning": "2024-01-10T10:30:00Z"
  }
}
```

---

## 📊 Enhanced Dashboard

### Get Role-based Dashboard Stats
```http
GET /dashboard/stats/employee
GET /dashboard/stats/manager
GET /dashboard/stats/admin
```

### Get Overdue Tasks
```http
GET /dashboard/overdue-tasks
```

### Get This Week Tasks
```http
GET /dashboard/this-week
```

### Get Task Warnings
```http
GET /dashboard/warnings
```

**Response:**
```json
{
  "warning_level": "medium", // none, low, medium, high, critical
  "warning_count": 3,
  "overdue_tasks": 2,
  "due_today_tasks": 1,
  "has_warnings": true
}
```

---

## 🔍 Advanced Task Features

### Get Overdue Tasks
```http
GET /tasks/overdue
```

### Bulk Update Delayed Tasks
```http
PUT /tasks/update-delayed
```

**Body:**
```json
{
  "task_ids": [1, 2, 3],
  "new_status": "Delayed",
  "new_due_date": "2024-02-20",
  "reason": "Resource constraints"
}
```

### Get Task Warnings for User
```http
GET /tasks/warnings/{employeeId}
```

---

## 📝 Response Codes

- `200` - Success
- `201` - Created
- `400` - Bad Request
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Not Found
- `500` - Internal Server Error

## 🔒 Role-based Access Control

### Roles:
- **Admin**: Full system access
- **Manager**: Team management, approvals
- **Team Lead**: Limited team oversight
- **Team Member**: Personal tasks and requests

### Permissions:
- Task support team management: Admin, Manager, Team Lead
- Leave/WFH approvals: Admin, Manager, Team Lead
- User warnings: Admin, Manager, Team Lead
- User import/export: Admin only
- Template creation: Admin, Manager, Team Lead

---

## 📈 Rate Limiting

- **General API**: 100 requests per minute per user
- **Bulk operations**: 10 requests per minute per user
- **File uploads**: 5 requests per minute per user

## 🔄 Pagination

For endpoints returning lists, use:
- `page`: Page number (default: 1)
- `limit`: Items per page (default: 20, max: 100)

**Response includes:**
```json
{
  "data": [...],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 150,
    "pages": 8
  }
}
```

---

## 🚀 Quick Start Examples

### JavaScript/Fetch Example
```javascript
// Apply for leave
const response = await fetch('/task/api/leaves', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    leave_type: 'Annual Leave',
    start_date: '2024-02-01',
    end_date: '2024-02-03',
    reason: 'Family vacation'
  })
});

const result = await response.json();
```

### cURL Example
```bash
# Get task comments
curl -X GET "https://task.amtariksha.com/task/api/tasks/123/comments" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json"
```

### Flutter/Dart Example
```dart
// Add task comment
final response = await http.post(
  Uri.parse('$apiBase/task/api/tasks/$taskId/comments'),
  headers: {
    'Authorization': 'Bearer $jwt',
    'Content-Type': 'application/json',
  },
  body: jsonEncode({
    'content': 'This is a comment',
    'is_internal': false,
  }),
);
```
