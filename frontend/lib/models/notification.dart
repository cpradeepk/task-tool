class AppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final bool isRead;
  final Map<String, dynamic>? data;
  final DateTime createdAt;
  final DateTime? readAt;
  final Map<String, dynamic>? task;
  final Map<String, dynamic>? project;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.data,
    required this.createdAt,
    this.readAt,
    this.task,
    this.project,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      title: json['title'],
      message: json['message'],
      type: NotificationTypeExtension.fromString(json['type']),
      isRead: json['isRead'] ?? false,
      data: json['data'],
      createdAt: DateTime.parse(json['createdAt']),
      readAt: json['readAt'] != null ? DateTime.parse(json['readAt']) : null,
      task: json['task'],
      project: json['project'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type.value,
      'isRead': isRead,
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'task': task,
      'project': project,
    };
  }

  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    bool? isRead,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    DateTime? readAt,
    Map<String, dynamic>? task,
    Map<String, dynamic>? project,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      task: task ?? this.task,
      project: project ?? this.project,
    );
  }

  String get taskTitle => task?['title'] ?? '';
  String get projectName => project?['name'] ?? '';
  bool get hasTask => task != null;
  bool get hasProject => project != null;
}

class NotificationStats {
  final int total;
  final int unread;
  final Map<String, int> byType;

  NotificationStats({
    required this.total,
    required this.unread,
    required this.byType,
  });

