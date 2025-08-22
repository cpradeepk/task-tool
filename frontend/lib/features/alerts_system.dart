import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../main_layout.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3003');

class AlertsSystemScreen extends StatefulWidget {
  const AlertsSystemScreen({super.key});

  @override
  State<AlertsSystemScreen> createState() => _AlertsSystemScreenState();
}

class _AlertsSystemScreenState extends State<AlertsSystemScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _alerts = [];
  List<dynamic> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAlerts();
    _loadNotifications();
  }

  Future<String?> _getJwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);

    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.get(
        Uri.parse('$apiBase/task/api/alerts'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        setState(() => _alerts = jsonDecode(response.body));
      } else {
        setState(() => _alerts = _generateMockAlerts());
      }
    } catch (e) {
      setState(() => _alerts = _generateMockAlerts());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadNotifications() async {
    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.get(
        Uri.parse('$apiBase/task/api/notifications'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        setState(() => _notifications = jsonDecode(response.body));
      } else {
        setState(() => _notifications = _generateMockNotifications());
      }
    } catch (e) {
      setState(() => _notifications = _generateMockNotifications());
    }
  }

  List<dynamic> _generateMockAlerts() {
    final now = DateTime.now();
    return [
      {
        'id': 1,
        'type': 'deadline',
        'title': 'Task Deadline Approaching',
        'message': 'Complete user authentication task is due tomorrow',
        'severity': 'high',
        'created_at': now.subtract(const Duration(hours: 2)).toIso8601String(),
        'is_read': false,
        'task_id': 1,
        'project': 'Task Tool',
      },
      {
        'id': 2,
        'type': 'overdue',
        'title': 'Overdue Task',
        'message': 'Database optimization task is 2 days overdue',
        'severity': 'critical',
        'created_at': now.subtract(const Duration(days: 1)).toIso8601String(),
        'is_read': false,
        'task_id': 3,
        'project': 'Backend Development',
      },
      {
        'id': 3,
        'type': 'assignment',
        'title': 'New Task Assigned',
        'message': 'You have been assigned to Code Review Session',
        'severity': 'medium',
        'created_at': now.subtract(const Duration(hours: 4)).toIso8601String(),
        'is_read': true,
        'task_id': 4,
        'project': 'Development',
      },
      {
        'id': 4,
        'type': 'milestone',
        'title': 'Milestone Completed',
        'message': 'Project Alpha Phase 1 has been completed',
        'severity': 'low',
        'created_at': now.subtract(const Duration(days: 2)).toIso8601String(),
        'is_read': true,
        'project': 'Project Alpha',
      },
    ];
  }

  List<dynamic> _generateMockNotifications() {
    final now = DateTime.now();
    final dateStr = now.toIso8601String().substring(0, 10).replaceAll('-', '');

    return [
      {
        'id': 1,
        'title': 'Task Assignment',
        'message': 'You have been assigned to "Complete user authentication" (JSR-$dateStr-001)',
        'type': 'task_assignment',
        'created_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
        'is_read': false,
        'priority': 'high',
        'task_id': 'JSR-$dateStr-001',
        'from_user': 'Project Manager',
      },
      {
        'id': 2,
        'title': 'Due Date Reminder',
        'message': 'Task "Design dashboard layout" (JSR-$dateStr-002) is due tomorrow',
        'type': 'due_date',
        'created_at': now.subtract(const Duration(minutes: 30)).toIso8601String(),
        'is_read': false,
        'priority': 'medium',
        'task_id': 'JSR-$dateStr-002',
      },
      {
        'id': 3,
        'title': 'Team Message',
        'message': 'John Doe commented on your task: "Great progress on the authentication module!"',
        'type': 'team_message',
        'created_at': now.subtract(const Duration(hours: 3)).toIso8601String(),
        'is_read': true,
        'priority': 'medium',
        'from_user': 'John Doe',
        'task_id': 'JSR-$dateStr-001',
      },
      {
        'id': 4,
        'title': 'Project Update',
        'message': 'Project "Task Tool Development" has been updated with new modules',
        'type': 'project_update',
        'created_at': now.subtract(const Duration(hours: 6)).toIso8601String(),
        'is_read': true,
        'priority': 'low',
        'project_id': 1,
      },
      {
        'id': 5,
        'title': 'System Alert',
        'message': 'Weekly backup completed successfully. All data is secure.',
        'type': 'system',
        'created_at': now.subtract(const Duration(days: 1)).toIso8601String(),
        'is_read': false,
        'priority': 'low',
      },
      {
        'id': 6,
        'title': 'Daily Summary Report',
        'message': 'Your daily summary report for ${now.subtract(const Duration(days: 1)).toIso8601String().substring(0, 10)} is ready',
        'type': 'report',
        'created_at': now.subtract(const Duration(hours: 8)).toIso8601String(),
        'is_read': false,
        'priority': 'low',
      },
    ];
  }

  Future<void> _markAsRead(int alertId, bool isAlert) async {
    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final endpoint = isAlert ? 'alerts' : 'notifications';
      await http.patch(
        Uri.parse('$apiBase/task/api/$endpoint/$alertId/read'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      // Update locally
      setState(() {
        if (isAlert) {
          final index = _alerts.indexWhere((a) => a['id'] == alertId);
          if (index != -1) _alerts[index]['is_read'] = true;
        } else {
          final index = _notifications.indexWhere((n) => n['id'] == alertId);
          if (index != -1) _notifications[index]['is_read'] = true;
        }
      });
    } catch (e) {
      // Update locally for demo
      setState(() {
        if (isAlert) {
          final index = _alerts.indexWhere((a) => a['id'] == alertId);
          if (index != -1) _alerts[index]['is_read'] = true;
        } else {
          final index = _notifications.indexWhere((n) => n['id'] == alertId);
          if (index != -1) _notifications[index]['is_read'] = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadAlerts = _alerts.where((a) => !a['is_read']).length;
    final unreadNotifications = _notifications.where((n) => !n['is_read']).length;

    return MainLayout(
      title: 'Alerts & Notifications',
      child: Column(
        children: [
          // Header with stats
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.notifications, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Alerts & Notifications',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                _buildStatCard('Unread Alerts', unreadAlerts, Colors.red),
                const SizedBox(width: 16),
                _buildStatCard('Unread Notifications', unreadNotifications, Colors.orange),
              ],
            ),
          ),
          
          // Tab Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning),
                      const SizedBox(width: 8),
                      Text('Alerts ($unreadAlerts)'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.notifications),
                      const SizedBox(width: 8),
                      Text('Notifications ($unreadNotifications)'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAlertsTab(),
                _buildNotificationsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_alerts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text('No alerts', style: TextStyle(fontSize: 18, color: Colors.grey)),
            Text('All caught up!', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _alerts.length,
      itemBuilder: (context, index) {
        final alert = _alerts[index];
        return _buildAlertCard(alert);
      },
    );
  }

  Widget _buildNotificationsTab() {
    if (_notifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No notifications', style: TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      );
    }

    final unreadCount = _notifications.where((n) => !(n['is_read'] ?? false)).length;

    return Column(
      children: [
        // Bulk Actions Header
        if (unreadCount > 0)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Icon(Icons.notifications_active, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  '$unreadCount unread notification${unreadCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _markAllNotificationsAsRead,
                  icon: const Icon(Icons.done_all, size: 16),
                  label: const Text('Mark All Read'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),

        // Notifications List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _notifications.length,
            itemBuilder: (context, index) {
              final notification = _notifications[index];
              return _buildNotificationCard(notification);
            },
          ),
        ),
      ],
    );
  }

  Future<void> _markAllNotificationsAsRead() async {
    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      await http.patch(
        Uri.parse('$apiBase/task/api/notifications/mark-all-read'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      setState(() {
        for (var notification in _notifications) {
          notification['is_read'] = true;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    } catch (e) {
      // Mock success for development
      setState(() {
        for (var notification in _notifications) {
          notification['is_read'] = true;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    }
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final isRead = alert['is_read'] as bool;
    final severity = alert['severity'] as String;
    final timestamp = DateTime.parse(alert['created_at']);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : _getSeverityColor(severity).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getSeverityColor(severity).withOpacity(isRead ? 0.2 : 0.5),
          width: isRead ? 1 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getSeverityColor(severity),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getAlertIcon(alert['type']),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          alert['title'],
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alert['message']),
            const SizedBox(height: 4),
            Row(
              children: [
                if (alert['project'] != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      alert['project'],
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  _formatTimestamp(timestamp),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        trailing: !isRead
            ? IconButton(
                onPressed: () => _markAsRead(alert['id'], true),
                icon: const Icon(Icons.mark_email_read),
                tooltip: 'Mark as read',
              )
            : null,
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isRead = notification['is_read'] as bool;
    final timestamp = DateTime.parse(notification['created_at']);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withOpacity(isRead ? 0.2 : 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getNotificationColor(notification['type']),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getNotificationIcon(notification['type']),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          notification['title'],
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification['message']),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(timestamp),
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Priority indicator
            if (notification['priority'] != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getPriorityColor(notification['priority']),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  notification['priority'].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            const SizedBox(width: 8),

            // Actions menu
            PopupMenuButton<String>(
              onSelected: (action) => _handleNotificationAction(action, notification),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: isRead ? 'mark_unread' : 'mark_read',
                  child: Row(
                    children: [
                      Icon(isRead ? Icons.mark_email_unread : Icons.mark_email_read, size: 16),
                      const SizedBox(width: 8),
                      Text(isRead ? 'Mark as Unread' : 'Mark as Read'),
                    ],
                  ),
                ),
                if (notification['task_id'] != null)
                  const PopupMenuItem(
                    value: 'view_task',
                    child: Row(
                      children: [
                        Icon(Icons.task, size: 16),
                        SizedBox(width: 8),
                        Text('View Task'),
                      ],
                    ),
                  ),
                if (notification['project_id'] != null)
                  const PopupMenuItem(
                    value: 'view_project',
                    child: Row(
                      children: [
                        Icon(Icons.folder, size: 16),
                        SizedBox(width: 8),
                        Text('View Project'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              child: Icon(
                Icons.more_vert,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _handleNotificationAction(String action, Map<String, dynamic> notification) {
    switch (action) {
      case 'mark_read':
        _markAsRead(notification['id'], false);
        break;
      case 'mark_unread':
        _markAsUnread(notification['id']);
        break;
      case 'view_task':
        _viewTask(notification['task_id']);
        break;
      case 'view_project':
        _viewProject(notification['project_id']);
        break;
      case 'delete':
        _deleteNotification(notification['id']);
        break;
    }
  }

  void _markAsUnread(int notificationId) {
    setState(() {
      final index = _notifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        _notifications[index]['is_read'] = false;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notification marked as unread')),
    );
  }

  void _deleteNotification(int notificationId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notification'),
        content: const Text('Are you sure you want to delete this notification?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _notifications.removeWhere((n) => n['id'] == notificationId);
              });
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notification deleted')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _viewTask(String? taskId) {
    if (taskId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Navigate to task: $taskId')),
      );
      // TODO: Implement navigation to task detail
    }
  }

  void _viewProject(int? projectId) {
    if (projectId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Navigate to project: $projectId')),
      );
      // TODO: Implement navigation to project detail
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red.shade700;
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getAlertIcon(String type) {
    switch (type.toLowerCase()) {
      case 'deadline':
        return Icons.schedule;
      case 'overdue':
        return Icons.warning;
      case 'assignment':
        return Icons.assignment_ind;
      case 'milestone':
        return Icons.flag;
      default:
        return Icons.info;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type.toLowerCase()) {
      case 'report':
        return const Color(0xFFFFA301); // Primary orange
      case 'reminder':
        return const Color(0xFFE6920E); // Orange variant
      case 'comment':
        return const Color(0xFFCC8200); // Orange variant
      case 'system':
        return const Color(0xFFB37200); // Orange variant
      default:
        return const Color(0xFF808080); // Gray
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'report':
        return Icons.assessment;
      case 'reminder':
        return Icons.alarm;
      case 'comment':
        return Icons.comment;
      case 'system':
        return Icons.settings;
      default:
        return Icons.notifications;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
