import 'package:flutter/foundation.dart';
import '../models/project.dart';
import '../services/api_service.dart';

class ProjectProvider with ChangeNotifier {
  List<Project> _projects = [];
  Project? _selectedProject;
  bool _isLoading = false;
  String? _error;

  List<Project> get projects => _projects;
  Project? get selectedProject => _selectedProject;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchProjects() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.get('/projects');
      _projects = (response['projects'] as List)
          .map((json) => Project.fromJson(json))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createProject({
    required String name,
    String? description,
    String priority = 'MEDIUM',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final response = await ApiService.post('/projects', {
        'name': name,
        'description': description,
        'priority': priority,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
      });

      final newProject = Project.fromJson(response);
      _projects.insert(0, newProject);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProject(String id, Map<String, dynamic> updates) async {
    try {
      final response = await ApiService.put('/projects/$id', updates);
      final updatedProject = Project.fromJson(response);
      
      final index = _projects.indexWhere((p) => p.id == id);
      if (index != -1) {
        _projects[index] = updatedProject;
        if (_selectedProject?.id == id) {
          _selectedProject = updatedProject;
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

  void selectProject(Project project) {
    _selectedProject = project;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
