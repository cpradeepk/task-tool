import 'dart:async';
import '../models/time_entry.dart';
import '../services/api_service.dart';

class TimeTrackingService {
  static final TimeTrackingService _instance = TimeTrackingService._internal();
  factory TimeTrackingService() => _instance;
  TimeTrackingService._internal();

  // Stream controllers for time tracking events
  final StreamController<TimeEntry> _timeEntryController = StreamController.broadcast();
  final StreamController<ActiveTimer?> _activeTimerController = StreamController.broadcast();

  // Getters for streams
  Stream<TimeEntry> get timeEntryStream => _timeEntryController.stream;
  Stream<ActiveTimer?> get activeTimerStream => _activeTimerController.stream;

  ActiveTimer? _activeTimer;
  Timer? _timerUpdateTimer;

  ActiveTimer? get activeTimer => _activeTimer;
  bool get hasActiveTimer => _activeTimer != null;

  // Time entry management
  Future<Map<String, dynamic>> getTimeEntries({
    int page = 1,
    int limit = 20,
    String? taskId,
    String? projectId,
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (taskId != null) queryParams['taskId'] = taskId;
      if (projectId != null) queryParams['projectId'] = projectId;
      if (userId != null) queryParams['userId'] = userId;
      if (startDate != null) queryParams['startDate'] = startDate.toIso8601String();
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();

      final response = await ApiService.get('/time-tracking', queryParams: queryParams);
      
      return {
        'entries': (response['entries'] as List<dynamic>)
            .map((data) => TimeEntry.fromJson(data))
            .toList(),
        'pagination': response['pagination'],
      };
    } catch (e) {
      throw Exception('Failed to get time entries: $e');
    }
  }

