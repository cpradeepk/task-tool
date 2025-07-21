import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../services/api_service.dart';

class TaskProvider with ChangeNotifier {
  List<Task> _tasks = [];
  Task? _selectedTask;
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic> _filters = {};

  List<Task> get tasks => _tasks;
  Task? get selectedTask => _selectedTask;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic> get filters => _filters;

  Future<void> fetchTasks({Map<String, dynamic>? filters}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      String endpoint = '/tasks';
      if (filters != null && filters.isNotEmpty) {
        final queryParams = filters.entries
            .where((e) => e.value != null)
            .map((e) => '${e.key}=${e.value}')
            .join('&');
        endpoint += '?$queryParams';
      }

      final response = await ApiService.get(endpoint);
      _tasks = (response['tasks'] as List)
          .map((json) => Task.fromJson(json))
          .toList();
      _filters = filters ?? {};
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createTask({
    required String title,
    String? description,
    String? projectId,
    String? assignedToId,
    String priority = 'MEDIUM',
    DateTime? dueDate,
    double? estimatedHours,
    List<String>? tags,
  }) async {
    try {
      final response = await ApiService.post('/tasks', {
        'title': title,
        'description': description,
        'projectId': projectId,
        'assignedToId': assignedToId,
        'priority': priority,
        'dueDate': dueDate?.toIso8601String(),
        'estimatedHours': estimatedHours,
        'tags': tags,
      });

      final newTask = Task.fromJson(response);
      _tasks.insert(0, newTask);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTask(String id, Map<String, dynamic> updates) async {
    try {
      final response = await ApiService.put('/tasks/$id', updates);
      final updatedTask = Task.fromJson(response);
      
      final index = _tasks.indexWhere((t) => t.id == id);
      if (index != -1) {
        _tasks[index] = updatedTask;
        if (_selectedTask?.id == id) {
          _selectedTask = updatedTask;
        }
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTaskStatus(String id, String status) async {
    return updateTask(id, {'status': status});
  }

  void selectTask(Task task) {
    _selectedTask = task;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  List<Task> getTasksByStatus(String status) {
    return _tasks.where((task) => task.status == status).toList();
  }

  List<Task> getTasksByProject(String projectId) {
    return _tasks.where((task) => task.projectId == projectId).toList();
  }
}
