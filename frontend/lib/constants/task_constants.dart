import 'package:flutter/material.dart';

// Eisenhower Matrix Priority System
class TaskPriority {
  static const String importantUrgent = 'Important & Urgent';
  static const String importantNotUrgent = 'Important & Not Urgent';
  static const String notImportantUrgent = 'Not Important & Urgent';
  static const String notImportantNotUrgent = 'Not Important & Not Urgent';

  static const List<String> values = [
    importantUrgent,
    importantNotUrgent,
    notImportantUrgent,
    notImportantNotUrgent,
  ];

  static const Map<String, int> order = {
    importantUrgent: 1,
    importantNotUrgent: 2,
    notImportantUrgent: 3,
    notImportantNotUrgent: 4,
  };

  static const Map<String, Color> colors = {
    importantUrgent: Colors.orange,
    importantNotUrgent: Colors.yellow,
    notImportantUrgent: Colors.white,
    notImportantNotUrgent: Colors.white,
  };

  static const Map<String, String> descriptions = {
    importantUrgent: 'Priority 1 - Do First (Crisis, emergencies)',
    importantNotUrgent: 'Priority 2 - Schedule (Prevention, planning)',
    notImportantUrgent: 'Priority 3 - Delegate (Interruptions, some emails)',
    notImportantNotUrgent: 'Priority 4 - Eliminate (Time wasters, busy work)',
  };

  static Color getColor(String priority) {
    return colors[priority] ?? Colors.grey;
  }

  static int getOrder(String priority) {
    return order[priority] ?? 5;
  }

  static String getDescription(String priority) {
    return descriptions[priority] ?? 'Unknown priority';
  }
}

// Color-Coded Status System
class TaskStatus {
  static const String open = 'Open';
  static const String inProgress = 'In Progress';
  static const String completed = 'Completed';
  static const String cancelled = 'Cancelled';
  static const String hold = 'Hold';
  static const String delayed = 'Delayed';

  static const List<String> values = [
    open,
    inProgress,
    completed,
    cancelled,
    hold,
    delayed,
  ];

  static const Map<String, Color> colors = {
    open: Color(0xFFFFF8E6),
    inProgress: Color(0xFFFFCA1A),
    completed: Color(0xFFE6920E),
    cancelled: Color(0xFFA0A0A0),
    hold: Color(0xFFCC8200),
    delayed: Color(0xFFB37200),
  };

  static const Map<String, Color> backgroundColors = {
    open: Color(0xFFF5F5F5),
    inProgress: Color(0xFFFFF3CD),
    completed: Color(0xFFD4EDDA),
    cancelled: Color(0xFFE2E3E5),
    hold: Color(0xFFEDDDD4),
    delayed: Color(0xFFF8D7DA),
  };

  static const Map<String, String> descriptions = {
    open: 'Task is open and ready to start',
    inProgress: 'Task is currently being worked on',
    completed: 'Task has been completed successfully',
    cancelled: 'Task has been cancelled',
    hold: 'Task is temporarily on hold',
    delayed: 'Task is delayed beyond original timeline',
  };

  static Color getColor(String status) {
    return colors[status] ?? Colors.grey;
  }

  static Color getBackgroundColor(String status) {
    return backgroundColors[status] ?? Colors.grey.shade100;
  }

  static String getDescription(String status) {
    return descriptions[status] ?? 'Unknown status';
  }

  static bool shouldAutoPopulateStartDate(String status) {
    return status == inProgress;
  }

  static bool shouldAutoPopulateEndDate(String status) {
    return status == completed;
  }
}

// Task ID Generation
class TaskIdGenerator {
  static String generate(DateTime creationDate, int dailyCounter) {
    final dateStr = creationDate.toIso8601String().substring(0, 10).replaceAll('-', '');
    final counterStr = dailyCounter.toString().padLeft(3, '0');
    return 'JSR-$dateStr-$counterStr';
  }

  static String generateFromDate(DateTime date) {
    // This would typically get the counter from database
    // For now, using a simple timestamp-based approach
    final dateStr = date.toIso8601String().substring(0, 10).replaceAll('-', '');
    final timeStr = date.millisecondsSinceEpoch.toString().substring(10);
    return 'JSR-$dateStr-$timeStr';
  }

