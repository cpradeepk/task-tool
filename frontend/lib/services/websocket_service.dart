import 'dart:convert';
import 'dart:developer';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;
  String? _userId;
  String? _token;

  // Notification callbacks
  final List<Function(Map<String, dynamic>)> _notificationCallbacks = [];
  final List<Function(Map<String, dynamic>)> _taskUpdateCallbacks = [];
  final List<Function(Map<String, dynamic>)> _chatMessageCallbacks = [];

  bool get isConnected => _isConnected;

  // Initialize WebSocket connection
  Future<void> connect({required String userId, required String token}) async {
    try {
      _userId = userId;
      _token = token;

      const String baseUrl = kDebugMode 
          ? 'http://localhost:3003' 
          : 'https://task.amtariksha.com';

      _socket = IO.io('$baseUrl', <String, dynamic>{
        'path': '/task/socket.io/',
        'transports': ['websocket'],
        'autoConnect': false,
        'timeout': 20000,
      });

      _socket!.connect();

      _socket!.onConnect((_) {
        log('WebSocket connected');
        _isConnected = true;
        
        // Authenticate with the server
        _socket!.emit('authenticate', {
          'userId': userId,
          'token': token,
        });
      });

      _socket!.onDisconnect((_) {
        log('WebSocket disconnected');
        _isConnected = false;
      });

      _socket!.on('authenticated', (data) {
        log('WebSocket authenticated: $data');
        if (data['success'] == true) {
          _setupEventListeners();
        }
      });

      _socket!.on('welcome', (data) {
        log('WebSocket welcome: $data');
      });

      _socket!.onError((error) {
        log('WebSocket error: $error');
      });

    } catch (e) {
      log('WebSocket connection error: $e');
    }
  }

  // Setup event listeners
  void _setupEventListeners() {
    // Notification events
    _socket!.on('notification', (data) {
      log('Received notification: $data');
      _notifyCallbacks(_notificationCallbacks, data);
    });

    _socket!.on('notifications.pending', (data) {
      log('Received pending notifications: $data');
      _notifyCallbacks(_notificationCallbacks, data);
    });

    _socket!.on('notification.read', (data) {
      log('Notification marked as read: $data');
      _notifyCallbacks(_notificationCallbacks, data);
    });

    // Task events
    _socket!.on('task.created', (data) {
      log('Task created: $data');
      _notifyCallbacks(_taskUpdateCallbacks, data);
    });

    _socket!.on('task.updated', (data) {
      log('Task updated: $data');
      _notifyCallbacks(_taskUpdateCallbacks, data);
    });

    _socket!.on('task.status_changed', (data) {
      log('Task status changed: $data');
      _notifyCallbacks(_taskUpdateCallbacks, data);
    });

    // Chat events
    _socket!.on('chat.message', (data) {
      log('Chat message: $data');
      _notifyCallbacks(_chatMessageCallbacks, data);
    });

    // User activity events
    _socket!.on('user.activity', (data) {
      log('User activity: $data');
    });
  }

  // Helper method to notify callbacks
  void _notifyCallbacks(List<Function(Map<String, dynamic>)> callbacks, dynamic data) {
    final Map<String, dynamic> eventData = data is Map<String, dynamic> 
        ? data 
        : {'data': data};
    
    for (final callback in callbacks) {
      try {
        callback(eventData);
      } catch (e) {
        log('Error in callback: $e');
      }
    }
  }

  // Add notification listener
  void addNotificationListener(Function(Map<String, dynamic>) callback) {
    _notificationCallbacks.add(callback);
  }

  // Remove notification listener
  void removeNotificationListener(Function(Map<String, dynamic>) callback) {
    _notificationCallbacks.remove(callback);
  }

  // Add task update listener
  void addTaskUpdateListener(Function(Map<String, dynamic>) callback) {
    _taskUpdateCallbacks.add(callback);
  }

  // Remove task update listener
  void removeTaskUpdateListener(Function(Map<String, dynamic>) callback) {
    _taskUpdateCallbacks.remove(callback);
  }

  // Add chat message listener
  void addChatMessageListener(Function(Map<String, dynamic>) callback) {
    _chatMessageCallbacks.add(callback);
  }

  // Remove chat message listener
  void removeChatMessageListener(Function(Map<String, dynamic>) callback) {
    _chatMessageCallbacks.remove(callback);
  }

  // Send custom event
  void emit(String event, Map<String, dynamic> data) {
    if (_isConnected && _socket != null) {
      _socket!.emit(event, data);
    }
  }

  // Disconnect WebSocket
  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    _isConnected = false;
    _userId = null;
    _token = null;
    
    // Clear all callbacks
    _notificationCallbacks.clear();
    _taskUpdateCallbacks.clear();
    _chatMessageCallbacks.clear();
  }

  // Reconnect with stored credentials
  Future<void> reconnect() async {
    if (_userId != null && _token != null) {
      disconnect();
      await connect(userId: _userId!, token: _token!);
    }
  }

  // Test notification (for development)
  void sendTestNotification() {
    if (_isConnected && _socket != null) {
      _socket!.emit('test_notification', {
        'title': 'Test Notification',
        'message': 'This is a test notification from Flutter',
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }
}
