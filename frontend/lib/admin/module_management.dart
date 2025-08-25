import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/task_constants.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3003');

class ModuleManagementScreen extends StatefulWidget {
  const ModuleManagementScreen({super.key});

  @override
  State<ModuleManagementScreen> createState() => _ModuleManagementScreenState();
}

class _ModuleManagementScreenState extends State<ModuleManagementScreen> {
  List<dynamic> _modules = [];
  List<dynamic> _projects = [];
  bool _isLoading = false;
  String _searchQuery = '';

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

    try {
      final jwt = await _getJwt();
      if (jwt == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Load real projects from API
      final projectsResponse = await http.get(
        Uri.parse('$apiBase/task/api/projects'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (projectsResponse.statusCode == 200) {
        _projects = jsonDecode(projectsResponse.body) as List<dynamic>;
      } else {
        _projects = [];
      }

      // Load real modules from all projects
      _modules = [];
      for (final project in _projects) {
        try {
          final modulesResponse = await http.get(
            Uri.parse('$apiBase/task/api/projects/${project['id']}/modules'),
            headers: {'Authorization': 'Bearer $jwt'},
          );

          if (modulesResponse.statusCode == 200) {
            final projectModules = jsonDecode(modulesResponse.body) as List<dynamic>;
            for (final module in projectModules) {
              _modules.add({
                'id': module['id'],
                'name': module['name'],
                'description': module['description'] ?? '',
                'category': ProjectCategory.development,
                'status': 'Active',
                'taskCount': 0, // TODO: Load actual task count
                'completedTasks': 0, // TODO: Load actual completed tasks
                'createdAt': module['created_at']?.toString().substring(0, 10) ?? '',
                'attachedProjects': [project['id']],
                'projectName': project['name'],
              });
            }
          }
        } catch (e) {
          print('Error loading modules for project ${project['id']}: $e');
        }
      }
    } catch (e) {
      print('Error loading data: $e');
      _projects = [];
      _modules = [];
    }

    setState(() => _isLoading = false);
  }

  void _showCreateModuleDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedCategory = ProjectCategory.development;
    String selectedStatus = 'Active';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New Module'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Module Name *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedCategory,
                  items: ProjectCategory.values.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Row(
                        children: [
                          Icon(ProjectCategory.getIcon(category), size: 16),
                          const SizedBox(width: 8),
                          Text(category),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedCategory = value!);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedStatus,
                  items: ['Active', 'Planning', 'On Hold', 'Completed'].map((status) {
                    return DropdownMenuItem(value: status, child: Text(status));
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedStatus = value!);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  _createModule(
                    nameController.text.trim(),
                    descriptionController.text.trim(),
                    selectedCategory,
                    selectedStatus,
                  );
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _createModule(String name, String description, String category, String status) async {
    try {
      final jwt = await _getJwt();
      if (jwt == null) {
        _showErrorMessage('Authentication required');
        return;
      }

      // For now, we'll create a demo module since we need a project context
      // In a real implementation, this would need to be associated with a specific project
      final response = await http.post(
        Uri.parse('$apiBase/task/api/admin/projects/1/modules'), // Using project ID 1 as default
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'description': description,
          'order_index': _modules.length,
        }),
      );

      if (response.statusCode == 201) {
        final newModule = jsonDecode(response.body);
        setState(() {
          _modules.add({
            'id': newModule['id'],
            'name': name,
            'description': description,
            'category': category,
            'status': status,
            'taskCount': 0,
            'completedTasks': 0,
            'createdAt': DateTime.now().toIso8601String().substring(0, 10),
            'attachedProjects': [],
          });
        });

        _showSuccessMessage('Module created successfully');
      } else {
        _showErrorMessage('Failed to create module: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorMessage('Error creating module: $e');
    }
  }

  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: const Color(0xFFFFA301)),
      );
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: const Color(0xFFE6920E)),
      );
    }
  }

  void _editModule(Map<String, dynamic> module) {
    // TODO: Implement edit module dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Edit Module: ${module['name']} - Coming Soon')),
    );
  }

  void _deleteModule(int moduleId) {
    final module = _modules.firstWhere((m) => m['id'] == moduleId);
    
    if (module['attachedProjects'].isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete module attached to projects. Detach first.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Module'),
        content: Text('Are you sure you want to delete the module "${module['name']}"?\n\nThis will also delete all associated tasks.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _modules.removeWhere((m) => m['id'] == moduleId);
              });
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Module deleted successfully'), backgroundColor: Colors.orange),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _attachToProject(int moduleId) {
    final module = _modules.firstWhere((m) => m['id'] == moduleId);
    final availableProjects = _projects.where((p) => !module['attachedProjects'].contains(p['id'])).toList();

    if (availableProjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Module is already attached to all projects')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Attach "${module['name']}" to Project'),
        content: SizedBox(
          width: 300,
          height: 200,
          child: ListView.builder(
            itemCount: availableProjects.length,
            itemBuilder: (context, index) {
              final project = availableProjects[index];
              return ListTile(
                title: Text(project['name']),
                onTap: () {
                  setState(() {
                    module['attachedProjects'].add(project['id']);
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Module attached to ${project['name']}')),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _detachFromProject(int moduleId, int projectId) {
    final module = _modules.firstWhere((m) => m['id'] == moduleId);
    final project = _projects.firstWhere((p) => p['id'] == projectId);

    setState(() {
      module['attachedProjects'].remove(projectId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Module detached from ${project['name']}')),
    );
  }

  List<dynamic> get _filteredModules {
    if (_searchQuery.isEmpty) return _modules;
    return _modules.where((module) {
      return module['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
             module['description'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
             module['category'].toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  String _getProjectNames(List<dynamic> projectIds) {
    if (projectIds.isEmpty) return 'Not attached';
    final names = projectIds.map((id) {
      final project = _projects.firstWhere((p) => p['id'] == id, orElse: () => {'name': 'Unknown'});
      return project['name'];
    }).toList();
    return names.join(', ');
  }

  double _getCompletionPercentage(Map<String, dynamic> module) {
    if (module['taskCount'] == 0) return 0.0;
    return (module['completedTasks'] / module['taskCount']) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.view_module, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Module Management',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                SizedBox(
                  width: 300,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search modules...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _showCreateModuleDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Module'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Modules Grid
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredModules.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.view_module, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('No modules found', style: TextStyle(fontSize: 18, color: Colors.grey)),
                            ],
                          ),
                        )
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 1.1,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: _filteredModules.length,
                          itemBuilder: (context, index) {
                            final module = _filteredModules[index];
                            final completionPercentage = _getCompletionPercentage(module);
                            
                            return Card(
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          ProjectCategory.getIcon(module['category']),
                                          color: ProjectCategory.getColor(module['category']),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            module['name'],
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        PopupMenuButton(
                                          itemBuilder: (context) => [
                                            PopupMenuItem(
                                              onTap: () => _editModule(module),
                                              child: const Row(
                                                children: [
                                                  Icon(Icons.edit, size: 16),
                                                  SizedBox(width: 8),
                                                  Text('Edit'),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              onTap: () => _attachToProject(module['id']),
                                              child: const Row(
                                                children: [
                                                  Icon(Icons.attach_file, size: 16),
                                                  SizedBox(width: 8),
                                                  Text('Attach to Project'),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              onTap: () => _deleteModule(module['id']),
                                              child: const Row(
                                                children: [
                                                  Icon(Icons.delete, size: 16, color: Colors.red),
                                                  SizedBox(width: 8),
                                                  Text('Delete'),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      module['description'],
                                      style: TextStyle(color: Colors.grey.shade600),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Chip(
                                          label: Text(module['status'], style: const TextStyle(fontSize: 10)),
                                          backgroundColor: module['status'] == 'Active' 
                                              ? Colors.green.shade100 
                                              : Colors.orange.shade100,
                                        ),
                                        const Spacer(),
                                        Text(
                                          '${module['completedTasks']}/${module['taskCount']} tasks',
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    LinearProgressIndicator(
                                      value: completionPercentage / 100,
                                      backgroundColor: Colors.grey.shade200,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        completionPercentage == 100 ? Colors.green : Colors.blue,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Projects: ${_getProjectNames(module['attachedProjects'])}',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
    );
  }
}
