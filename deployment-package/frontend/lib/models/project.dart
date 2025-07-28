import 'user.dart';
import 'sub_project.dart';

// Project Member Role Enum
enum ProjectMemberRole {
  owner('OWNER', 'Owner'),
  admin('ADMIN', 'Admin'),
  member('MEMBER', 'Member'),
  viewer('VIEWER', 'Viewer');

  const ProjectMemberRole(this.value, this.label);
  final String value;
  final String label;

  static ProjectMemberRole fromString(String value) {
    return ProjectMemberRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => ProjectMemberRole.member,
    );
  }
}

class ProjectMember {
  final String id;
  final String userId;
  final String projectId;
  final ProjectMemberRole role;
  final DateTime joinedAt;
  final Map<String, dynamic>? user;

  ProjectMember({
    required this.id,
    required this.userId,
    required this.projectId,
    required this.role,
    required this.joinedAt,
    this.user,
  });

  factory ProjectMember.fromJson(Map<String, dynamic> json) {
    return ProjectMember(
      id: json['id'],
      userId: json['userId'],
      projectId: json['projectId'],
      role: ProjectMemberRole.fromString(json['role']),
      joinedAt: DateTime.parse(json['joinedAt']),
      user: json['user'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'projectId': projectId,
      'role': role.value,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }

  String get roleLabel => role.label;
}

class Project {
  final String id;
  final String name;
  final String? description;
  final ProjectStatus status;
  final Priority priority;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdById;

  // Related objects
  final Map<String, dynamic>? createdBy;
  final List<ProjectMember> members;
  final List<Map<String, dynamic>> tasks;
  final List<SubProject> subProjects;
  final Map<String, dynamic>? count;

  Project({
    required this.id,
    required this.name,
    this.description,
    required this.status,
    required this.priority,
    this.startDate,
    this.endDate,
    required this.createdAt,
    required this.updatedAt,
    required this.createdById,
    this.createdBy,
    this.members = const [],
    this.tasks = const [],
    this.subProjects = const [],
    this.count,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      status: ProjectStatus.fromString(json['status'] ?? 'ACTIVE'),
      priority: Priority.fromString(json['priority'] ?? 'NOT_IMPORTANT_NOT_URGENT'),
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
      createdById: json['createdById'] ?? json['ownerId'] ?? '',
      createdBy: json['createdBy'],
      members: (json['members'] as List<dynamic>?)
          ?.map((m) => ProjectMember.fromJson(m))
          .toList() ?? [],
      tasks: List<Map<String, dynamic>>.from(json['tasks'] ?? []),
      subProjects: (json['subProjects'] as List<dynamic>?)
          ?.map((sp) => SubProject.fromJson(sp))
          .toList() ?? [],
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
      'createdById': createdById,
    };
  }

  // Helper methods
  String get statusLabel => status.label;
  String get priorityLabel => priority.label;
  int get priorityColor => priority.color;

  int get taskCount => count?['tasks'] ?? tasks.length;
  int get subProjectCount => count?['subProjects'] ?? subProjects.length;

  bool get isActive => status == ProjectStatus.active;
  bool get isCompleted => status == ProjectStatus.completed;

  // Get user's role in this project
  ProjectMemberRole? getUserRole(String userId) {
    final member = members.where((m) => m.userId == userId).firstOrNull;
    return member?.role;
  }

  bool isUserAdmin(String userId) {
    final role = getUserRole(userId);
    return role == ProjectMemberRole.owner || role == ProjectMemberRole.admin;
  }
}
