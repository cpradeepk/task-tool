// Task Status Enum
enum TaskStatus {
  open('OPEN', 'Open', 0xFFFFFFFF), // White
  inProgress('IN_PROGRESS', 'In Progress', 0xFFFFC107), // Yellow
  completed('COMPLETED', 'Completed', 0xFF4CAF50), // Green
  cancelled('CANCELLED', 'Cancelled', 0xFF9E9E9E), // Grey
  hold('HOLD', 'Hold', 0xFF795548), // Brown
  delayed('DELAYED', 'Delayed', 0xFFF44336); // Red

  const TaskStatus(this.value, this.label, this.color);
  final String value;
  final String label;
  final int color;

  static TaskStatus fromString(String value) {
    return TaskStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => TaskStatus.open,
    );
  }

  String get displayName => label;
}

// Priority Enum (Eisenhower Matrix)
enum TaskPriority {
  importantUrgent('IMPORTANT_URGENT', 'Important & Urgent', 0xFFFF9800), // Orange
  importantNotUrgent('IMPORTANT_NOT_URGENT', 'Important & Not Urgent', 0xFFFFC107), // Yellow
  notImportantUrgent('NOT_IMPORTANT_URGENT', 'Not Important & Urgent', 0xFFFFFFFF), // White
  notImportantNotUrgent('NOT_IMPORTANT_NOT_URGENT', 'Not Important & Not Urgent', 0xFFFFFFFF); // White

  const TaskPriority(this.value, this.label, this.color);
  final String value;
  final String label;
  final int color;

  static TaskPriority fromString(String value) {
    return TaskPriority.values.firstWhere(
      (priority) => priority.value == value,
      orElse: () => TaskPriority.notImportantNotUrgent,
    );
  }
}

// Task Type Enum
enum TaskType {
  requirement('REQUIREMENT', 'Requirement'),
  design('DESIGN', 'Design'),
  coding('CODING', 'Coding'),
  testing('TESTING', 'Testing'),
  learning('LEARNING', 'Learning'),
  documentation('DOCUMENTATION', 'Documentation');

  const TaskType(this.value, this.label);
  final String value;
  final String label;

  static TaskType fromString(String value) {
    return TaskType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => TaskType.requirement,
    );
  }
}

// Task Assignment Role
enum TaskAssignmentRole {
  mainResponsible('MAIN_RESPONSIBLE', 'Main Responsible'),
  support('SUPPORT', 'Support');

  const TaskAssignmentRole(this.value, this.label);
  final String value;
  final String label;

  static TaskAssignmentRole fromString(String value) {
    return TaskAssignmentRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => TaskAssignmentRole.support,
    );
  }
}

class TaskAssignment {
  final String id;
  final TaskAssignmentRole role;
  final DateTime assignedAt;
  final String taskId;
  final String userId;
  final Map<String, dynamic>? user;

  TaskAssignment({
    required this.id,
    required this.role,
    required this.assignedAt,
    required this.taskId,
    required this.userId,
    this.user,
  });

  factory TaskAssignment.fromJson(Map<String, dynamic> json) {
    return TaskAssignment(
      id: json['id'],
      role: TaskAssignmentRole.fromString(json['role']),
      assignedAt: DateTime.parse(json['assignedAt']),
      taskId: json['taskId'],
      userId: json['userId'],
      user: json['user'],
    );
  }
}

class TaskDependency {
  final String id;
  final String dependencyType;
  final DateTime createdAt;
  final String preTaskId;
  final String postTaskId;
  final Map<String, dynamic>? preTask;
  final Map<String, dynamic>? postTask;

  TaskDependency({
    required this.id,
    required this.dependencyType,
    required this.createdAt,
    required this.preTaskId,
    required this.postTaskId,
    this.preTask,
    this.postTask,
  });

  factory TaskDependency.fromJson(Map<String, dynamic> json) {
    return TaskDependency(
      id: json['id'],
      dependencyType: json['dependencyType'],
      createdAt: DateTime.parse(json['createdAt']),
      preTaskId: json['preTaskId'],
      postTaskId: json['postTaskId'],
      preTask: json['preTask'],
      postTask: json['postTask'],
    );
  }
}