  factory NotificationStats.fromJson(Map<String, dynamic> json) {
    return NotificationStats(
      total: json['total'] ?? 0,
      unread: json['unread'] ?? 0,
      byType: Map<String, int>.from(json['byType'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total': total,
      'unread': unread,
      'byType': byType,
    };
  }
}

class NotificationPreferences {
  final EmailPreferences email;
  final PushPreferences push;
  final InAppPreferences inApp;

  NotificationPreferences({
    required this.email,
    required this.push,
    required this.inApp,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      email: EmailPreferences.fromJson(json['email'] ?? {}),
      push: PushPreferences.fromJson(json['push'] ?? {}),
      inApp: InAppPreferences.fromJson(json['inApp'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email.toJson(),
      'push': push.toJson(),
      'inApp': inApp.toJson(),
    };
  }
}

class EmailPreferences {
  final bool taskAssigned;
  final bool taskCompleted;
  final bool taskOverdue;
  final bool commentAdded;
  final bool projectUpdated;
  final bool deadlineReminder;

  EmailPreferences({
    required this.taskAssigned,
    required this.taskCompleted,
    required this.taskOverdue,
    required this.commentAdded,
    required this.projectUpdated,
    required this.deadlineReminder,
  });

  factory EmailPreferences.fromJson(Map<String, dynamic> json) {
    return EmailPreferences(
      taskAssigned: json['taskAssigned'] ?? true,
      taskCompleted: json['taskCompleted'] ?? true,
      taskOverdue: json['taskOverdue'] ?? true,
      commentAdded: json['commentAdded'] ?? true,
      projectUpdated: json['projectUpdated'] ?? true,
      deadlineReminder: json['deadlineReminder'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'taskAssigned': taskAssigned,
      'taskCompleted': taskCompleted,
      'taskOverdue': taskOverdue,
      'commentAdded': commentAdded,
      'projectUpdated': projectUpdated,
      'deadlineReminder': deadlineReminder,
    };
  }
}

class PushPreferences {
  final bool taskAssigned;
  final bool taskCompleted;
  final bool taskOverdue;
  final bool commentAdded;
  final bool projectUpdated;
  final bool deadlineReminder;

  PushPreferences({
    required this.taskAssigned,
    required this.taskCompleted,
    required this.taskOverdue,
    required this.commentAdded,
    required this.projectUpdated,
    required this.deadlineReminder,
  });

  factory PushPreferences.fromJson(Map<String, dynamic> json) {
    return PushPreferences(
      taskAssigned: json['taskAssigned'] ?? true,
      taskCompleted: json['taskCompleted'] ?? false,
      taskOverdue: json['taskOverdue'] ?? true,
      commentAdded: json['commentAdded'] ?? true,
      projectUpdated: json['projectUpdated'] ?? false,
      deadlineReminder: json['deadlineReminder'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'taskAssigned': taskAssigned,
      'taskCompleted': taskCompleted,
      'taskOverdue': taskOverdue,
      'commentAdded': commentAdded,
      'projectUpdated': projectUpdated,
      'deadlineReminder': deadlineReminder,
    };
  }
}

class InAppPreferences {
  final bool taskAssigned;
  final bool taskCompleted;
  final bool taskOverdue;
  final bool commentAdded;
  final bool projectUpdated;
  final bool deadlineReminder;
  final bool mention;

  InAppPreferences({
    required this.taskAssigned,
    required this.taskCompleted,
    required this.taskOverdue,
    required this.commentAdded,
    required this.projectUpdated,
    required this.deadlineReminder,
    required this.mention,
  });

  factory InAppPreferences.fromJson(Map<String, dynamic> json) {
    return InAppPreferences(
      taskAssigned: json['taskAssigned'] ?? true,
      taskCompleted: json['taskCompleted'] ?? true,
      taskOverdue: json['taskOverdue'] ?? true,
      commentAdded: json['commentAdded'] ?? true,
      projectUpdated: json['projectUpdated'] ?? true,
      deadlineReminder: json['deadlineReminder'] ?? true,
      mention: json['mention'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'taskAssigned': taskAssigned,
      'taskCompleted': taskCompleted,
      'taskOverdue': taskOverdue,
      'commentAdded': commentAdded,
      'projectUpdated': projectUpdated,
      'deadlineReminder': deadlineReminder,
      'mention': mention,
    };
  }
}

enum NotificationType {
  info,
  success,
  warning,
  error,
  taskAssigned,
  taskUpdated,
  taskCompleted,
  taskOverdue,
  projectUpdated,
  commentAdded,
  mention,
  deadlineReminder,
}

extension NotificationTypeExtension on NotificationType {
  String get value {
    switch (this) {
      case NotificationType.info:
        return 'INFO';
      case NotificationType.success:
        return 'SUCCESS';
      case NotificationType.warning:
        return 'WARNING';
      case NotificationType.error:
        return 'ERROR';
      case NotificationType.taskAssigned:
        return 'TASK_ASSIGNED';
      case NotificationType.taskUpdated:
        return 'TASK_UPDATED';
      case NotificationType.taskCompleted:
        return 'TASK_COMPLETED';
      case NotificationType.taskOverdue:
        return 'TASK_OVERDUE';
      case NotificationType.projectUpdated:
        return 'PROJECT_UPDATED';
      case NotificationType.commentAdded:
        return 'COMMENT_ADDED';
      case NotificationType.mention:
        return 'MENTION';
      case NotificationType.deadlineReminder:
        return 'DEADLINE_REMINDER';
    }
  }

  static NotificationType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'INFO':
        return NotificationType.info;
      case 'SUCCESS':
        return NotificationType.success;
      case 'WARNING':
        return NotificationType.warning;
      case 'ERROR':
        return NotificationType.error;
      case 'TASK_ASSIGNED':
        return NotificationType.taskAssigned;
      case 'TASK_UPDATED':
        return NotificationType.taskUpdated;
      case 'TASK_COMPLETED':
        return NotificationType.taskCompleted;
      case 'TASK_OVERDUE':
        return NotificationType.taskOverdue;
      case 'PROJECT_UPDATED':
        return NotificationType.projectUpdated;
      case 'COMMENT_ADDED':
        return NotificationType.commentAdded;
      case 'MENTION':
        return NotificationType.mention;
      case 'DEADLINE_REMINDER':
        return NotificationType.deadlineReminder;
      default:
        return NotificationType.info;
    }
  }
}
