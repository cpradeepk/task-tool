import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../main_layout.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3003');

class ChatSystemScreen extends StatefulWidget {
  const ChatSystemScreen({super.key});

  @override
  State<ChatSystemScreen> createState() => _ChatSystemScreenState();
}

class _ChatSystemScreenState extends State<ChatSystemScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<dynamic> _channels = [];
  List<dynamic> _messages = [];
  int? _selectedChannelId;
  String? _currentUserEmail;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadChannels();
  }

  Future<String?> _getJwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserEmail = prefs.getString('email');
    });
  }

  Future<void> _loadChannels() async {
    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.get(
        Uri.parse('$apiBase/task/api/chat/channels'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        setState(() => _channels = jsonDecode(response.body));
      } else {
        // Use mock data
        setState(() => _channels = _generateMockChannels());
      }
    } catch (e) {
      setState(() => _channels = _generateMockChannels());
    }
  }

  List<dynamic> _generateMockChannels() {
    return [
      {'id': 1, 'name': 'General', 'description': 'General discussion', 'type': 'public'},
      {'id': 2, 'name': 'Development', 'description': 'Development team chat', 'type': 'public'},
      {'id': 3, 'name': 'Project Alpha', 'description': 'Project Alpha team', 'type': 'private'},
      {'id': 4, 'name': 'Announcements', 'description': 'Company announcements', 'type': 'public'},
    ];
  }

  Future<void> _loadMessages(int channelId) async {
    setState(() => _isLoading = true);

    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.get(
        Uri.parse('$apiBase/task/api/chat/channels/$channelId/messages'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        setState(() => _messages = jsonDecode(response.body));
      } else {
        // Use mock data
        setState(() => _messages = _generateMockMessages(channelId));
      }
    } catch (e) {
      setState(() => _messages = _generateMockMessages(channelId));
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  List<dynamic> _generateMockMessages(int channelId) {
    final now = DateTime.now();
    return [
      {
        'id': 1,
        'user_email': 'john@example.com',
        'message': 'Hello everyone! How is the project going?',
        'timestamp': now.subtract(const Duration(hours: 2)).toIso8601String(),
        'channel_id': channelId,
      },
      {
        'id': 2,
        'user_email': _currentUserEmail,
        'message': 'Hi John! We\'re making good progress on the dashboard.',
        'timestamp': now.subtract(const Duration(hours: 1, minutes: 30)).toIso8601String(),
        'channel_id': channelId,
      },
      {
        'id': 3,
        'user_email': 'sarah@example.com',
        'message': 'The PERT analysis feature is almost complete!',
        'timestamp': now.subtract(const Duration(minutes: 45)).toIso8601String(),
        'channel_id': channelId,
      },
      {
        'id': 4,
        'user_email': 'mike@example.com',
        'message': 'Great work team! Let me know if you need any help with testing.',
        'timestamp': now.subtract(const Duration(minutes: 15)).toIso8601String(),
        'channel_id': channelId,
      },
    ];
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _selectedChannelId == null) return;

    final jwt = await _getJwt();
    if (jwt == null) return;

    final message = _messageController.text.trim();
    _messageController.clear();

    try {
      final response = await http.post(
        Uri.parse('$apiBase/task/api/chat/channels/$_selectedChannelId/messages'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'message': message}),
      );

      if (response.statusCode == 201) {
        _loadMessages(_selectedChannelId!);
      } else {
        // Add message locally for demo
        setState(() {
          _messages.add({
            'id': _messages.length + 1,
            'user_email': _currentUserEmail,
            'message': message,
            'timestamp': DateTime.now().toIso8601String(),
            'channel_id': _selectedChannelId,
          });
        });
        _scrollToBottom();
      }
    } catch (e) {
      // Add message locally for demo
      setState(() {
        _messages.add({
          'id': _messages.length + 1,
          'user_email': _currentUserEmail,
          'message': message,
          'timestamp': DateTime.now().toIso8601String(),
          'channel_id': _selectedChannelId,
        });
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Team Chat',
      child: Row(
        children: [
          // Channels Sidebar
          Container(
            width: 250,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              children: [
                // Channels Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 2,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.chat, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Channels',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Channels List
                Expanded(
                  child: ListView.builder(
                    itemCount: _channels.length,
                    itemBuilder: (context, index) {
                      final channel = _channels[index];
                      final isSelected = _selectedChannelId == channel['id'];
                      
                      return ListTile(
                        leading: Icon(
                          channel['type'] == 'private' ? Icons.lock : Icons.tag,
                          color: isSelected ? Colors.blue : Colors.grey,
                        ),
                        title: Text(
                          channel['name'],
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.blue : Colors.black,
                          ),
                        ),
                        subtitle: Text(
                          channel['description'],
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: isSelected,
                        selectedTileColor: Colors.blue.shade50,
                        onTap: () {
                          setState(() => _selectedChannelId = channel['id']);
                          _loadMessages(channel['id']);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Chat Area
          Expanded(
            child: _selectedChannelId == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Select a channel to start chatting',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Chat Header
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 2,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getSelectedChannel()['type'] == 'private' ? Icons.lock : Icons.tag,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getSelectedChannel()['name'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_messages.length} messages',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      // Messages Area
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(16),
                                itemCount: _messages.length,
                                itemBuilder: (context, index) {
                                  final message = _messages[index];
                                  final isCurrentUser = message['user_email'] == _currentUserEmail;
                                  final timestamp = DateTime.parse(message['timestamp']);
                                  
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: isCurrentUser
                                          ? MainAxisAlignment.end
                                          : MainAxisAlignment.start,
                                      children: [
                                        if (!isCurrentUser) ...[
                                          CircleAvatar(
                                            backgroundColor: Colors.blue,
                                            radius: 16,
                                            child: Text(
                                              message['user_email'].substring(0, 1).toUpperCase(),
                                              style: const TextStyle(color: Colors.white, fontSize: 12),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        Flexible(
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: isCurrentUser ? Colors.blue : Colors.grey.shade200,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (!isCurrentUser)
                                                  Text(
                                                    message['user_email'].split('@')[0],
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                Text(
                                                  message['message'],
                                                  style: TextStyle(
                                                    color: isCurrentUser ? Colors.white : Colors.black,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: isCurrentUser 
                                                        ? Colors.white.withOpacity(0.7)
                                                        : Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (isCurrentUser) ...[
                                          const SizedBox(width: 8),
                                          CircleAvatar(
                                            backgroundColor: Colors.green,
                                            radius: 16,
                                            child: Text(
                                              message['user_email'].substring(0, 1).toUpperCase(),
                                              style: const TextStyle(color: Colors.white, fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      // Message Input
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(top: BorderSide(color: Colors.grey.shade300)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                decoration: InputDecoration(
                                  hintText: 'Type a message...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FloatingActionButton(
                              mini: true,
                              onPressed: _sendMessage,
                              child: const Icon(Icons.send),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getSelectedChannel() {
    return _channels.firstWhere(
      (channel) => channel['id'] == _selectedChannelId,
      orElse: () => {'name': 'Unknown', 'type': 'public'},
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