class Task {
  final String id;
  final String title;
  final String? description;
  final TaskStatus status;
  final TaskPriority priority;
  final TaskType taskType;

  // Date fields
  final DateTime? startDate;
  final DateTime? plannedEndDate;
  final DateTime? endDate;
  final DateTime? dueDate;

  // PERT time estimates
  final double? optimisticHours;
  final double? pessimisticHours;
  final double? mostLikelyHours;
  final double? estimatedHours;
  final double? actualHours;

  // Organization
  final List<String> tags;
  final List<String> milestones;
  final List<String> customLabels;

  final DateTime createdAt;
  final DateTime updatedAt;

  // Relations
  final String? projectId;
  final String? subProjectId;
  final String? parentTaskId;
  final String createdById;
  final String? mainAssigneeId;

  // Related objects
  final Map<String, dynamic>? project;
  final Map<String, dynamic>? subProject;
  final Map<String, dynamic>? parentTask;
  final Map<String, dynamic>? mainAssignee;
  final Map<String, dynamic>? createdBy;
  final List<TaskAssignment> assignments;
  final List<Task> subtasks;
  final List<TaskDependency> preDependencies;
  final List<TaskDependency> postDependencies;
  final List<Map<String, dynamic>> comments;
  final List<Map<String, dynamic>> timeEntries;
  final List<Map<String, dynamic>> attachments;
  final Map<String, dynamic>? count;

