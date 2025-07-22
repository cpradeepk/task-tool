import 'dart:async';
import '../models/notification.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final SocketService _socketService = SocketService();
  
  // Stream controllers for notification events
  final StreamController<AppNotification> _notificationController = StreamController.broadcast();
  final StreamController<NotificationStats> _statsController = StreamController.broadcast();

  // Getters for streams
  Stream<AppNotification> get notificationStream => _notificationController.stream;
  Stream<NotificationStats> get statsStream => _statsController.stream;

  // Initialize notification service
  Future<void> initialize() async {
    // Listen to socket events
    _socketService.notificationStream.listen((data) {
      _handleSocketNotification(data);
    });
  }

  void _handleSocketNotification(Map<String, dynamic> data) {
    final type = data['type'];
    
    switch (type) {
      case 'new_notification':
        final notification = AppNotification.fromJson(data);
        _notificationController.add(notification);
        break;
        
      case 'notification_read':
        // Handle notification read event
        break;
        
      case 'all_notifications_read':
        // Handle all notifications read event
        break;
    }
  }

  // Get notifications
  Future<Map<String, dynamic>> getNotifications({
    int page = 1,
    int limit = 20,
    bool? isRead,
    NotificationType? type,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (isRead != null) queryParams['isRead'] = isRead.toString();
      if (type != null) queryParams['type'] = type.value;

      final response = await ApiService.get('/notifications', queryParams: queryParams);
      
      return {
        'notifications': (response['notifications'] as List<dynamic>)
            .map((data) => AppNotification.fromJson(data))
            .toList(),
        'pagination': response['pagination'],
      };
    } catch (e) {
      throw Exception('Failed to get notifications: $e');
    }
  }

  // Get notification statistics
  Future<NotificationStats> getNotificationStats() async {
    try {
      final response = await ApiService.get('/notifications/stats');
      return NotificationStats.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get notification stats: $e');
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await ApiService.put('/notifications/$notificationId/read', {});
      _socketService.markNotificationAsRead(notificationId);
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      await ApiService.post('/notifications/mark-all-read', {});
      _socketService.markAllNotificationsAsRead();
    } catch (e) {
      throw Exception('Failed to mark all notifications as read: $e');
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await ApiService.delete('/notifications/$notificationId');
    } catch (e) {
      throw Exception('Failed to delete notification: $e');
    }
  }

  // Get notification preferences
  Future<NotificationPreferences> getNotificationPreferences() async {
    try {
      final response = await ApiService.get('/notifications/preferences');
      return NotificationPreferences.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get notification preferences: $e');
    }
  }

  // Update notification preferences
  Future<NotificationPreferences> updateNotificationPreferences(
    NotificationPreferences preferences,
  ) async {
    try {
      final response = await ApiService.put('/notifications/preferences', preferences.toJson());
      return NotificationPreferences.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update notification preferences: $e');
    }
  }

  // Get unread count
  Future<int> getUnreadCount() async {
    try {
      final stats = await getNotificationStats();
      return stats.unread;
    } catch (e) {
      return 0;
    }
  }

  // Create notification (admin only)
  Future<AppNotification> createNotification({
    required String userId,
    required String title,
    required String message,
    required NotificationType type,
    String? taskId,
    String? projectId,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await ApiService.post('/notifications', {
        'userId': userId,
        'title': title,
        'message': message,
        'type': type.value,
        'taskId': taskId,
        'projectId': projectId,
        'data': data,
      });

      return AppNotification.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create notification: $e');
    }
  }

  // Create bulk notifications (admin only)
  Future<List<AppNotification>> createBulkNotifications(
    List<Map<String, dynamic>> notifications,
  ) async {
    try {
      final response = await ApiService.post('/notifications/bulk', {
        'notifications': notifications,
      });

      return (response as List<dynamic>)
          .map((data) => AppNotification.fromJson(data))
          .toList();
    } catch (e) {
      throw Exception('Failed to create bulk notifications: $e');
    }
  }

  // Test notification (admin only)
  Future<void> testNotification({
    required String userId,
    required String title,
    required String message,
    NotificationType type = NotificationType.info,
  }) async {
    try {
      await ApiService.post('/notifications/test', {
        'userId': userId,
        'title': title,
        'message': message,
        'type': type.value,
      });
    } catch (e) {
      throw Exception('Failed to send test notification: $e');
    }
  }

  // Local notification helpers
  void showLocalNotification(AppNotification notification) {
    // This would integrate with local notification plugins
    // For now, just add to stream
    _notificationController.add(notification);
  }

  // Filter notifications
  List<AppNotification> filterNotifications(
    List<AppNotification> notifications, {
    bool? isRead,
    NotificationType? type,
    String? search,
  }) {
    var filtered = notifications;

    if (isRead != null) {
      filtered = filtered.where((n) => n.isRead == isRead).toList();
    }

    if (type != null) {
      filtered = filtered.where((n) => n.type == type).toList();
    }

    if (search != null && search.isNotEmpty) {
      final searchLower = search.toLowerCase();
      filtered = filtered.where((n) =>
        n.title.toLowerCase().contains(searchLower) ||
        n.message.toLowerCase().contains(searchLower)
      ).toList();
    }

    return filtered;
  }

  // Group notifications by date
  Map<String, List<AppNotification>> groupNotificationsByDate(
    List<AppNotification> notifications,
  ) {
    final grouped = <String, List<AppNotification>>{};
    
    for (final notification in notifications) {
      final date = _formatDate(notification.createdAt);
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(notification);
    }

    return grouped;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final notificationDate = DateTime(date.year, date.month, date.day);

    if (notificationDate == today) {
      return 'Today';
    } else if (notificationDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else if (notificationDate.isAfter(today.subtract(const Duration(days: 7)))) {
      final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return weekdays[date.weekday - 1];
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void dispose() {
    _notificationController.close();
    _statsController.close();
  }
}
