class ChatChannel {
  final String id;
  final String name;
  final String? description;
  final bool isPrivate;
  final String channelType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? project;
  final Map<String, dynamic> createdBy;
  final List<ChatChannelMember> members;
  final int messageCount;

  ChatChannel({
    required this.id,
    required this.name,
    this.description,
    required this.isPrivate,
    required this.channelType,
    required this.createdAt,
    required this.updatedAt,
    this.project,
    required this.createdBy,
    required this.members,
    required this.messageCount,
  });

  factory ChatChannel.fromJson(Map<String, dynamic> json) {
    return ChatChannel(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      isPrivate: json['isPrivate'],
      channelType: json['channelType'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      project: json['project'],
      createdBy: json['createdBy'],
      members: (json['members'] as List<dynamic>?)
          ?.map((m) => ChatChannelMember.fromJson(m))
          .toList() ?? [],
      messageCount: json['messageCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'isPrivate': isPrivate,
      'channelType': channelType,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'project': project,
      'createdBy': createdBy,
      'members': members.map((m) => m.toJson()).toList(),
      'messageCount': messageCount,
    };
  }
}

class ChatChannelMember {
  final String id;
  final String role;
  final DateTime joinedAt;
  final DateTime? lastRead;
  final Map<String, dynamic> user;

  ChatChannelMember({
    required this.id,
    required this.role,
    required this.joinedAt,
    this.lastRead,
    required this.user,
  });

  factory ChatChannelMember.fromJson(Map<String, dynamic> json) {
    return ChatChannelMember(
      id: json['id'],
      role: json['role'],
      joinedAt: DateTime.parse(json['joinedAt']),
      lastRead: json['lastRead'] != null ? DateTime.parse(json['lastRead']) : null,
      user: json['user'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'joinedAt': joinedAt.toIso8601String(),
      'lastRead': lastRead?.toIso8601String(),
      'user': user,
    };
  }
}

class ChatMessage {
  final String id;
  final String content;
  final String messageType;
  final bool isEdited;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> sender;
  final Map<String, dynamic>? recipient;
  final Map<String, dynamic>? channel;
  final ChatMessage? parentMessage;
  final List<ChatMessage> replies;
  final int replyCount;
  final List<Map<String, dynamic>> attachments;

  ChatMessage({
    required this.id,
    required this.content,
    required this.messageType,
    required this.isEdited,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
    required this.sender,
    this.recipient,
    this.channel,
    this.parentMessage,
    required this.replies,
    required this.replyCount,
    required this.attachments,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      content: json['content'],
      messageType: json['messageType'],
      isEdited: json['isEdited'] ?? false,
      isDeleted: json['isDeleted'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      sender: json['sender'],
      recipient: json['recipient'],
      channel: json['channel'],
      parentMessage: json['parentMessage'] != null 
          ? ChatMessage.fromJson(json['parentMessage'])
          : null,
      replies: (json['replies'] as List<dynamic>?)
          ?.map((r) => ChatMessage.fromJson(r))
          .toList() ?? [],
      replyCount: json['replyCount'] ?? 0,
      attachments: List<Map<String, dynamic>>.from(json['attachments'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'messageType': messageType,
      'isEdited': isEdited,
      'isDeleted': isDeleted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'sender': sender,
      'recipient': recipient,
      'channel': channel,
      'parentMessage': parentMessage?.toJson(),
      'replies': replies.map((r) => r.toJson()).toList(),
      'replyCount': replyCount,
      'attachments': attachments,
    };
  }

  bool get isDirectMessage => recipient != null;
  bool get isChannelMessage => channel != null;
  bool get hasReplies => replyCount > 0;
  bool get hasAttachments => attachments.isNotEmpty;
  
  String get senderName => sender['name'] ?? 'Unknown';
  String get senderId => sender['id'] ?? '';
}

class DirectConversation {
  final String userId;
  final Map<String, dynamic> user;
  final ChatMessage lastMessage;
  final int unreadCount;

  DirectConversation({
    required this.userId,
    required this.user,
    required this.lastMessage,
    required this.unreadCount,
  });

  factory DirectConversation.fromJson(Map<String, dynamic> json) {
    return DirectConversation(
      userId: json['userId'],
      user: json['user'],
      lastMessage: ChatMessage.fromJson(json['lastMessage']),
      unreadCount: json['unreadCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'user': user,
      'lastMessage': lastMessage.toJson(),
      'unreadCount': unreadCount,
    };
  }

  String get userName => user['name'] ?? 'Unknown';
  String get userEmail => user['email'] ?? '';
}

enum MessageType {
  text,
  image,
  file,
  system,
  taskReference,
  projectReference,
}

extension MessageTypeExtension on MessageType {
  String get value {
    switch (this) {
      case MessageType.text:
        return 'TEXT';
      case MessageType.image:
        return 'IMAGE';
      case MessageType.file:
        return 'FILE';
      case MessageType.system:
        return 'SYSTEM';
      case MessageType.taskReference:
        return 'TASK_REFERENCE';
      case MessageType.projectReference:
        return 'PROJECT_REFERENCE';
    }
  }

  static MessageType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'TEXT':
        return MessageType.text;
      case 'IMAGE':
        return MessageType.image;
      case 'FILE':
        return MessageType.file;
      case 'SYSTEM':
        return MessageType.system;
      case 'TASK_REFERENCE':
        return MessageType.taskReference;
      case 'PROJECT_REFERENCE':
        return MessageType.projectReference;
      default:
        return MessageType.text;
    }
  }
}

enum ChannelType {
  project,
  direct,
  general,
  announcement,
}

extension ChannelTypeExtension on ChannelType {
  String get value {
    switch (this) {
      case ChannelType.project:
        return 'PROJECT';
      case ChannelType.direct:
        return 'DIRECT';
      case ChannelType.general:
        return 'GENERAL';
      case ChannelType.announcement:
        return 'ANNOUNCEMENT';
    }
  }

  static ChannelType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'PROJECT':
        return ChannelType.project;
      case 'DIRECT':
        return ChannelType.direct;
      case 'GENERAL':
        return ChannelType.general;
      case 'ANNOUNCEMENT':
        return ChannelType.announcement;
      default:
        return ChannelType.project;
    }
  }
}
