import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../modern_layout.dart';

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
  List<dynamic> _users = [];
  int? _selectedChannelId;
  String? _currentUserEmail;
  bool _isLoading = false;
  bool _isAdmin = false;

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
      _isAdmin = prefs.getBool('isAdmin') ?? false;
    });
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    // Mock users for development
    setState(() => _users = [
      {'id': '1', 'name': 'John Doe', 'email': 'john@example.com'},
      {'id': '2', 'name': 'Jane Smith', 'email': 'jane@example.com'},
      {'id': '3', 'name': 'Mike Johnson', 'email': 'mike@example.com'},
      {'id': '4', 'name': 'Sarah Wilson', 'email': 'sarah@example.com'},
    ]);
  }

  Future<void> _loadChannels() async {
    try {
      setState(() => _channels = _generateMockChannels());
    } catch (e) {
      setState(() => _channels = _generateMockChannels());
    }
  }

  List<dynamic> _generateMockChannels() {
    final now = DateTime.now();
    return [
      {
        'id': 1, 
        'name': 'General', 
        'description': 'General discussion for all team members', 
        'type': 'public',
        'created_at': now.subtract(const Duration(days: 30)).toIso8601String(),
        'member_count': 25,
        'is_archived': false,
      },
      {
        'id': 2, 
        'name': 'Development', 
        'description': 'Development team discussions and updates', 
        'type': 'public',
        'created_at': now.subtract(const Duration(days: 20)).toIso8601String(),
        'member_count': 8,
        'is_archived': false,
      },
      {
        'id': 3, 
        'name': 'Project Alpha', 
        'description': 'Private channel for Project Alpha team', 
        'type': 'private',
        'created_at': now.subtract(const Duration(days: 15)).toIso8601String(),
        'member_count': 5,
        'is_archived': false,
      },
    ];
  }

  Future<void> _loadMessages(int channelId) async {
    setState(() => _isLoading = true);

    try {
      // Mock messages for development
      final now = DateTime.now();
      setState(() => _messages = [
        {
          'id': 1,
          'message': 'Welcome to the team chat! 🎉',
          'user_email': 'admin@example.com',
          'timestamp': now.subtract(const Duration(hours: 2)).toIso8601String(),
          'channel_id': channelId,
        },
        {
          'id': 2,
          'message': 'Thanks for the warm welcome! Excited to be here.',
          'user_email': _currentUserEmail ?? 'user@example.com',
          'timestamp': now.subtract(const Duration(hours: 1)).toIso8601String(),
          'channel_id': channelId,
        },
        {
          'id': 3,
          'message': 'Let\'s discuss the upcoming project milestones.',
          'user_email': 'john@example.com',
          'timestamp': now.subtract(const Duration(minutes: 30)).toIso8601String(),
          'channel_id': channelId,
        },
      ]);
    } catch (e) {
      setState(() => _messages = []);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _selectedChannelId == null) return;

    final message = _messageController.text.trim();
    _messageController.clear();

    // Add message locally for demo
    setState(() {
      _messages.add({
        'id': _messages.length + 1,
        'message': message,
        'user_email': _currentUserEmail ?? 'user@example.com',
        'timestamp': DateTime.now().toIso8601String(),
        'channel_id': _selectedChannelId,
      });
    });

    // Scroll to bottom
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

  String _formatMessageTime(String timestamp) {
    final messageTime = DateTime.parse(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(messageTime.year, messageTime.month, messageTime.day);

    if (messageDate == today) {
      return DateFormat('HH:mm').format(messageTime);
    } else if (messageDate == yesterday) {
      return 'Yesterday ${DateFormat('HH:mm').format(messageTime)}';
    } else if (now.difference(messageTime).inDays < 7) {
      return '${DateFormat('EEEE HH:mm').format(messageTime)}';
    } else if (messageTime.year == now.year) {
      return DateFormat('MMM dd, HH:mm').format(messageTime);
    } else {
      return DateFormat('MMM dd, yyyy HH:mm').format(messageTime);
    }
  }

  void _showCreateChannelDialog() {
    if (!_isAdmin) return;

    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    String channelType = 'public';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New Channel'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Channel Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.tag),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: channelType,
                decoration: const InputDecoration(
                  labelText: 'Channel Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.security),
                ),
                items: const [
                  DropdownMenuItem(value: 'public', child: Text('Public')),
                  DropdownMenuItem(value: 'private', child: Text('Private')),
                ],
                onChanged: (value) => setDialogState(() => channelType = value!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  _createChannel(
                    nameController.text.trim(),
                    descriptionController.text.trim(),
                    channelType,
                  );
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _createChannel(String name, String description, String type) {
    final newChannel = {
      'id': _channels.length + 1,
      'name': name,
      'description': description,
      'type': type,
      'created_at': DateTime.now().toIso8601String(),
      'member_count': 1,
      'is_archived': false,
    };

    setState(() {
      _channels.add(newChannel);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Channel "$name" created successfully')),
    );
  }

  Map<String, dynamic> _getSelectedChannel() {
    return _channels.firstWhere(
      (channel) => channel['id'] == _selectedChannelId,
      orElse: () => {'name': 'Unknown', 'type': 'public'},
    );
  }

  @override
  Widget build(BuildContext context) {
    return ModernLayout(
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
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.chat, color: Colors.white),
                      const SizedBox(width: 8),
                      const Text(
                        'Channels',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_isAdmin)
                        IconButton(
                          onPressed: _showCreateChannelDialog,
                          icon: const Icon(Icons.add, color: Colors.white),
                          tooltip: 'Create Channel',
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
                        trailing: channel['member_count'] != null
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${channel['member_count']}',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              )
                            : null,
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
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getSelectedChannel()['type'] == 'private' ? Icons.lock : Icons.tag,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getSelectedChannel()['name'] ?? 'Unknown',
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
                      // Messages
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _messages.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No messages yet. Start the conversation!',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  )
                                : ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _messages.length,
                                    itemBuilder: (context, index) {
                                      final message = _messages[index];
                                      final isCurrentUser = message['user_email'] == _currentUserEmail;
                                      
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        child: Row(
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
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    if (!isCurrentUser)
                                                      Text(
                                                        message['user_email'].split('@')[0],
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.blue,
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
                                                      _formatMessageTime(message['timestamp']),
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: isCurrentUser 
                                                            ? Colors.white.withValues(alpha: 0.7)
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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
