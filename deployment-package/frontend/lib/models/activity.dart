class ActivityLog {
  final String id;
  final ActivityType action;
  final String description;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final Map<String, dynamic> user;
  final Map<String, dynamic>? task;
  final Map<String, dynamic>? project;

  ActivityLog({
    required this.id,
    required this.action,
    required this.description,
    this.metadata,
    required this.createdAt,
    required this.user,
    this.task,
    this.project,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'],
      action: ActivityTypeExtension.fromString(json['action']),
      description: json['description'],
      metadata: json['metadata'],
      createdAt: DateTime.parse(json['createdAt']),
      user: json['user'],
      task: json['task'],
      project: json['project'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action.value,
      'description': description,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      'user': user,
      'task': task,
      'project': project,
    };
  }

  String get userName => user['name'] ?? 'Unknown';
  String get userEmail => user['email'] ?? '';
  String get taskTitle => task?['title'] ?? '';
  String get projectName => project?['name'] ?? '';
  bool get hasTask => task != null;
  bool get hasProject => project != null;
}

class ActivityStats {
  final int total;
  final Map<String, int> byAction;
  final List<UserActivityStat> byUser;
  final List<DailyActivityStat> daily;

  ActivityStats({
    required this.total,
    required this.byAction,
    required this.byUser,
    required this.daily,
  });

  factory ActivityStats.fromJson(Map<String, dynamic> json) {
    return ActivityStats(
      total: json['total'] ?? 0,
      byAction: Map<String, int>.from(json['byAction'] ?? {}),
      byUser: (json['byUser'] as List<dynamic>?)
          ?.map((u) => UserActivityStat.fromJson(u))
          .toList() ?? [],
      daily: (json['daily'] as List<dynamic>?)
          ?.map((d) => DailyActivityStat.fromJson(d))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total': total,
      'byAction': byAction,
      'byUser': byUser.map((u) => u.toJson()).toList(),
      'daily': daily.map((d) => d.toJson()).toList(),
    };
  }
}

class UserActivityStat {
  final Map<String, dynamic> user;
  final int count;

  UserActivityStat({
    required this.user,
    required this.count,
  });

  factory UserActivityStat.fromJson(Map<String, dynamic> json) {
    return UserActivityStat(
      user: json['user'],
      count: json['count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user,
      'count': count,
    };
  }

  String get userName => user['name'] ?? 'Unknown';
  String get userEmail => user['email'] ?? '';
}

class DailyActivityStat {
  final DateTime date;
  final int count;

  DailyActivityStat({
    required this.date,
    required this.count,
  });

  factory DailyActivityStat.fromJson(Map<String, dynamic> json) {
    return DailyActivityStat(
      date: DateTime.parse(json['date']),
      count: json['count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'count': count,
    };
  }
}

enum ActivityType {
  taskCreated,
  taskUpdated,
  taskCompleted,
  taskDeleted,
  taskAssigned,
  taskUnassigned,
  projectCreated,
  projectUpdated,
  projectDeleted,
  commentAdded,
  commentUpdated,
  commentDeleted,
  fileUploaded,
  fileDeleted,
  timeLogged,
  dependencyAdded,
  dependencyRemoved,
  statusChanged,
  priorityChanged,
  userJoined,
  userLeft,
  channelCreated,
  channelUpdated,
  messageSent,
}

extension ActivityTypeExtension on ActivityType {
  String get value {
    switch (this) {
      case ActivityType.taskCreated:
        return 'TASK_CREATED';
      case ActivityType.taskUpdated:
        return 'TASK_UPDATED';
      case ActivityType.taskCompleted:
        return 'TASK_COMPLETED';
      case ActivityType.taskDeleted:
        return 'TASK_DELETED';
      case ActivityType.taskAssigned:
        return 'TASK_ASSIGNED';
      case ActivityType.taskUnassigned:
        return 'TASK_UNASSIGNED';
      case ActivityType.projectCreated:
        return 'PROJECT_CREATED';
      case ActivityType.projectUpdated:
        return 'PROJECT_UPDATED';
      case ActivityType.projectDeleted:
        return 'PROJECT_DELETED';
      case ActivityType.commentAdded:
        return 'COMMENT_ADDED';
      case ActivityType.commentUpdated:
        return 'COMMENT_UPDATED';
      case ActivityType.commentDeleted:
        return 'COMMENT_DELETED';
      case ActivityType.fileUploaded:
        return 'FILE_UPLOADED';
      case ActivityType.fileDeleted:
        return 'FILE_DELETED';
      case ActivityType.timeLogged:
        return 'TIME_LOGGED';
      case ActivityType.dependencyAdded:
        return 'DEPENDENCY_ADDED';
      case ActivityType.dependencyRemoved:
        return 'DEPENDENCY_REMOVED';
      case ActivityType.statusChanged:
        return 'STATUS_CHANGED';
      case ActivityType.priorityChanged:
        return 'PRIORITY_CHANGED';
      case ActivityType.userJoined:
        return 'USER_JOINED';
      case ActivityType.userLeft:
        return 'USER_LEFT';
      case ActivityType.channelCreated:
        return 'CHANNEL_CREATED';
      case ActivityType.channelUpdated:
        return 'CHANNEL_UPDATED';
      case ActivityType.messageSent:
        return 'MESSAGE_SENT';
    }
  }

  static ActivityType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'TASK_CREATED':
        return ActivityType.taskCreated;
      case 'TASK_UPDATED':
        return ActivityType.taskUpdated;
      case 'TASK_COMPLETED':
        return ActivityType.taskCompleted;
      case 'TASK_DELETED':
        return ActivityType.taskDeleted;
      case 'TASK_ASSIGNED':
        return ActivityType.taskAssigned;
      case 'TASK_UNASSIGNED':
        return ActivityType.taskUnassigned;
      case 'PROJECT_CREATED':
        return ActivityType.projectCreated;
      case 'PROJECT_UPDATED':
        return ActivityType.projectUpdated;
      case 'PROJECT_DELETED':
        return ActivityType.projectDeleted;
      case 'COMMENT_ADDED':
        return ActivityType.commentAdded;
      case 'COMMENT_UPDATED':
        return ActivityType.commentUpdated;
      case 'COMMENT_DELETED':
        return ActivityType.commentDeleted;
      case 'FILE_UPLOADED':
        return ActivityType.fileUploaded;
      case 'FILE_DELETED':
        return ActivityType.fileDeleted;
      case 'TIME_LOGGED':
        return ActivityType.timeLogged;
      case 'DEPENDENCY_ADDED':
        return ActivityType.dependencyAdded;
      case 'DEPENDENCY_REMOVED':
        return ActivityType.dependencyRemoved;
      case 'STATUS_CHANGED':
        return ActivityType.statusChanged;
      case 'PRIORITY_CHANGED':
        return ActivityType.priorityChanged;
      case 'USER_JOINED':
        return ActivityType.userJoined;
      case 'USER_LEFT':
        return ActivityType.userLeft;
      case 'CHANNEL_CREATED':
        return ActivityType.channelCreated;
      case 'CHANNEL_UPDATED':
        return ActivityType.channelUpdated;
      case 'MESSAGE_SENT':
        return ActivityType.messageSent;
      default:
        return ActivityType.taskUpdated;
    }
  }

  String get displayName {
    switch (this) {
      case ActivityType.taskCreated:
        return 'Task Created';
      case ActivityType.taskUpdated:
        return 'Task Updated';
      case ActivityType.taskCompleted:
        return 'Task Completed';
      case ActivityType.taskDeleted:
        return 'Task Deleted';
      case ActivityType.taskAssigned:
        return 'Task Assigned';
      case ActivityType.taskUnassigned:
        return 'Task Unassigned';
      case ActivityType.projectCreated:
        return 'Project Created';
      case ActivityType.projectUpdated:
        return 'Project Updated';
      case ActivityType.projectDeleted:
        return 'Project Deleted';
      case ActivityType.commentAdded:
        return 'Comment Added';
      case ActivityType.commentUpdated:
        return 'Comment Updated';
      case ActivityType.commentDeleted:
        return 'Comment Deleted';
      case ActivityType.fileUploaded:
        return 'File Uploaded';
      case ActivityType.fileDeleted:
        return 'File Deleted';
      case ActivityType.timeLogged:
        return 'Time Logged';
      case ActivityType.dependencyAdded:
        return 'Dependency Added';
      case ActivityType.dependencyRemoved:
        return 'Dependency Removed';
      case ActivityType.statusChanged:
        return 'Status Changed';
      case ActivityType.priorityChanged:
        return 'Priority Changed';
      case ActivityType.userJoined:
        return 'User Joined';
      case ActivityType.userLeft:
        return 'User Left';
      case ActivityType.channelCreated:
        return 'Channel Created';
      case ActivityType.channelUpdated:
        return 'Channel Updated';
      case ActivityType.messageSent:
        return 'Message Sent';
    }
  }
}
