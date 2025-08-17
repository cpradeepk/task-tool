import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3003');

class ProjectExpandableCard extends StatefulWidget {
  final Map<String, dynamic> project;
  final VoidCallback? onTap;
  
  const ProjectExpandableCard({
    super.key, 
    required this.project, 
    this.onTap
  });

  @override
  State<ProjectExpandableCard> createState() => _ProjectExpandableCardState();
}

class _ProjectExpandableCardState extends State<ProjectExpandableCard> {
  bool _isExpanded = false;
  bool _isLoading = false;
  List<dynamic> _modules = [];
  Map<int, List<dynamic>> _moduleTasks = {};

  Future<void> _loadModulesAndTasks() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');
      
      if (jwt == null) return;
      
      // Load modules
      final modulesResponse = await http.get(
        Uri.parse('$apiBase/task/api/projects/${widget.project['id']}/modules'),
        headers: {'Authorization': 'Bearer $jwt'},
      );
      
      if (modulesResponse.statusCode == 200) {
        final modules = jsonDecode(modulesResponse.body) as List;
        setState(() => _modules = modules);
        
        // Load tasks for each module
        for (final module in modules) {
          final tasksResponse = await http.get(
            Uri.parse('$apiBase/task/api/modules/${module['id']}/tasks'),
            headers: {'Authorization': 'Bearer $jwt'},
          );
          
          if (tasksResponse.statusCode == 200) {
            final tasks = jsonDecode(tasksResponse.body) as List;
            setState(() => _moduleTasks[module['id']] = tasks);
          }
        }
      }
    } catch (e) {
      // Handle error silently
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              _isExpanded ? Icons.folder_open : Icons.folder,
              color: Colors.blue,
            ),
            title: Text(
              widget.project['name'] ?? 'Unnamed Project',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Project ID: ${widget.project['id']}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                IconButton(
                  icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () {
                    setState(() => _isExpanded = !_isExpanded);
                    if (_isExpanded && _modules.isEmpty) {
                      _loadModulesAndTasks();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: widget.onTap,
                  tooltip: 'Open Project',
                ),
              ],
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _modules.isEmpty
                  ? const Text(
                      'No modules in this project',
                      style: TextStyle(color: Colors.grey),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _modules.map((module) {
                        final tasks = _moduleTasks[module['id']] ?? [];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ExpansionTile(
                            leading: const Icon(Icons.view_module, color: Colors.green),
                            title: Text(
                              module['name'] ?? 'Unnamed Module',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text('${tasks.length} tasks'),
                            children: tasks.isEmpty
                                ? [
                                    const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                        'No tasks in this module',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  ]
                                : tasks.map<Widget>((task) {
                                    return ListTile(
                                      dense: true,
                                      leading: Icon(
                                        _getTaskIcon(task['status']),
                                        color: _getTaskColor(task['status']),
                                        size: 16,
                                      ),
                                      title: Text(
                                        task['title'] ?? 'Unnamed Task',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      subtitle: Text(
                                        '${task['status']} • ${task['priority']}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    );
                                  }).toList(),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getTaskIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'in progress':
        return Icons.play_circle;
      case 'hold':
        return Icons.pause_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  Color _getTaskColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in progress':
        return Colors.blue;
      case 'hold':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
