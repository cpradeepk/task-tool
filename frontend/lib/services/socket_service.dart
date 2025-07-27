import 'dart:async';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import '../config/environment.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;
  
  // Stream controllers for different event types
  final StreamController<Map<String, dynamic>> _messageController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _notificationController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _activityController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _taskUpdateController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _typingController = StreamController.broadcast();
  final StreamController<bool> _connectionController = StreamController.broadcast();

  // Getters for streams
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get notificationStream => _notificationController.stream;
  Stream<Map<String, dynamic>> get activityStream => _activityController.stream;
  Stream<Map<String, dynamic>> get taskUpdateStream => _taskUpdateController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  bool get isConnected => _isConnected;

  Future<void> connect() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        debugPrint('No auth token available for socket connection');
        return;
      }

      final baseUrl = Environment.socketUrl;
      
      _socket = IO.io(baseUrl, IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setAuth({'token': token})
          .build());

      _setupEventListeners();
      
      debugPrint('Socket.IO connection initiated');
    } catch (e) {
      debugPrint('Error connecting to socket: $e');
    }
  }

  void _setupEventListeners() {
    if (_socket == null) return;

    // Connection events
    _socket!.onConnect((_) {
      debugPrint('Socket connected');
      _isConnected = true;
      _connectionController.add(true);
    });

    _socket!.onDisconnect((_) {
      debugPrint('Socket disconnected');
      _isConnected = false;
      _connectionController.add(false);
    });

    _socket!.onConnectError((error) {
      debugPrint('Socket connection error: $error');
      _isConnected = false;
      _connectionController.add(false);
    });

    // Chat events
    _socket!.on('new_message', (data) {
      debugPrint('New message received: $data');
      _messageController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('message_updated', (data) {
      debugPrint('Message updated: $data');
      _messageController.add({
        'type': 'message_updated',
        ...Map<String, dynamic>.from(data)
      });
    });

    _socket!.on('message_deleted', (data) {
      debugPrint('Message deleted: $data');
      _messageController.add({
        'type': 'message_deleted',
        ...Map<String, dynamic>.from(data)
      });
    });

    _socket!.on('user_typing', (data) {
      debugPrint('User typing: $data');
      _typingController.add({
        'type': 'typing_start',
        ...Map<String, dynamic>.from(data)
      });
    });

    _socket!.on('user_stopped_typing', (data) {
      debugPrint('User stopped typing: $data');
      _typingController.add({
        'type': 'typing_stop',
        ...Map<String, dynamic>.from(data)
      });
    });

    _socket!.on('user_joined_channel', (data) {
      debugPrint('User joined channel: $data');
      _messageController.add({
        'type': 'user_joined',
        ...Map<String, dynamic>.from(data)
      });
    });

    _socket!.on('user_left_channel', (data) {
      debugPrint('User left channel: $data');
      _messageController.add({
        'type': 'user_left',
        ...Map<String, dynamic>.from(data)
      });
    });

    _socket!.on('messages_read', (data) {
      debugPrint('Messages read: $data');
      _messageController.add({
        'type': 'messages_read',
        ...Map<String, dynamic>.from(data)
      });
    });

    // Notification events
    _socket!.on('new_notification', (data) {
      debugPrint('New notification: $data');
      _notificationController.add({
        'type': 'new_notification',
        ...Map<String, dynamic>.from(data)
      });
    });

    _socket!.on('notification_read', (data) {
      debugPrint('Notification read: $data');
      _notificationController.add({
        'type': 'notification_read',
        ...Map<String, dynamic>.from(data)
      });
    });

    _socket!.on('all_notifications_read', (data) {
      debugPrint('All notifications read: $data');
      _notificationController.add({
        'type': 'all_notifications_read',
        ...Map<String, dynamic>.from(data)
      });
    });

    // Activity events
    _socket!.on('new_activity', (data) {
      debugPrint('New activity: $data');
      _activityController.add({
        'type': 'new_activity',
        ...Map<String, dynamic>.from(data)
      });
    });

    // Task events
    _socket!.on('task_updated', (data) {
      debugPrint('Task updated: $data');
      _taskUpdateController.add({
        'type': 'task_updated',
        ...Map<String, dynamic>.from(data)
      });
    });

    // Channel events
    _socket!.on('channel_created', (data) {
      debugPrint('Channel created: $data');
      _messageController.add({
        'type': 'channel_created',
        ...Map<String, dynamic>.from(data)
      });
    });
  }

  // Chat methods
  void joinChannel(String channelId) {
    if (_socket?.connected == true) {
      _socket!.emit('join_channel', {'channelId': channelId});
      debugPrint('Joined channel: $channelId');
    }
  }

  void leaveChannel(String channelId) {
    if (_socket?.connected == true) {
      _socket!.emit('leave_channel', {'channelId': channelId});
      debugPrint('Left channel: $channelId');
    }
  }

  void sendMessage({
    String? channelId,
    String? recipientId,
    required String content,
    String messageType = 'TEXT',
    String? parentMessageId,
  }) {
    if (_socket?.connected == true) {
      _socket!.emit('send_message', {
        'channelId': channelId,
        'recipientId': recipientId,
        'content': content,
        'messageType': messageType,
        'parentMessageId': parentMessageId,
      });
      debugPrint('Message sent to ${channelId ?? recipientId}');
    }
  }

  void startTyping({String? channelId, String? recipientId}) {
    if (_socket?.connected == true) {
      _socket!.emit('typing_start', {
        'channelId': channelId,
        'recipientId': recipientId,
      });
    }
  }

  void stopTyping({String? channelId, String? recipientId}) {
    if (_socket?.connected == true) {
      _socket!.emit('typing_stop', {
        'channelId': channelId,
        'recipientId': recipientId,
      });
    }
  }

  void markAsRead(String channelId, {String? messageId}) {
    if (_socket?.connected == true) {
      _socket!.emit('mark_read', {
        'channelId': channelId,
        'messageId': messageId,
      });
    }
  }

  // Notification methods
  void markNotificationAsRead(String notificationId) {
    if (_socket?.connected == true) {
      _socket!.emit('mark_notification_read', {
        'notificationId': notificationId,
      });
    }
  }

  void markAllNotificationsAsRead() {
    if (_socket?.connected == true) {
      _socket!.emit('mark_all_notifications_read', {});
    }
  }

  // Task methods
  void joinTask(String taskId) {
    if (_socket?.connected == true) {
      _socket!.emit('join_task', {'taskId': taskId});
    }
  }

  void leaveTask(String taskId) {
    if (_socket?.connected == true) {
      _socket!.emit('leave_task', {'taskId': taskId});
    }
  }

  void emitTaskUpdate(String taskId, String projectId, Map<String, dynamic> update) {
    if (_socket?.connected == true) {
      _socket!.emit('task_update', {
        'taskId': taskId,
        'projectId': projectId,
        'update': update,
      });
    }
  }

  // Project methods
  void joinProject(String projectId) {
    if (_socket?.connected == true) {
      _socket!.emit('join_project', {'projectId': projectId});
    }
  }

  void leaveProject(String projectId) {
    if (_socket?.connected == true) {
      _socket!.emit('leave_project', {'projectId': projectId});
    }
  }

  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
      _isConnected = false;
      _connectionController.add(false);
      debugPrint('Socket disconnected manually');
    }
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _notificationController.close();
    _activityController.close();
    _taskUpdateController.close();
    _typingController.close();
    _connectionController.close();
  }
}
