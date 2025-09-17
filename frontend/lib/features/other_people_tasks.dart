import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../modern_layout.dart';
import '../constants/task_constants.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://task.amtariksha.com');

class OtherPeopleTasksScreen extends StatefulWidget {
  const OtherPeopleTasksScreen({super.key});

  @override
  State<OtherPeopleTasksScreen> createState() => _OtherPeopleTasksScreenState();
}

class _OtherPeopleTasksScreenState extends State<OtherPeopleTasksScreen> {
  List<dynamic> _tasks = [];
  List<dynamic> _users = [];
  bool _isLoading = false;
  String? _selectedUserId;
  String _selectedStatus = 'All';
  String _selectedPriority = 'All';

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadTasks();
  }

  Future<String?> _getJwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  Future<void> _loadUsers() async {
    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.get(
        Uri.parse('$apiBase/task/api/admin/users'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        setState(() => _users = jsonDecode(response.body));
      }
    } catch (e) {
      print('Error loading users: $e');
      setState(() => _users = []);
    }
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);

    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      String url = '$apiBase/task/api/tasks/others';
      if (_selectedUserId != null) {
        url += '?assigned_to=$_selectedUserId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        setState(() => _tasks = jsonDecode(response.body));
      }
    } catch (e) {
      print('Error loading tasks: $e');
      setState(() => _tasks = []);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showTaskDetails(Map<String, dynamic> task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(task['title']),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.tag, size: 16),
                  const SizedBox(width: 4),
                  Text('ID: ${task['task_id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Text('Description: ${task['description']}'),
              const SizedBox(height: 8),
              Text('Project: ${task['project']}'),
              const SizedBox(height: 8),
              Text('Module: ${task['module']}'),
              const SizedBox(height: 8),
              Text('Assigned to: ${task['assigned_to']}'),
              const SizedBox(height: 8),
              Text('Status: ${task['status']}'),
              const SizedBox(height: 8),
              Text('Priority: ${task['priority']}'),
              const SizedBox(height: 8),
              Text('Due Date: ${task['due_date']}'),
              const SizedBox(height: 8),
              Text('Progress: ${task['completed_hours']}/${task['estimated_hours']} hours'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ModernLayout(
      title: 'Other People\'s Tasks',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.people, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Other People\'s Tasks',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Filters
            Row(
              children: [
                // User filter
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Filter by User',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    value: _selectedUserId,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Users')),
                      ..._users.map((user) => DropdownMenuItem(
                        value: user['id'].toString(),
                        child: Text(user['name']),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedUserId = value);
                      _loadTasks();
                    },
                  ),
                ),
                const SizedBox(width: 16),

                // Status filter
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Filter by Status',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.flag),
                    ),
                    value: _selectedStatus,
                    items: [
                      const DropdownMenuItem(value: 'All', child: Text('All Statuses')),
                      ...TaskStatus.values.map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedStatus = value!);
                      _loadTasks();
                    },
                  ),
                ),
                const SizedBox(width: 16),

                // Priority filter
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Filter by Priority',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.priority_high),
                    ),
                    value: _selectedPriority,
                    items: [
                      const DropdownMenuItem(value: 'All', child: Text('All Priorities')),
                      ...TaskPriority.values.map((priority) => DropdownMenuItem(
                        value: priority,
                        child: Text(priority),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedPriority = value!);
                      _loadTasks();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Tasks List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _tasks.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.task_alt, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('No tasks found', style: TextStyle(fontSize: 18, color: Colors.grey)),
                              Text('Try adjusting your filters', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _tasks.length,
                          itemBuilder: (context, index) {
                            final task = _tasks[index];
                            final completionPercentage = task['estimated_hours'] > 0 
                                ? (task['completed_hours'] / task['estimated_hours']) * 100 
                                : 0.0;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              child: ListTile(
                                leading: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: TaskStatus.getColor(task['status']),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                title: Text(
                                  task['title'],
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${task['task_id']} • ${task['assigned_to']}'),
                                    Text('${task['project']} → ${task['module']}'),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Chip(
                                          label: Text(
                                            task['priority'],
                                            style: const TextStyle(fontSize: 10),
                                          ),
                                          backgroundColor: TaskPriority.getColor(task['priority']).withOpacity(0.2),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Due: ${task['due_date']}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    LinearProgressIndicator(
                                      value: completionPercentage / 100,
                                      backgroundColor: Colors.grey.shade200,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        completionPercentage == 100 ? Colors.green : Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  onPressed: () => _showTaskDetails(task),
                                  icon: const Icon(Icons.info_outline),
                                  tooltip: 'View Details',
                                ),
                                onTap: () => _showTaskDetails(task),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
