import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String apiBase = 'https://task.amtariksha.com';

class ProjectDetailScreen extends StatefulWidget {
  final int projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  Map<String, dynamic>? _project;
  List<dynamic> _modules = [];
  Map<int, List<dynamic>> _moduleTasks = {}; // moduleId -> tasks
  Map<int, List<dynamic>> _taskSubtasks = {}; // taskId -> subtasks
  Map<int, bool> _moduleExpanded = {}; // moduleId -> expanded state
  Map<int, bool> _taskExpanded = {}; // taskId -> expanded state
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProjectData();
  }

  Future<String?> _getJwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  Future<void> _loadProjectData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final jwt = await _getJwt();
      if (jwt == null) {
        setState(() {
          _errorMessage = 'Authentication required';
          _isLoading = false;
        });
        return;
      }

      // Load project details
      await _loadProject(jwt);
      
      // Load modules for this project
      await _loadModules(jwt);
      
      // Load tasks for each module
      for (final module in _modules) {
        await _loadModuleTasks(jwt, module['id']);
      }

    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading project data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProject(String jwt) async {
    final response = await http.get(
      Uri.parse('$apiBase/task/api/projects/${widget.projectId}'),
      headers: {'Authorization': 'Bearer $jwt'},
    );

    if (response.statusCode == 200) {
      setState(() {
        _project = jsonDecode(response.body);
      });
    } else {
      throw Exception('Failed to load project: ${response.statusCode}');
    }
  }

  Future<void> _loadModules(String jwt) async {
    final response = await http.get(
      Uri.parse('$apiBase/task/api/projects/${widget.projectId}/modules'),
      headers: {'Authorization': 'Bearer $jwt'},
    );

    if (response.statusCode == 200) {
      final modules = jsonDecode(response.body) as List<dynamic>;
      setState(() {
        _modules = modules;
        // Set all modules to expanded by default
        for (final module in modules) {
          _moduleExpanded[module['id']] = true;
        }
      });
    } else {
      throw Exception('Failed to load modules: ${response.statusCode}');
    }
  }

  Future<void> _loadModuleTasks(String jwt, int moduleId) async {
    final response = await http.get(
      Uri.parse('$apiBase/task/api/projects/${widget.projectId}/modules/$moduleId/tasks'),
      headers: {'Authorization': 'Bearer $jwt'},
    );

    if (response.statusCode == 200) {
      final tasks = jsonDecode(response.body) as List<dynamic>;
      setState(() {
        _moduleTasks[moduleId] = tasks;
        // Set all tasks to collapsed by default
        for (final task in tasks) {
          _taskExpanded[task['id']] = false;
        }
      });
    }
  }

  Future<void> _loadTaskSubtasks(String jwt, int taskId) async {
    final response = await http.get(
      Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks/$taskId/subtasks'),
      headers: {'Authorization': 'Bearer $jwt'},
    );

    if (response.statusCode == 200) {
      final subtasks = jsonDecode(response.body) as List<dynamic>;
      setState(() {
        _taskSubtasks[taskId] = subtasks;
      });
    }
  }

  void _toggleModuleExpansion(int moduleId) {
    setState(() {
      _moduleExpanded[moduleId] = !(_moduleExpanded[moduleId] ?? false);
    });
  }

  void _toggleTaskExpansion(int taskId) async {
    final isExpanded = _taskExpanded[taskId] ?? false;
    
    if (!isExpanded && !_taskSubtasks.containsKey(taskId)) {
      // Load subtasks if not already loaded
      final jwt = await _getJwt();
      if (jwt != null) {
        await _loadTaskSubtasks(jwt, taskId);
      }
    }
    
    setState(() {
      _taskExpanded[taskId] = !isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFFA301))),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: const Color(0xFFE6920E), size: 64),
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(color: Color(0xFFE6920E))),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProjectData,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA301)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_project?['name'] ?? 'Project Details'),
        backgroundColor: const Color(0xFFFFA301),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProjectData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildProjectHierarchy(),
    );
  }

  Widget _buildProjectHierarchy() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project header
          _buildProjectHeader(),
          const SizedBox(height: 24),
          
          // Modules hierarchy
          if (_modules.isEmpty)
            _buildEmptyState()
          else
            ..._modules.map((module) => _buildModuleCard(module)).toList(),
        ],
      ),
    );
  }

  Widget _buildProjectHeader() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFA301).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.folder, color: Color(0xFFFFA301), size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _project?['name'] ?? 'Unknown Project',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  if (_project?['description'] != null)
                    Text(
                      _project!['description'],
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.folder_open, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No modules found in this project',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                'Create modules to organize your tasks',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModuleCard(Map<String, dynamic> module) {
    final moduleId = module['id'] as int;
    final isExpanded = _moduleExpanded[moduleId] ?? true;
    final tasks = _moduleTasks[moduleId] ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          // Module header
          InkWell(
            onTap: () => _toggleModuleExpansion(moduleId),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.expand_more : Icons.chevron_right,
                    color: const Color(0xFFFFA301),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFA301).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.view_module, color: Color(0xFFFFA301), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          module['name'] ?? 'Unnamed Module',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        if (module['description'] != null && module['description'].toString().isNotEmpty)
                          Text(
                            module['description'],
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFA301).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${tasks.length} tasks',
                      style: const TextStyle(
                        color: Color(0xFFFFA301),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tasks list (when expanded)
          if (isExpanded && tasks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 32, right: 16, bottom: 16),
              child: Column(
                children: tasks.map<Widget>((task) => _buildTaskItem(task)).toList(),
              ),
            ),

          // Empty tasks state
          if (isExpanded && tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 32, right: 16, bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.task_alt, color: Colors.grey.shade400),
                    const SizedBox(width: 12),
                    Text(
                      'No tasks in this module',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task) {
    final taskId = task['id'] as int;
    final isExpanded = _taskExpanded[taskId] ?? false;
    final subtasks = _taskSubtasks[taskId] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Task header
          InkWell(
            onTap: () => _toggleTaskExpansion(taskId),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.expand_more : Icons.chevron_right,
                    color: const Color(0xFFFFA301),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFA301).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.task, color: Color(0xFFFFA301), size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task['title'] ?? 'Unnamed Task',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        if (task['description'] != null && task['description'].toString().isNotEmpty)
                          Text(
                            task['description'],
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (subtasks.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFA301).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${subtasks.length}',
                        style: const TextStyle(
                          color: Color(0xFFFFA301),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Subtasks list (when expanded)
          if (isExpanded && subtasks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 32, right: 12, bottom: 12),
              child: Column(
                children: subtasks.map<Widget>((subtask) => _buildSubtaskItem(subtask)).toList(),
              ),
            ),

          // Empty subtasks state
          if (isExpanded && subtasks.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 32, right: 12, bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.subdirectory_arrow_right, color: Colors.grey.shade400, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'No subtasks',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubtaskItem(Map<String, dynamic> subtask) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.subdirectory_arrow_right, color: Colors.grey.shade400, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              subtask['title'] ?? 'Unnamed Subtask',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getStatusColor(subtask['status']).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              subtask['status'] ?? 'Open',
              style: TextStyle(
                color: _getStatusColor(subtask['status']),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
      case 'done':
        return Colors.green;
      case 'in progress':
      case 'in_progress':
        return const Color(0xFFFFA301);
      case 'blocked':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}
