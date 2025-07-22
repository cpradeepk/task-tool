import 'package:flutter/material.dart';
import 'dart:async';
import '../models/notification.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class NotificationCenter extends StatefulWidget {
  const NotificationCenter({Key? key}) : super(key: key);

  @override
  State<NotificationCenter> createState() => _NotificationCenterState();
}

class _NotificationCenterState extends State<NotificationCenter> with TickerProviderStateMixin {
  late TabController _tabController;
  final SocketService _socketService = SocketService();
  
  List<AppNotification> _allNotifications = [];
  List<AppNotification> _unreadNotifications = [];
  NotificationStats? _stats;
  
  bool _isLoading = true;
  String? _error;
  
  StreamSubscription? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadNotifications();
    _setupSocketListener();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _setupSocketListener() {
    _notificationSubscription = _socketService.notificationStream.listen((data) {
      _handleSocketNotification(data);
    });
  }

  void _handleSocketNotification(Map<String, dynamic> data) {
    final type = data['type'];
    
    switch (type) {
      case 'new_notification':
        final notification = AppNotification.fromJson(data);
        setState(() {
          _allNotifications.insert(0, notification);
          if (!notification.isRead) {
            _unreadNotifications.insert(0, notification);
          }
          _updateStats();
        });
        break;
        
      case 'notification_read':
        final notificationId = data['notificationId'];
        setState(() {
          _markNotificationAsRead(notificationId);
        });
        break;
        
      case 'all_notifications_read':
        setState(() {
          _markAllAsRead();
        });
        break;
    }
  }

  Future<void> _loadNotifications() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final [allResponse, unreadResponse, statsResponse] = await Future.wait([
        ApiService.get('/notifications'),
        ApiService.get('/notifications', queryParams: {'isRead': 'false'}),
        ApiService.get('/notifications/stats'),
      ]);

      final allNotifications = (allResponse['notifications'] as List<dynamic>)
          .map((data) => AppNotification.fromJson(data))
          .toList();

      final unreadNotifications = (unreadResponse['notifications'] as List<dynamic>)
          .map((data) => AppNotification.fromJson(data))
          .toList();

      final stats = NotificationStats.fromJson(statsResponse);

      setState(() {
        _allNotifications = allNotifications;
        _unreadNotifications = unreadNotifications;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _markNotificationAsRead(String notificationId) {
    final index = _allNotifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _allNotifications[index] = _allNotifications[index].copyWith(
        isRead: true,
        readAt: DateTime.now(),
      );
    }
    
    _unreadNotifications.removeWhere((n) => n.id == notificationId);
    _updateStats();
  }

  void _markAllAsRead() {
    for (int i = 0; i < _allNotifications.length; i++) {
      if (!_allNotifications[i].isRead) {
        _allNotifications[i] = _allNotifications[i].copyWith(
          isRead: true,
          readAt: DateTime.now(),
        );
      }
    }
    _unreadNotifications.clear();
    _updateStats();
  }

  void _updateStats() {
    if (_stats != null) {
      _stats = NotificationStats(
        total: _allNotifications.length,
        unread: _unreadNotifications.length,
        byType: _stats!.byType,
      );
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await ApiService.put('/notifications/$notificationId/read', {});
      _markNotificationAsRead(notificationId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark notification as read: $e')),
      );
    }
  }

  Future<void> _markAllAsReadAction() async {
    try {
      await ApiService.post('/notifications/mark-all-read', {});
      _markAllAsRead();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark all as read: $e')),
      );
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await ApiService.delete('/notifications/$notificationId');
      
      setState(() {
        _allNotifications.removeWhere((n) => n.id == notificationId);
        _unreadNotifications.removeWhere((n) => n.id == notificationId);
        _updateStats();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete notification: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              text: 'Unread',
              icon: _unreadNotifications.isNotEmpty
                  ? Badge(
                      label: Text('${_unreadNotifications.length}'),
                      child: const Icon(Icons.notifications),
                    )
                  : const Icon(Icons.notifications),
            ),
            const Tab(
              text: 'All',
              icon: Icon(Icons.list),
            ),
          ],
        ),
        actions: [
          if (_unreadNotifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all),
              onPressed: _markAllAsReadAction,
              tooltip: 'Mark all as read',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading notifications'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadNotifications,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildNotificationsList(_unreadNotifications, showEmpty: true),
        _buildNotificationsList(_allNotifications),
      ],
    );
  }

  Widget _buildNotificationsList(List<AppNotification> notifications, {bool showEmpty = false}) {
    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              showEmpty ? Icons.notifications_none : Icons.check_circle_outline,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              showEmpty ? 'No unread notifications' : 'No notifications',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              showEmpty ? 'You\'re all caught up!' : 'Notifications will appear here',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _buildNotificationCard(notification);
      },
    );
  }

  Widget _buildNotificationCard(AppNotification notification) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: notification.isRead ? 1 : 3,
      child: InkWell(
        onTap: () async {
          if (!notification.isRead) {
            await _markAsRead(notification.id);
          }
          
          // Navigate to related content if available
          if (notification.hasTask) {
            // Navigate to task details
          } else if (notification.hasProject) {
            // Navigate to project details
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: notification.isRead ? null : Colors.blue[50],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildNotificationIcon(notification.type),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.message,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'mark_read':
                          if (!notification.isRead) {
                            _markAsRead(notification.id);
                          }
                          break;
                        case 'delete':
                          _deleteNotification(notification.id);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      if (!notification.isRead)
                        const PopupMenuItem(
                          value: 'mark_read',
                          child: Row(
                            children: [
                              Icon(Icons.done, size: 16),
                              SizedBox(width: 8),
                              Text('Mark as read'),
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
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (notification.hasTask) ...[
                    Icon(Icons.task, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      notification.taskTitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (notification.hasProject) ...[
                    Icon(Icons.folder, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      notification.projectName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  const Spacer(),
                  Text(
                    _formatTime(notification.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(NotificationType type) {
    IconData iconData;
    Color color;

    switch (type) {
      case NotificationType.taskAssigned:
        iconData = Icons.assignment_ind;
        color = Colors.blue;
        break;
      case NotificationType.taskCompleted:
        iconData = Icons.check_circle;
        color = Colors.green;
        break;
      case NotificationType.taskOverdue:
        iconData = Icons.warning;
        color = Colors.red;
        break;
      case NotificationType.commentAdded:
        iconData = Icons.comment;
        color = Colors.orange;
        break;
      case NotificationType.mention:
        iconData = Icons.alternate_email;
        color = Colors.purple;
        break;
      case NotificationType.deadlineReminder:
        iconData = Icons.schedule;
        color = Colors.amber;
        break;
      case NotificationType.success:
        iconData = Icons.check_circle;
        color = Colors.green;
        break;
      case NotificationType.warning:
        iconData = Icons.warning;
        color = Colors.orange;
        break;
      case NotificationType.error:
        iconData = Icons.error;
        color = Colors.red;
        break;
      default:
        iconData = Icons.info;
        color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, color: color, size: 20),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