  Future<TimeEntry> createTimeEntry({
    required String taskId,
    required double hours,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    try {
      final response = await ApiService.post('/time-tracking', {
        'taskId': taskId,
        'hours': hours,
        'description': description,
        'startTime': startTime?.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
      });

      final timeEntry = TimeEntry.fromJson(response);
      _timeEntryController.add(timeEntry);
      return timeEntry;
    } catch (e) {
      throw Exception('Failed to create time entry: $e');
    }
  }

  Future<TimeEntry> updateTimeEntry(
    String entryId, {
    double? hours,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (hours != null) data['hours'] = hours;
      if (description != null) data['description'] = description;
      if (startTime != null) data['startTime'] = startTime.toIso8601String();
      if (endTime != null) data['endTime'] = endTime.toIso8601String();

      final response = await ApiService.put('/time-tracking/$entryId', data);
      
      final timeEntry = TimeEntry.fromJson(response);
      _timeEntryController.add(timeEntry);
      return timeEntry;
    } catch (e) {
      throw Exception('Failed to update time entry: $e');
    }
  }

  Future<void> deleteTimeEntry(String entryId) async {
    try {
      await ApiService.delete('/time-tracking/$entryId');
    } catch (e) {
      throw Exception('Failed to delete time entry: $e');
    }
  }

  // Timer management
  Future<ActiveTimer> startTimer(String taskId, String taskTitle, {String? description}) async {
    try {
      final response = await ApiService.post('/time-tracking/tasks/$taskId/start', {
        'description': description,
      });

      _activeTimer = ActiveTimer(
        taskId: taskId,
        taskTitle: taskTitle,
        startTime: DateTime.now(),
        description: description,
      );

      _activeTimerController.add(_activeTimer);
      _startTimerUpdates();

      return _activeTimer!;
    } catch (e) {
      throw Exception('Failed to start timer: $e');
    }
  }

  Future<TimeEntry> stopTimer(String taskId, {String? description}) async {
    try {
      final response = await ApiService.post('/time-tracking/tasks/$taskId/stop', {
        'description': description,
      });

      _activeTimer = null;
      _activeTimerController.add(null);
      _stopTimerUpdates();

      final timeEntry = TimeEntry.fromJson(response);
      _timeEntryController.add(timeEntry);
      return timeEntry;
    } catch (e) {
      throw Exception('Failed to stop timer: $e');
    }
  }

  void _startTimerUpdates() {
    _timerUpdateTimer?.cancel();
    _timerUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_activeTimer != null) {
        _activeTimerController.add(_activeTimer);
      }
    });
  }

  void _stopTimerUpdates() {
    _timerUpdateTimer?.cancel();
    _timerUpdateTimer = null;
  }

  // Task time tracking
  Future<List<TimeEntry>> getTaskTimeEntries(String taskId) async {
    try {
      final response = await ApiService.get('/time-tracking/tasks/$taskId');
      return (response as List<dynamic>)
          .map((data) => TimeEntry.fromJson(data))
          .toList();
    } catch (e) {
      throw Exception('Failed to get task time entries: $e');
    }
  }

  // Project time tracking
  Future<List<TimeEntry>> getProjectTimeEntries(String projectId) async {
    try {
      final response = await ApiService.get('/time-tracking/projects/$projectId');
      return (response as List<dynamic>)
          .map((data) => TimeEntry.fromJson(data))
          .toList();
    } catch (e) {
      throw Exception('Failed to get project time entries: $e');
    }
  }

  Future<TimeTrackingSummary> getProjectTimeSummary(String projectId) async {
    try {
      final response = await ApiService.get('/time-tracking/projects/$projectId/summary');
      return TimeTrackingSummary.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get project time summary: $e');
    }
  }

  // User time tracking
  Future<List<TimeEntry>> getUserTimeEntries(String userId) async {
    try {
      final response = await ApiService.get('/time-tracking/users/$userId');
      return (response as List<dynamic>)
          .map((data) => TimeEntry.fromJson(data))
          .toList();
    } catch (e) {
      throw Exception('Failed to get user time entries: $e');
    }
  }

  Future<TimeTrackingSummary> getUserTimeSummary(String userId) async {
    try {
      final response = await ApiService.get('/time-tracking/users/$userId/summary');
      return TimeTrackingSummary.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get user time summary: $e');
    }
  }

  // Reports
  Future<TimeTrackingReport> getDailyTimeReport({
    DateTime? date,
    String? userId,
    String? projectId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (date != null) queryParams['date'] = date.toIso8601String();
      if (userId != null) queryParams['userId'] = userId;
      if (projectId != null) queryParams['projectId'] = projectId;

      final response = await ApiService.get('/time-tracking/reports/daily', queryParams: queryParams);
      return TimeTrackingReport.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get daily time report: $e');
    }
  }

  Future<TimeTrackingReport> getWeeklyTimeReport({
    DateTime? startDate,
    String? userId,
    String? projectId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['startDate'] = startDate.toIso8601String();
      if (userId != null) queryParams['userId'] = userId;
      if (projectId != null) queryParams['projectId'] = projectId;

      final response = await ApiService.get('/time-tracking/reports/weekly', queryParams: queryParams);
      return TimeTrackingReport.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get weekly time report: $e');
    }
  }

  Future<TimeTrackingReport> getMonthlyTimeReport({
    DateTime? month,
    String? userId,
    String? projectId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (month != null) queryParams['month'] = month.toIso8601String();
      if (userId != null) queryParams['userId'] = userId;
      if (projectId != null) queryParams['projectId'] = projectId;

      final response = await ApiService.get('/time-tracking/reports/monthly', queryParams: queryParams);
      return TimeTrackingReport.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get monthly time report: $e');
    }
  }

  // Utility methods
  double calculateHours(DateTime startTime, DateTime endTime) {
    final duration = endTime.difference(startTime);
    return duration.inMinutes / 60.0;
  }

  String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String formatHours(double hours) {
    final h = hours.toInt();
    final m = ((hours % 1) * 60).toInt();
    
    if (h > 0) {
      return '${h}h ${m}m';
    } else {
      return '${m}m';
    }
  }

  // Local storage for active timer persistence
  Future<void> saveActiveTimer() async {
    // This would save to local storage for persistence across app restarts
    // Implementation depends on the storage solution used
  }

  Future<void> loadActiveTimer() async {
    // This would load from local storage
    // Implementation depends on the storage solution used
  }

  void dispose() {
    _timeEntryController.close();
    _activeTimerController.close();
    _stopTimerUpdates();
  }
}
