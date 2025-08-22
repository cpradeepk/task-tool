import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../modern_layout.dart';
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

    // Load mock data for development
    _projects = [
      {'id': 1, 'name': 'Task Tool Development'},
      {'id': 2, 'name': 'Mobile App Development'},
      {'id': 3, 'name': 'Website Redesign'},
      {'id': 4, 'name': 'API Integration'},
    ];

    _modules = [
      {
        'id': 1,
        'name': 'Authentication Module',
        'description': 'User authentication and authorization system',
        'category': ProjectCategory.development,
        'status': 'Active',
        'taskCount': 12,
        'completedTasks': 8,
        'createdAt': '2025-01-10',
        'attachedProjects': [1, 2],
      },
      {
        'id': 2,
        'name': 'Dashboard Module',
        'description': 'Main dashboard with analytics and reporting',
        'category': ProjectCategory.development,
        'status': 'Active',
        'taskCount': 18,
        'completedTasks': 15,
        'createdAt': '2025-01-12',
        'attachedProjects': [1],
      },
      {
        'id': 3,
        'name': 'UI Design System',
        'description': 'Comprehensive design system and component library',
        'category': ProjectCategory.design,
        'status': 'Active',
        'taskCount': 25,
        'completedTasks': 20,
        'createdAt': '2025-01-08',
        'attachedProjects': [1, 3],
      },
      {
        'id': 4,
        'name': 'Payment Integration',
        'description': 'Payment gateway integration and processing',
        'category': ProjectCategory.development,
        'status': 'Planning',
        'taskCount': 8,
        'completedTasks': 0,
        'createdAt': '2025-01-15',
        'attachedProjects': [],
      },
      {
        'id': 5,
        'name': 'Marketing Automation',
        'description': 'Automated marketing campaigns and analytics',
        'category': ProjectCategory.marketing,
        'status': 'Active',
        'taskCount': 15,
        'completedTasks': 10,
        'createdAt': '2025-01-05',
        'attachedProjects': [3],
      },
    ];

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

  void _createModule(String name, String description, String category, String status) {
    setState(() {
      _modules.add({
        'id': _modules.length + 1,
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Module created successfully'), backgroundColor: Colors.green),
    );
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
    return ModernLayout(
      title: 'Module Management',
      child: Padding(
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
      ),
    );
  }
}