  Task({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    required this.taskType,
    this.startDate,
    this.plannedEndDate,
    this.endDate,
    this.dueDate,
    this.optimisticHours,
    this.pessimisticHours,
    this.mostLikelyHours,
    this.estimatedHours,
    this.actualHours,
    this.tags = const [],
    this.milestones = const [],
    this.customLabels = const [],
    required this.createdAt,
    required this.updatedAt,
    this.projectId,
    this.subProjectId,
    this.parentTaskId,
    required this.createdById,
    this.mainAssigneeId,
    this.project,
    this.subProject,
    this.parentTask,
    this.mainAssignee,
    this.createdBy,
    this.assignments = const [],
    this.subtasks = const [],
    this.preDependencies = const [],
    this.postDependencies = const [],
    this.comments = const [],
    this.timeEntries = const [],
    this.attachments = const [],
    this.count,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      status: TaskStatus.fromString(json['status']),
      priority: TaskPriority.fromString(json['priority']),
      taskType: TaskType.fromString(json['taskType'] ?? 'REQUIREMENT'),
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
      plannedEndDate: json['plannedEndDate'] != null ? DateTime.parse(json['plannedEndDate']) : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      optimisticHours: json['optimisticHours']?.toDouble(),
      pessimisticHours: json['pessimisticHours']?.toDouble(),
      mostLikelyHours: json['mostLikelyHours']?.toDouble(),
      estimatedHours: json['estimatedHours']?.toDouble(),
      actualHours: json['actualHours']?.toDouble(),
      tags: List<String>.from(json['tags'] ?? []),
      milestones: List<String>.from(json['milestones'] ?? []),
      customLabels: List<String>.from(json['customLabels'] ?? []),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      projectId: json['projectId'],
      subProjectId: json['subProjectId'],
      parentTaskId: json['parentTaskId'],
      createdById: json['createdById'],
      mainAssigneeId: json['mainAssigneeId'],
      project: json['project'],
      subProject: json['subProject'],
      parentTask: json['parentTask'],
      mainAssignee: json['mainAssignee'],
      createdBy: json['createdBy'],
      assignments: (json['assignments'] as List<dynamic>?)
          ?.map((a) => TaskAssignment.fromJson(a))
          .toList() ?? [],
      subtasks: (json['subtasks'] as List<dynamic>?)
          ?.map((t) => Task.fromJson(t))
          .toList() ?? [],
      preDependencies: (json['preDependencies'] as List<dynamic>?)
          ?.map((d) => TaskDependency.fromJson(d))
          .toList() ?? [],
      postDependencies: (json['postDependencies'] as List<dynamic>?)
          ?.map((d) => TaskDependency.fromJson(d))
          .toList() ?? [],
      comments: List<Map<String, dynamic>>.from(json['comments'] ?? []),
      timeEntries: List<Map<String, dynamic>>.from(json['timeEntries'] ?? []),
      attachments: List<Map<String, dynamic>>.from(json['attachments'] ?? []),
      count: json['_count'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status.value,
      'priority': priority.value,
      'taskType': taskType.value,
      'startDate': startDate?.toIso8601String(),
      'plannedEndDate': plannedEndDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'optimisticHours': optimisticHours,
      'pessimisticHours': pessimisticHours,
      'mostLikelyHours': mostLikelyHours,
      'estimatedHours': estimatedHours,
      'actualHours': actualHours,
      'tags': tags,
      'milestones': milestones,
      'customLabels': customLabels,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'projectId': projectId,
      'subProjectId': subProjectId,
      'parentTaskId': parentTaskId,
      'createdById': createdById,
      'mainAssigneeId': mainAssigneeId,
    };
  }

  // Helper methods
  bool get isOverdue {
    if (dueDate == null || status == TaskStatus.completed) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  bool get isInProgress => status == TaskStatus.inProgress;
  bool get isCompleted => status == TaskStatus.completed;

  String get statusLabel => status.label;
  String get priorityLabel => priority.label;
  String get typeLabel => taskType.label;

  int get statusColor => status.color;
  int get priorityColor => priority.color;

  // Additional properties needed by enhanced_task_card.dart
  String get assigneeName => mainAssignee?['name'] ?? '';
  bool get hasComments => comments.isNotEmpty;
  bool get hasAttachments => attachments.isNotEmpty;

  // Counts object for comments and attachments
  Map<String, int> get counts => {
    'comments': comments.length,
    'attachments': attachments.length,
  };

  // copyWith method for updating task properties
  Task copyWith({
    String? id,
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    TaskType? taskType,
    DateTime? startDate,
    DateTime? plannedEndDate,
    DateTime? endDate,
    DateTime? dueDate,
    double? optimisticHours,
    double? pessimisticHours,
    double? mostLikelyHours,
    double? estimatedHours,
    double? actualHours,
    List<String>? tags,
    List<String>? milestones,
    List<String>? customLabels,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? projectId,
    String? subProjectId,
    String? parentTaskId,
    String? createdById,
    String? mainAssigneeId,
    Map<String, dynamic>? project,
    Map<String, dynamic>? subProject,
    Map<String, dynamic>? parentTask,
    Map<String, dynamic>? mainAssignee,
    Map<String, dynamic>? createdBy,
    List<TaskAssignment>? assignments,
    List<Task>? subtasks,
    List<TaskDependency>? preDependencies,
    List<TaskDependency>? postDependencies,
    List<Map<String, dynamic>>? comments,
    List<Map<String, dynamic>>? timeEntries,
    List<Map<String, dynamic>>? attachments,
    Map<String, dynamic>? count,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      taskType: taskType ?? this.taskType,
      startDate: startDate ?? this.startDate,
      plannedEndDate: plannedEndDate ?? this.plannedEndDate,
      endDate: endDate ?? this.endDate,
      dueDate: dueDate ?? this.dueDate,
      optimisticHours: optimisticHours ?? this.optimisticHours,
      pessimisticHours: pessimisticHours ?? this.pessimisticHours,
      mostLikelyHours: mostLikelyHours ?? this.mostLikelyHours,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      actualHours: actualHours ?? this.actualHours,
      tags: tags ?? this.tags,
      milestones: milestones ?? this.milestones,
      customLabels: customLabels ?? this.customLabels,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      projectId: projectId ?? this.projectId,
      subProjectId: subProjectId ?? this.subProjectId,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      createdById: createdById ?? this.createdById,
      mainAssigneeId: mainAssigneeId ?? this.mainAssigneeId,
      project: project ?? this.project,
      subProject: subProject ?? this.subProject,
      parentTask: parentTask ?? this.parentTask,
      mainAssignee: mainAssignee ?? this.mainAssignee,
      createdBy: createdBy ?? this.createdBy,
      assignments: assignments ?? this.assignments,
      subtasks: subtasks ?? this.subtasks,
      preDependencies: preDependencies ?? this.preDependencies,
      postDependencies: postDependencies ?? this.postDependencies,
      comments: comments ?? this.comments,
      timeEntries: timeEntries ?? this.timeEntries,
      attachments: attachments ?? this.attachments,
      count: count ?? this.count,
    );
  }
}
