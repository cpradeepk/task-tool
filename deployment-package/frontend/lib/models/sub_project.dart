// Project Status Enum
enum ProjectStatus {
  active('ACTIVE', 'Active'),
  onHold('ON_HOLD', 'On Hold'),
  completed('COMPLETED', 'Completed'),
  cancelled('CANCELLED', 'Cancelled');

  const ProjectStatus(this.value, this.label);
  final String value;
  final String label;

  static ProjectStatus fromString(String value) {
    return ProjectStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => ProjectStatus.active,
    );
  }
}

// Priority Enum (same as Task Priority)
enum Priority {
  importantUrgent('IMPORTANT_URGENT', 'Important & Urgent', 0xFFFF9800), // Orange
  importantNotUrgent('IMPORTANT_NOT_URGENT', 'Important & Not Urgent', 0xFFFFC107), // Yellow
  notImportantUrgent('NOT_IMPORTANT_URGENT', 'Not Important & Urgent', 0xFFFFFFFF), // White
  notImportantNotUrgent('NOT_IMPORTANT_NOT_URGENT', 'Not Important & Not Urgent', 0xFFFFFFFF); // White

  const Priority(this.value, this.label, this.color);
  final String value;
  final String label;
  final int color;

  static Priority fromString(String value) {
    return Priority.values.firstWhere(
      (priority) => priority.value == value,
      orElse: () => Priority.notImportantNotUrgent,
    );
  }
}

class SubProject {
  final String id;
  final String name;
  final String? description;
  final ProjectStatus status;
  final Priority priority;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String projectId;
  
  // Related objects
  final Map<String, dynamic>? project;
  final List<Map<String, dynamic>> tasks;
  final Map<String, dynamic>? count;

  SubProject({
    required this.id,
    required this.name,
    this.description,
    required this.status,
    required this.priority,
    this.startDate,
    this.endDate,
    required this.createdAt,
    required this.updatedAt,
    required this.projectId,
    this.project,
    this.tasks = const [],
    this.count,
  });

  factory SubProject.fromJson(Map<String, dynamic> json) {
    return SubProject(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      status: ProjectStatus.fromString(json['status']),
      priority: Priority.fromString(json['priority']),
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      projectId: json['projectId'],
      project: json['project'],
      tasks: List<Map<String, dynamic>>.from(json['tasks'] ?? []),
      count: json['_count'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'status': status.value,
      'priority': priority.value,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'projectId': projectId,
    };
  }

  // Helper methods
  String get statusLabel => status.label;
  String get priorityLabel => priority.label;
  int get priorityColor => priority.color;
  
  int get taskCount => count?['tasks'] ?? tasks.length;
  
  bool get isActive => status == ProjectStatus.active;
  bool get isCompleted => status == ProjectStatus.completed;
}
