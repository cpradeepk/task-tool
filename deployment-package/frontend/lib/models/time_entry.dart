class TimeEntry {
  final String id;
  final double hours;
  final String? description;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isRunning;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> user;
  final Map<String, dynamic>? task;
  final Map<String, dynamic>? project;

  TimeEntry({
    required this.id,
    required this.hours,
    this.description,
    required this.startTime,
    this.endTime,
    required this.isRunning,
    required this.createdAt,
    required this.updatedAt,
    required this.user,
    this.task,
    this.project,
  });

  factory TimeEntry.fromJson(Map<String, dynamic> json) {
    return TimeEntry(
      id: json['id'],
      hours: (json['hours'] ?? 0).toDouble(),
      description: json['description'],
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      isRunning: json['isRunning'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      user: json['user'],
      task: json['task'],
      project: json['project'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hours': hours,
      'description': description,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'isRunning': isRunning,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'user': user,
      'task': task,
      'project': project,
    };
  }

  TimeEntry copyWith({
    String? id,
    double? hours,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    bool? isRunning,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? user,
    Map<String, dynamic>? task,
    Map<String, dynamic>? project,
  }) {
    return TimeEntry(
      id: id ?? this.id,
      hours: hours ?? this.hours,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isRunning: isRunning ?? this.isRunning,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      user: user ?? this.user,
      task: task ?? this.task,
      project: project ?? this.project,
    );
  }

  // Helper getters
  String get userName => user['name'] ?? 'Unknown';
  String get userEmail => user['email'] ?? '';
  String get taskTitle => task?['title'] ?? '';
  String get projectName => project?['name'] ?? '';
  
  Duration get duration {
    if (endTime != null) {
      return endTime!.difference(startTime);
    } else if (isRunning) {
      return DateTime.now().difference(startTime);
    }
    return Duration(hours: hours.toInt(), minutes: ((hours % 1) * 60).toInt());
  }

  String get formattedDuration {
    final d = duration;
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDate = DateTime(startTime.year, startTime.month, startTime.day);
    
    if (entryDate == today) {
      return 'Today';
    } else if (entryDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${startTime.day}/${startTime.month}/${startTime.year}';
    }
  }
}

class TimeTrackingSummary {
  final double totalHours;
  final int totalEntries;
  final double averageHoursPerDay;
  final Map<String, double> byTask;
  final Map<String, double> byProject;
  final Map<String, double> byDate;

  TimeTrackingSummary({
    required this.totalHours,
    required this.totalEntries,
    required this.averageHoursPerDay,
    required this.byTask,
    required this.byProject,
    required this.byDate,
  });

  factory TimeTrackingSummary.fromJson(Map<String, dynamic> json) {
    return TimeTrackingSummary(
      totalHours: (json['totalHours'] ?? 0).toDouble(),
      totalEntries: json['totalEntries'] ?? 0,
      averageHoursPerDay: (json['averageHoursPerDay'] ?? 0).toDouble(),
      byTask: Map<String, double>.from(json['byTask'] ?? {}),
      byProject: Map<String, double>.from(json['byProject'] ?? {}),
      byDate: Map<String, double>.from(json['byDate'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalHours': totalHours,
      'totalEntries': totalEntries,
      'averageHoursPerDay': averageHoursPerDay,
      'byTask': byTask,
      'byProject': byProject,
      'byDate': byDate,
    };
  }

  String get formattedTotalHours {
    final hours = totalHours.toInt();
    final minutes = ((totalHours % 1) * 60).toInt();
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}

class TimeTrackingReport {
  final DateTime startDate;
  final DateTime endDate;
  final TimeTrackingSummary summary;
  final List<TimeEntry> entries;
  final List<DailyTimeEntry> dailyBreakdown;

  TimeTrackingReport({
    required this.startDate,
    required this.endDate,
    required this.summary,
    required this.entries,
    required this.dailyBreakdown,
  });

  factory TimeTrackingReport.fromJson(Map<String, dynamic> json) {
    return TimeTrackingReport(
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      summary: TimeTrackingSummary.fromJson(json['summary']),
      entries: (json['entries'] as List<dynamic>)
          .map((e) => TimeEntry.fromJson(e))
          .toList(),
      dailyBreakdown: (json['dailyBreakdown'] as List<dynamic>)
          .map((d) => DailyTimeEntry.fromJson(d))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'summary': summary.toJson(),
      'entries': entries.map((e) => e.toJson()).toList(),
      'dailyBreakdown': dailyBreakdown.map((d) => d.toJson()).toList(),
    };
  }
}

class DailyTimeEntry {
  final DateTime date;
  final double hours;
  final int entries;

  DailyTimeEntry({
    required this.date,
    required this.hours,
    required this.entries,
  });

  factory DailyTimeEntry.fromJson(Map<String, dynamic> json) {
    return DailyTimeEntry(
      date: DateTime.parse(json['date']),
      hours: (json['hours'] ?? 0).toDouble(),
      entries: json['entries'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'hours': hours,
      'entries': entries,
    };
  }

  String get formattedDate {
    return '${date.day}/${date.month}';
  }

  String get formattedHours {
    final h = hours.toInt();
    final m = ((hours % 1) * 60).toInt();
    
    if (h > 0) {
      return '${h}h ${m}m';
    } else {
      return '${m}m';
    }
  }
}

class ActiveTimer {
  final String taskId;
  final String taskTitle;
  final DateTime startTime;
  final String? description;

  ActiveTimer({
    required this.taskId,
    required this.taskTitle,
    required this.startTime,
    this.description,
  });

  factory ActiveTimer.fromJson(Map<String, dynamic> json) {
    return ActiveTimer(
      taskId: json['taskId'],
      taskTitle: json['taskTitle'],
      startTime: DateTime.parse(json['startTime']),
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'taskTitle': taskTitle,
      'startTime': startTime.toIso8601String(),
      'description': description,
    };
  }

  Duration get elapsed => DateTime.now().difference(startTime);

  String get formattedElapsed {
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes % 60;
    final seconds = elapsed.inSeconds % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }
}
