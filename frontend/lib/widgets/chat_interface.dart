import 'package:flutter/material.dart';
import 'dart:async';
import '../models/chat.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class ChatInterface extends StatefulWidget {
  final String? channelId;
  final String? recipientId;
  final String? projectId;

  const ChatInterface({
    Key? key,
    this.channelId,
    this.recipientId,
    this.projectId,
  }) : super(key: key);

  @override
  State<ChatInterface> createState() => _ChatInterfaceState();
}

class _ChatInterfaceState extends State<ChatInterface> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SocketService _socketService = SocketService();
  
  List<ChatMessage> _messages = [];
  List<ChatChannel> _channels = [];
  List<DirectConversation> _conversations = [];
  ChatChannel? _currentChannel;
  DirectConversation? _currentConversation;
  
  bool _isLoading = true;
  String? _error;
  bool _isTyping = false;
  Set<String> _typingUsers = {};
  Timer? _typingTimer;
  
  StreamSubscription? _messageSubscription;
  StreamSubscription? _typingSubscription;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _setupSocketListeners();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load channels and conversations
      await Future.wait([
        _loadChannels(),
        _loadConversations(),
      ]);

      // Load messages for current chat
      if (widget.channelId != null) {
        await _loadChannelMessages(widget.channelId!);
        _socketService.joinChannel(widget.channelId!);
      } else if (widget.recipientId != null) {
        await _loadDirectMessages(widget.recipientId!);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _setupSocketListeners() {
    _messageSubscription = _socketService.messageStream.listen((data) {
      _handleSocketMessage(data);
    });

    _typingSubscription = _socketService.typingStream.listen((data) {
      _handleTypingEvent(data);
    });
  }

  void _handleSocketMessage(Map<String, dynamic> data) {
    final type = data['type'];
    
    switch (type) {
      case 'new_message':
        final message = ChatMessage.fromJson(data);
        if (_shouldDisplayMessage(message)) {
          setState(() {
            _messages.add(message);
          });
          _scrollToBottom();
        }
        break;
        
      case 'message_updated':
        final updatedMessage = ChatMessage.fromJson(data);
        setState(() {
          final index = _messages.indexWhere((m) => m.id == updatedMessage.id);
          if (index != -1) {
            _messages[index] = updatedMessage;
          }
        });
        break;
        
      case 'message_deleted':
        final messageId = data['messageId'];
        setState(() {
          _messages.removeWhere((m) => m.id == messageId);
        });
        break;
        
      case 'user_joined':
        // Handle user joined channel
        break;
        
      case 'user_left':
        // Handle user left channel
        break;
    }
  }

  void _handleTypingEvent(Map<String, dynamic> data) {
    final type = data['type'];
    final userId = data['userId'];
    
    if (type == 'typing_start') {
      setState(() {
        _typingUsers.add(userId);
      });
    } else if (type == 'typing_stop') {
      setState(() {
        _typingUsers.remove(userId);
      });
    }
  }

  bool _shouldDisplayMessage(ChatMessage message) {
    if (widget.channelId != null) {
      return message.channel?['id'] == widget.channelId;
    } else if (widget.recipientId != null) {
      return (message.senderId == widget.recipientId || 
              message.recipient?['id'] == widget.recipientId);
    }
    return false;
  }

  Future<void> _loadChannels() async {
    try {
      final response = await ApiService.get('/chat/channels', queryParams: {
        if (widget.projectId != null) 'projectId': widget.projectId!,
      });
      
      final channels = (response as List<dynamic>)
          .map((data) => ChatChannel.fromJson(data))
          .toList();
      
      setState(() {
        _channels = channels;
        if (widget.channelId != null) {
          _currentChannel = channels.firstWhere(
            (c) => c.id == widget.channelId,
            orElse: () => channels.first,
          );
        }
      });
    } catch (e) {
      debugPrint('Error loading channels: $e');
    }
  }

  Future<void> _loadConversations() async {
    try {
      final response = await ApiService.get('/chat/conversations');
      
      final conversations = (response as List<dynamic>)
          .map((data) => DirectConversation.fromJson(data))
          .toList();
      
      setState(() {
        _conversations = conversations;
        if (widget.recipientId != null) {
          _currentConversation = conversations.firstWhere(
            (c) => c.userId == widget.recipientId,
            orElse: () => conversations.isNotEmpty ? conversations.first : null,
          );
        }
      });
    } catch (e) {
      debugPrint('Error loading conversations: $e');
    }
  }

  Future<void> _loadChannelMessages(String channelId) async {
    try {
      final response = await ApiService.get('/chat/messages', queryParams: {
        'channelId': channelId,
        'limit': '50',
      });
      
      final messages = (response['messages'] as List<dynamic>)
          .map((data) => ChatMessage.fromJson(data))
          .toList();
      
      setState(() {
        _messages = messages;
      });
      
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error loading channel messages: $e');
    }
  }

  Future<void> _loadDirectMessages(String recipientId) async {
    try {
      final response = await ApiService.get('/chat/messages', queryParams: {
        'recipientId': recipientId,
        'limit': '50',
      });
      
      final messages = (response['messages'] as List<dynamic>)
          .map((data) => ChatMessage.fromJson(data))
          .toList();
      
      setState(() {
        _messages = messages;
      });
      
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error loading direct messages: $e');
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    try {
      await ApiService.post('/chat/messages', {
        'channelId': widget.channelId,
        'recipientId': widget.recipientId,
        'content': content,
        'messageType': 'TEXT',
      });

      _messageController.clear();
      _stopTyping();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  void _startTyping() {
    if (!_isTyping) {
      _isTyping = true;
      _socketService.startTyping(
        channelId: widget.channelId,
        recipientId: widget.recipientId,
      );
    }
    
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      _stopTyping();
    });
  }

  void _stopTyping() {
    if (_isTyping) {
      _isTyping = false;
      _socketService.stopTyping(
        channelId: widget.channelId,
        recipientId: widget.recipientId,
      );
    }
    _typingTimer?.cancel();
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
    return Column(
      children: [
        _buildChatHeader(),
        Expanded(
          child: _buildMessagesList(),
        ),
        _buildTypingIndicator(),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildChatHeader() {
    String title = 'Chat';
    String subtitle = '';

    if (_currentChannel != null) {
      title = _currentChannel!.name;
      subtitle = '${_currentChannel!.members.length} members';
    } else if (_currentConversation != null) {
      title = _currentConversation!.userName;
      subtitle = _currentConversation!.userEmail;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue[100],
            child: Text(
              title.substring(0, 1).toUpperCase(),
              style: TextStyle(color: Colors.blue[700]),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // Show chat options
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
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
            Text('Error loading messages'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _initializeChat,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No messages yet'),
            SizedBox(height: 8),
            Text(
              'Start the conversation!',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message.senderId == 'current_user_id'; // Replace with actual user ID
        
        return _buildMessageBubble(message, isMe);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Text(
                  message.senderName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? Colors.blue[500] : Colors.grey[200],
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    if (_typingUsers.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            '${_typingUsers.length} user${_typingUsers.length > 1 ? 's' : ''} typing...',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
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
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onChanged: (text) {
                if (text.isNotEmpty) {
                  _startTyping();
                } else {
                  _stopTyping();
                }
              },
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sendMessage,
            icon: const Icon(Icons.send),
            style: IconButton.styleFrom(
              backgroundColor: Colors.blue[500],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }
}
