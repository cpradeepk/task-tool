import 'dart:async';
import '../models/chat.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final SocketService _socketService = SocketService();
  
  // Stream controllers for chat events
  final StreamController<ChatMessage> _messageController = StreamController.broadcast();
  final StreamController<ChatChannel> _channelController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _typingController = StreamController.broadcast();

  // Getters for streams
  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<ChatChannel> get channelStream => _channelController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;

  // Initialize chat service
  Future<void> initialize() async {
    // Listen to socket events
    _socketService.messageStream.listen((data) {
      _handleSocketMessage(data);
    });

    _socketService.typingStream.listen((data) {
      _typingController.add(data);
    });
  }

  void _handleSocketMessage(Map<String, dynamic> data) {
    final type = data['type'];
    
    switch (type) {
      case 'new_message':
        final message = ChatMessage.fromJson(data);
        _messageController.add(message);
        break;
        
      case 'message_updated':
        final message = ChatMessage.fromJson(data);
        _messageController.add(message);
        break;
        
      case 'channel_created':
        final channel = ChatChannel.fromJson(data);
        _channelController.add(channel);
        break;
    }
  }

  // Channel management
  Future<List<ChatChannel>> getChannels({String? projectId}) async {
    try {
      final queryParams = <String, String>{};
      if (projectId != null) {
        queryParams['projectId'] = projectId;
      }

      final response = await ApiService.get('/chat/channels', queryParams: queryParams);
      return (response as List<dynamic>)
          .map((data) => ChatChannel.fromJson(data))
          .toList();
    } catch (e) {
      throw Exception('Failed to get channels: $e');
    }
  }

  Future<ChatChannel> createChannel({
    required String name,
    String? description,
    bool isPrivate = false,
    String? projectId,
    String channelType = 'PROJECT',
  }) async {
    try {
      final response = await ApiService.post('/chat/channels', {
        'name': name,
        'description': description,
        'isPrivate': isPrivate,
        'projectId': projectId,
        'channelType': channelType,
      });

      return ChatChannel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create channel: $e');
    }
  }

  Future<ChatChannel> getChannel(String channelId) async {
    try {
      final response = await ApiService.get('/chat/channels/$channelId');
      return ChatChannel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get channel: $e');
    }
  }

  Future<ChatChannel> updateChannel(String channelId, {
    String? name,
    String? description,
    bool? isPrivate,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;
      if (isPrivate != null) data['isPrivate'] = isPrivate;

      final response = await ApiService.put('/chat/channels/$channelId', data);
      return ChatChannel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update channel: $e');
    }
  }

  Future<void> deleteChannel(String channelId) async {
    try {
      await ApiService.delete('/chat/channels/$channelId');
    } catch (e) {
      throw Exception('Failed to delete channel: $e');
    }
  }

  Future<void> joinChannel(String channelId) async {
    try {
      await ApiService.post('/chat/channels/$channelId/join', {});
      _socketService.joinChannel(channelId);
    } catch (e) {
      throw Exception('Failed to join channel: $e');
    }
  }

  Future<void> leaveChannel(String channelId) async {
    try {
      await ApiService.post('/chat/channels/$channelId/leave', {});
      _socketService.leaveChannel(channelId);
    } catch (e) {
      throw Exception('Failed to leave channel: $e');
    }
  }

  // Message management
  Future<Map<String, dynamic>> getMessages({
    String? channelId,
    String? recipientId,
    int page = 1,
    int limit = 50,
    String? parentMessageId,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (channelId != null) queryParams['channelId'] = channelId;
      if (recipientId != null) queryParams['recipientId'] = recipientId;
      if (parentMessageId != null) queryParams['parentMessageId'] = parentMessageId;

      final response = await ApiService.get('/chat/messages', queryParams: queryParams);
      
      return {
        'messages': (response['messages'] as List<dynamic>)
            .map((data) => ChatMessage.fromJson(data))
            .toList(),
        'pagination': response['pagination'],
      };
    } catch (e) {
      throw Exception('Failed to get messages: $e');
    }
  }

  Future<ChatMessage> sendMessage({
    String? channelId,
    String? recipientId,
    required String content,
    String messageType = 'TEXT',
    String? parentMessageId,
  }) async {
    try {
      final response = await ApiService.post('/chat/messages', {
        'channelId': channelId,
        'recipientId': recipientId,
        'content': content,
        'messageType': messageType,
        'parentMessageId': parentMessageId,
      });

      return ChatMessage.fromJson(response);
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  Future<ChatMessage> updateMessage(String messageId, {
    required String content,
  }) async {
    try {
      final response = await ApiService.put('/chat/messages/$messageId', {
        'content': content,
      });

      return ChatMessage.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update message: $e');
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await ApiService.delete('/chat/messages/$messageId');
    } catch (e) {
      throw Exception('Failed to delete message: $e');
    }
  }

  // Direct conversations
  Future<List<DirectConversation>> getDirectConversations() async {
    try {
      final response = await ApiService.get('/chat/conversations');
      return (response as List<dynamic>)
          .map((data) => DirectConversation.fromJson(data))
          .toList();
    } catch (e) {
      throw Exception('Failed to get conversations: $e');
    }
  }

  // Real-time features
  void startTyping({String? channelId, String? recipientId}) {
    _socketService.startTyping(channelId: channelId, recipientId: recipientId);
  }

  void stopTyping({String? channelId, String? recipientId}) {
    _socketService.stopTyping(channelId: channelId, recipientId: recipientId);
  }

  void markAsRead(String channelId, {String? messageId}) {
    _socketService.markAsRead(channelId, messageId: messageId);
  }

  // Utility methods
  Future<void> markChannelAsRead(String channelId) async {
    try {
      await ApiService.post('/chat/channels/$channelId/read', {});
    } catch (e) {
      throw Exception('Failed to mark channel as read: $e');
    }
  }

  // Search messages
  Future<List<ChatMessage>> searchMessages({
    required String query,
    String? channelId,
    String? projectId,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'q': query,
        'limit': limit.toString(),
      };

      if (channelId != null) queryParams['channelId'] = channelId;
      if (projectId != null) queryParams['projectId'] = projectId;

      final response = await ApiService.get('/chat/search', queryParams: queryParams);
      return (response['messages'] as List<dynamic>)
          .map((data) => ChatMessage.fromJson(data))
          .toList();
    } catch (e) {
      throw Exception('Failed to search messages: $e');
    }
  }

  void dispose() {
    _messageController.close();
    _channelController.close();
    _typingController.close();
  }
}