  static bool isValidTaskId(String taskId) {
    final regex = RegExp(r'^JSR-\d{8}-\d{3}$');
    return regex.hasMatch(taskId);
  }

  static DateTime? getCreationDateFromTaskId(String taskId) {
    if (!isValidTaskId(taskId)) return null;
    
    final parts = taskId.split('-');
    if (parts.length != 3) return null;
    
    final dateStr = parts[1];
    if (dateStr.length != 8) return null;
    
    try {
      final year = int.parse(dateStr.substring(0, 4));
      final month = int.parse(dateStr.substring(4, 6));
      final day = int.parse(dateStr.substring(6, 8));
      return DateTime(year, month, day);
    } catch (e) {
      return null;
    }
  }
}

// Project Categories
class ProjectCategory {
  static const String development = 'Development';
  static const String design = 'Design';
  static const String marketing = 'Marketing';
  static const String research = 'Research';
  static const String operations = 'Operations';
  static const String maintenance = 'Maintenance';
  static const String testing = 'Testing';
  static const String documentation = 'Documentation';

  static const List<String> values = [
    development,
    design,
    marketing,
    research,
    operations,
    maintenance,
    testing,
    documentation,
  ];

  static const Map<String, Color> colors = {
    development: Color(0xFFFFA301),
    design: Color(0xFFE6920E),
    marketing: Color(0xFFCC8200),
    research: Color(0xFFB37200),
    operations: Color(0xFF996200),
    maintenance: Color(0xFFFFCA1A),
    testing: Color(0xFFFFD54D),
    documentation: Color(0xFFFFE080),
  };

  static const Map<String, IconData> icons = {
    development: Icons.code,
    design: Icons.palette,
    marketing: Icons.campaign,
    research: Icons.search,
    operations: Icons.settings,
    maintenance: Icons.build,
    testing: Icons.bug_report,
    documentation: Icons.description,
  };

  static Color getColor(String category) {
    return colors[category] ?? Colors.grey;
  }

  static IconData getIcon(String category) {
    return icons[category] ?? Icons.folder;
  }
}

// User Roles
class UserRole {
  static const String admin = 'Admin';
  static const String projectManager = 'Project Manager';
  static const String teamLead = 'Team Lead';
  static const String developer = 'Developer';
  static const String designer = 'Designer';
  static const String tester = 'Tester';
  static const String viewer = 'Viewer';

  static const List<String> values = [
    admin,
    projectManager,
    teamLead,
    developer,
    designer,
    tester,
    viewer,
  ];

  static const Map<String, Color> colors = {
    admin: Color(0xFFB37200),
    projectManager: Color(0xFFFFA301),
    teamLead: Color(0xFFE6920E),
    developer: Color(0xFFCC8200),
    designer: Color(0xFFFFCA1A),
    tester: Color(0xFFFFD54D),
    viewer: Color(0xFFA0A0A0),
  };

  static const Map<String, List<String>> permissions = {
    admin: ['*'],
    projectManager: ['projects.*', 'tasks.*', 'reports.*', 'users.read'],
    teamLead: ['tasks.*', 'projects.read', 'users.read'],
    developer: ['tasks.read', 'tasks.update', 'projects.read'],
    designer: ['tasks.read', 'tasks.update', 'projects.read'],
    tester: ['tasks.read', 'tasks.update', 'projects.read'],
    viewer: ['tasks.read', 'projects.read'],
  };

  static Color getColor(String role) {
    return colors[role] ?? Colors.grey;
  }

  static List<String> getPermissions(String role) {
    return permissions[role] ?? ['tasks.read'];
  }

  static bool hasPermission(String role, String permission) {
    final rolePermissions = getPermissions(role);
    return rolePermissions.contains('*') || 
           rolePermissions.contains(permission) ||
           rolePermissions.any((p) => p.endsWith('.*') && permission.startsWith(p.substring(0, p.length - 1)));
  }
}
