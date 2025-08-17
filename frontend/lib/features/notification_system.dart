import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../main_layout.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3003');

class NotificationSystemScreen extends StatefulWidget {
  const NotificationSystemScreen({super.key});

  @override
  State<NotificationSystemScreen> createState() => _NotificationSystemScreenState();
}

class _NotificationSystemScreenState extends State<NotificationSystemScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _notifications = [];
  List<dynamic> _filteredNotifications = [];
  bool _isLoading = false;
  String _selectedFilter = 'All';
  String _selectedType = 'All';
  bool _showUnreadOnly = false;

  final List<String> _filters = ['All', 'Today', 'This Week', 'This Month'];
  final List<String> _types = ['All', 'Task', 'Project', 'System', 'Chat', 'Reminder'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadNotifications();
  }

  Future<String?> _getJwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);

    try {
      final jwt = await _getJwt();
      if (jwt != null) {
        final response = await http.get(
          Uri.parse('$apiBase/task/api/notifications'),
          headers: {'Authorization': 'Bearer $jwt'},
        );

        if (response.statusCode == 200) {
          setState(() => _notifications = jsonDecode(response.body));
        }
      }
    } catch (e) {
      // Use mock notifications for development
      setState(() => _notifications = _generateMockNotifications());
    } finally {
      setState(() => _isLoading = false);
      _applyFilters();
    }
  }

  List<dynamic> _generateMockNotifications() {
    final now = DateTime.now();
    return [
      {
        'id': 1,
        'title': 'Task Deadline Approaching',
        'message': 'Your task "Frontend Development" is due tomorrow',
        'type': 'Task',
        'priority': 'High',
        'is_read': false,
        'created_at': now.subtract(const Duration(hours: 2)).toIso8601String(),
        'action_url': '/tasks/123',
        'icon': 'schedule',
      },
      {
        'id': 2,
        'title': 'New Project Assignment',
        'message': 'You have been assigned to project "Mobile App Development"',
        'type': 'Project',
        'priority': 'Medium',
        'is_read': false,
        'created_at': now.subtract(const Duration(hours: 4)).toIso8601String(),
        'action_url': '/projects/456',
        'icon': 'assignment',
      },
      {
        'id': 3,
        'title': 'System Maintenance',
        'message': 'Scheduled maintenance will occur tonight from 2-4 AM',
        'type': 'System',
        'priority': 'Low',
        'is_read': true,
        'created_at': now.subtract(const Duration(hours: 8)).toIso8601String(),
        'action_url': null,
        'icon': 'build',
      },
      {
        'id': 4,
        'title': 'New Chat Message',
        'message': 'John Doe sent a message in #development channel',
        'type': 'Chat',
        'priority': 'Low',
        'is_read': false,
        'created_at': now.subtract(const Duration(minutes: 30)).toIso8601String(),
        'action_url': '/chat/development',
        'icon': 'chat',
      },
      {
        'id': 5,
        'title': 'Meeting Reminder',
        'message': 'Daily standup meeting starts in 15 minutes',
        'type': 'Reminder',
        'priority': 'High',
        'is_read': false,
        'created_at': now.subtract(const Duration(minutes: 15)).toIso8601String(),
        'action_url': '/calendar',
        'icon': 'event',
      },
      {
        'id': 6,
        'title': 'Task Completed',
        'message': 'Sarah Wilson completed task "Database Schema Design"',
        'type': 'Task',
        'priority': 'Medium',
        'is_read': true,
        'created_at': now.subtract(const Duration(days: 1)).toIso8601String(),
        'action_url': '/tasks/789',
        'icon': 'check_circle',
      },
    ];
  }

  void _applyFilters() {
    setState(() {
      _filteredNotifications = _notifications.where((notification) {
        // Type filter
        final matchesType = _selectedType == 'All' || notification['type'] == _selectedType;
        
        // Read status filter
        final matchesReadStatus = !_showUnreadOnly || !notification['is_read'];
        
        // Date filter
        final notificationDate = DateTime.parse(notification['created_at']);
        final now = DateTime.now();
        bool matchesDate = true;
        
        switch (_selectedFilter) {
          case 'Today':
            matchesDate = notificationDate.isAfter(DateTime(now.year, now.month, now.day));
            break;
          case 'This Week':
            final weekStart = now.subtract(Duration(days: now.weekday - 1));
            matchesDate = notificationDate.isAfter(DateTime(weekStart.year, weekStart.month, weekStart.day));
            break;
          case 'This Month':
            matchesDate = notificationDate.isAfter(DateTime(now.year, now.month, 1));
            break;
        }
        
        return matchesType && matchesReadStatus && matchesDate;
      }).toList();
      
      // Sort by creation date (newest first)
      _filteredNotifications.sort((a, b) => 
        DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at']))
      );
    });
  }

  Future<void> _markAsRead(int notificationId) async {
    try {
      final jwt = await _getJwt();
      if (jwt != null) {
        await http.patch(
          Uri.parse('$apiBase/task/api/notifications/$notificationId/read'),
          headers: {'Authorization': 'Bearer $jwt'},
        );
      }
    } catch (e) {
      // Handle error
    }

    // Update local state
    setState(() {
      final index = _notifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        _notifications[index]['is_read'] = true;
      }
    });
    _applyFilters();
  }

  Future<void> _markAllAsRead() async {
    try {
      final jwt = await _getJwt();
      if (jwt != null) {
        await http.patch(
          Uri.parse('$apiBase/task/api/notifications/mark-all-read'),
          headers: {'Authorization': 'Bearer $jwt'},
        );
      }
    } catch (e) {
      // Handle error
    }

    // Update local state
    setState(() {
      for (var notification in _notifications) {
        notification['is_read'] = true;
      }
    });
    _applyFilters();
  }

  Future<void> _deleteNotification(int notificationId) async {
    try {
      final jwt = await _getJwt();
      if (jwt != null) {
        await http.delete(
          Uri.parse('$apiBase/task/api/notifications/$notificationId'),
          headers: {'Authorization': 'Bearer $jwt'},
        );
      }
    } catch (e) {
      // Handle error
    }

    // Update local state
    setState(() {
      _notifications.removeWhere((n) => n['id'] == notificationId);
    });
    _applyFilters();
  }

  IconData _getNotificationIcon(String iconName) {
    switch (iconName) {
      case 'schedule': return Icons.schedule;
      case 'assignment': return Icons.assignment;
      case 'build': return Icons.build;
      case 'chat': return Icons.chat;
      case 'event': return Icons.event;
      case 'check_circle': return Icons.check_circle;
      default: return Icons.notifications;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High': return Colors.red;
      case 'Medium': return Colors.orange;
      case 'Low': return Colors.green;
      default: return Colors.grey;
    }
  }

  String _formatTime(String timestamp) {
    final dateTime = DateTime.parse(timestamp);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n['is_read']).length;
    
    return MainLayout(
      title: 'Notifications',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.notifications, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Notifications',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
                const Spacer(),
                if (unreadCount > 0)
                  ElevatedButton.icon(
                    onPressed: _markAllAsRead,
                    icon: const Icon(Icons.done_all),
                    label: const Text('Mark All Read'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _loadNotifications,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Filters
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  // Time filter
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Time Period',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      value: _selectedFilter,
                      items: _filters.map((filter) => DropdownMenuItem(
                        value: filter,
                        child: Text(filter),
                      )).toList(),
                      onChanged: (value) {
                        setState(() => _selectedFilter = value!);
                        _applyFilters();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Type filter
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      value: _selectedType,
                      items: _types.map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      )).toList(),
                      onChanged: (value) {
                        setState(() => _selectedType = value!);
                        _applyFilters();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Unread only toggle
                  Row(
                    children: [
                      Checkbox(
                        value: _showUnreadOnly,
                        onChanged: (value) {
                          setState(() => _showUnreadOnly = value!);
                          _applyFilters();
                        },
                      ),
                      const Text('Unread only'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Notifications List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredNotifications.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.notifications_off, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('No notifications found', style: TextStyle(fontSize: 18, color: Colors.grey)),
                              Text('Adjust your filters or check back later', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredNotifications.length,
                          itemBuilder: (context, index) {
                            final notification = _filteredNotifications[index];
                            final isUnread = !notification['is_read'];
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: isUnread ? 2 : 1,
                              child: ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _getPriorityColor(notification['priority']).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(
                                    _getNotificationIcon(notification['icon']),
                                    color: _getPriorityColor(notification['priority']),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        notification['title'],
                                        style: TextStyle(
                                          fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    if (isUnread)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.blue,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(notification['message']),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Chip(
                                          label: Text(
                                            notification['type'],
                                            style: const TextStyle(fontSize: 10),
                                          ),
                                          backgroundColor: _getPriorityColor(notification['priority']).withValues(alpha: 0.2),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatTime(notification['created_at']),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (action) {
                                    switch (action) {
                                      case 'mark_read':
                                        if (isUnread) _markAsRead(notification['id']);
                                        break;
                                      case 'delete':
                                        _deleteNotification(notification['id']);
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    if (isUnread)
                                      const PopupMenuItem(
                                        value: 'mark_read',
                                        child: Row(
                                          children: [
                                            Icon(Icons.mark_email_read, size: 16),
                                            SizedBox(width: 8),
                                            Text('Mark as Read'),
                                          ],
                                        ),
                                      ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, size: 16, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Delete'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  if (isUnread) _markAsRead(notification['id']);
                                  if (notification['action_url'] != null) {
                                    // Navigate to the action URL
                                    // context.go(notification['action_url']);
                                  }
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
