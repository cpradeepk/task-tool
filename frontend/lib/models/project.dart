import 'user.dart';

class Project {
  final String id;
  final String name;
  final String? description;
  final String status;
  final String? priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String ownerId;
  final Map<String, dynamic>? createdBy;
  final List<dynamic>? members;
  final Map<String, dynamic>? count;

  Project({
    required this.id,
    required this.name,
    this.description,
    required this.status,
    this.priority,
    required this.createdAt,
    required this.updatedAt,
    required this.ownerId,
    this.createdBy,
    this.members,
    this.count,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      status: json['status'] ?? 'ACTIVE',
      priority: json['priority'],
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
      ownerId: json['ownerId'] ?? json['createdById'] ?? '',
      createdBy: json['createdBy'],
      members: json['members'],
      count: json['_count'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'status': status,
      'priority': priority,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'ownerId': ownerId,
      'createdBy': createdBy,
      'members': members,
      '_count': count,
    };
  }
}

class ProjectMember {
  final String id;
  final String userId;
  final String projectId;
  final String role;
  final DateTime joinedAt;

  ProjectMember({
    required this.id,
    required this.userId,
    required this.projectId,
    required this.role,
    required this.joinedAt,
  });

  factory ProjectMember.fromJson(Map<String, dynamic> json) {
    return ProjectMember(
      id: json['id'],
      userId: json['userId'],
      projectId: json['projectId'],
      role: json['role'],
      joinedAt: DateTime.parse(json['joinedAt']),
    );
  }
}
