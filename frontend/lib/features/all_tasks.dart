import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://task.amtariksha.com');

class AllTasksScreen extends StatefulWidget {
  const AllTasksScreen({super.key});

  @override
  State<AllTasksScreen> createState() => _AllTasksScreenState();
}

class _AllTasksScreenState extends State<AllTasksScreen> {
  List<dynamic> _tasks = [];
  List<dynamic> _projects = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Assigned to Me', 'Created by Me', 'In Progress', 'Completed'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<String?> _getJwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final jwt = await _getJwt();
    if (jwt == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Authentication required';
      });
      return;
    }

    try {
      // Load projects first
      final projectsResponse = await http.get(
        Uri.parse('$apiBase/task/api/projects'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (projectsResponse.statusCode == 200) {
        _projects = jsonDecode(projectsResponse.body);
      }

      // Load all tasks across projects
      List<dynamic> allTasks = [];
      for (final project in _projects) {
        try {
          final tasksResponse = await http.get(
            Uri.parse('$apiBase/task/api/projects/${project['id']}/tasks'),
            headers: {'Authorization': 'Bearer $jwt'},
          );

          if (tasksResponse.statusCode == 200) {
            final projectTasks = jsonDecode(tasksResponse.body) as List;
            // Add project info to each task
            for (final task in projectTasks) {
              task['project_name'] = project['name'];
              task['project_id'] = project['id'];
            }
            allTasks.addAll(projectTasks);
          }
        } catch (e) {
          // Continue loading other projects even if one fails
          print('Error loading tasks for project ${project['id']}: $e');
        }
      }

      setState(() {
        _tasks = allTasks;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load tasks: $e';
      });
    }
  }

  List<dynamic> _getFilteredTasks() {
    switch (_selectedFilter) {
      case 'Assigned to Me':
        return _tasks.where((task) => task['assigned_to'] != null).toList();
      case 'Created by Me':
        return _tasks.where((task) => task['created_by'] != null).toList();
      case 'In Progress':
        return _tasks.where((task) => task['status'] == 'in_progress').toList();
      case 'Completed':
        return _tasks.where((task) => task['status'] == 'completed').toList();
      default:
        return _tasks;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'completed':
        return 'Completed';
      case 'in_progress':
        return 'In Progress';
      case 'pending':
        return 'Pending';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredTasks = _getFilteredTasks();

    return Scaffold(
      body: Column(
        children: [
          // Header with filters
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.task_alt, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'All Tasks',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                DropdownButton<String>(
                  value: _selectedFilter,
                  items: _filters.map((filter) {
                    return DropdownMenuItem(
                      value: filter,
                      child: Text(filter),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedFilter = value!);
                  },
                ),
                const SizedBox(width: 16),
                Text(
                  '${filteredTasks.length} tasks',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          // Tasks List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, size: 64, color: Colors.red.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'Error Loading Tasks',
                              style: TextStyle(fontSize: 18, color: Colors.red.shade700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.grey.shade600),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadData,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : filteredTasks.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.task, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  'No tasks found',
                                  style: TextStyle(fontSize: 18, color: Colors.grey),
                                ),
                                Text(
                                  'Tasks will appear here once created',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredTasks.length,
                            itemBuilder: (context, index) {
                              final task = filteredTasks[index];
                              return _buildTaskCard(task);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        title: Text(
          task['title'] ?? 'Untitled Task',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task['description'] != null && task['description'].isNotEmpty)
              Text(
                task['description'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(task['status']),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getStatusLabel(task['status']),
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
                const SizedBox(width: 8),
                if (task['project_name'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      task['project_name'],
                      style: TextStyle(color: Colors.blue.shade700, fontSize: 10),
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          onPressed: () {
            if (task['project_id'] != null && task['id'] != null) {
              context.go('/projects/${task['project_id']}/tasks/${task['id']}');
            }
          },
          icon: const Icon(Icons.arrow_forward_ios, size: 16),
          tooltip: 'View Task Details',
        ),
      ),
    );
  }
}
