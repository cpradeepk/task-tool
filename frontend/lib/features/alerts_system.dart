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
    return [
      {
        'id': 1,
        'title': 'Daily Summary Report Available',
        'message': 'Your daily summary report for ${now.subtract(const Duration(days: 1)).toIso8601String().substring(0, 10)} is ready',
        'type': 'report',
        'created_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
        'is_read': false,
      },
      {
        'id': 2,
        'title': 'Team Meeting Reminder',
        'message': 'Sprint planning meeting starts in 30 minutes',
        'type': 'reminder',
        'created_at': now.subtract(const Duration(minutes: 30)).toIso8601String(),
        'is_read': false,
      },
      {
        'id': 3,
        'title': 'New Comment on Task',
        'message': 'John added a comment to "Complete user authentication"',
        'type': 'comment',
        'created_at': now.subtract(const Duration(hours: 3)).toIso8601String(),
        'is_read': true,
      },
      {
        'id': 4,
        'title': 'System Maintenance',
        'message': 'Scheduled maintenance will occur tonight from 2 AM to 4 AM',
        'type': 'system',
        'created_at': now.subtract(const Duration(hours: 6)).toIso8601String(),
        'is_read': true,
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return _buildNotificationCard(notification);
      },
    );
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
        trailing: !isRead
            ? IconButton(
                onPressed: () => _markAsRead(notification['id'], false),
                icon: const Icon(Icons.mark_email_read),
                tooltip: 'Mark as read',
              )
            : null,
      ),
    );
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
        return Colors.blue;
      case 'reminder':
        return Colors.orange;
      case 'comment':
        return Colors.green;
      case 'system':
        return Colors.purple;
      default:
        return Colors.grey;
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
