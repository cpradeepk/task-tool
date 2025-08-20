import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../main_layout.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://task.amtariksha.com');

class ProjectSettingsScreen extends StatefulWidget {
  final String? projectId;
  
  const ProjectSettingsScreen({super.key, this.projectId});

  @override
  State<ProjectSettingsScreen> createState() => _ProjectSettingsScreenState();
}

class _ProjectSettingsScreenState extends State<ProjectSettingsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _projects = [];
  List<dynamic> _modules = [];
  List<dynamic> _users = [];
  List<dynamic> _projectTeam = [];
  int? _selectedProjectId;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedProjectId = widget.projectId != null ? int.tryParse(widget.projectId!) : null;
    _loadProjects();
  }

  Future<String?> _getJwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);

    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.get(
        Uri.parse('$apiBase/task/api/admin/projects'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        final projectsData = jsonDecode(response.body);
        print('Loaded projects data: $projectsData'); // Debug log
        setState(() => _projects = projectsData);
        if (_selectedProjectId != null) {
          _loadModules();
          _loadProjectTeam();
        }
        _loadUsers();
      } else {
        setState(() => _errorMessage = 'Failed to load projects');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error loading projects: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadModules() async {
    if (_selectedProjectId == null) return;

    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.get(
        Uri.parse('$apiBase/task/api/admin/projects/$_selectedProjectId/modules'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        setState(() => _modules = jsonDecode(response.body));
      }
    } catch (e) {
      print('Error loading modules: $e');
      setState(() => _modules = []);
    }
  }

  Future<void> _createModule(String name, String description) async {
    if (_selectedProjectId == null) return;

    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.post(
        Uri.parse('$apiBase/task/api/admin/projects/$_selectedProjectId/modules'),
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
        _showSuccessMessage('Module created successfully');
        _loadModules();
      } else {
        String errorMessage = 'Failed to create module';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = 'Failed to create module: ${errorData['error'] ?? 'Unknown error'}';
        } catch (e) {
          errorMessage = 'Failed to create module: ${response.statusCode}';
        }
        _showErrorMessage(errorMessage);
      }
    } catch (e) {
      _showErrorMessage('Error creating module: $e');
    }
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
      // Use mock users for development
      setState(() => _users = [
        {'id': 1, 'email': 'john@example.com', 'name': 'John Doe'},
        {'id': 2, 'email': 'jane@example.com', 'name': 'Jane Smith'},
        {'id': 3, 'email': 'mike@example.com', 'name': 'Mike Johnson'},
      ]);
    }
  }

  Future<void> _loadProjectTeam() async {
    if (_selectedProjectId == null) return;

    final jwt = await _getJwt();
    if (jwt == null) return;

    // Clear team members immediately to prevent showing wrong data
    setState(() => _projectTeam = []);

    try {
      print('Loading team members for project: $_selectedProjectId'); // Debug log

      final response = await http.get(
        Uri.parse('$apiBase/task/api/admin/projects/$_selectedProjectId/team'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        final teamMembers = jsonDecode(response.body) as List;
        print('Loaded ${teamMembers.length} team members for project $_selectedProjectId'); // Debug log

        // Only update if we're still on the same project (prevent race conditions)
        if (_selectedProjectId != null) {
          setState(() {
            _projectTeam = teamMembers.map((member) => {
              'userId': member['user_id'],
              'role': member['role'],
              'assignedAt': member['assigned_at']?.toString().substring(0, 10) ?? '',
              'user': member['user'] ?? {},
              'projectId': _selectedProjectId, // Add project ID for verification
            }).toList();
          });
        }
      } else {
        print('Failed to load project team: ${response.statusCode} - ${response.body}');
        setState(() => _projectTeam = []);
      }
    } catch (e) {
      print('Error loading project team: $e');
      setState(() => _projectTeam = []);
    }
  }

  void _showAddModuleDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Module'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Module Name',
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                _createModule(nameController.text.trim(), descriptionController.text.trim());
                Navigator.of(context).pop();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }



  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Project Settings',
      child: Column(
        children: [
          // Header with project selection
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Header row
                Row(
                  children: [
                    const Icon(Icons.settings, color: Colors.blue, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'Project Settings',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Centered project selection dropdown
                Center(
                  child: SizedBox(
                    width: 400,
                    child: DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: 'Select Project',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.folder),
                      ),
                      value: _selectedProjectId,
                      items: _projects.map<DropdownMenuItem<int>>((project) {
                        return DropdownMenuItem<int>(
                          value: project['id'],
                          child: Text(project['name'] ?? 'Unnamed Project'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedProjectId = value;
                          // Clear previous project data when switching projects
                          _modules.clear();
                          _projectTeam.clear();
                        });
                        if (value != null) {
                          _loadModules();
                          _loadProjectTeam();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tab Bar
          if (_selectedProjectId != null)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info),
                        SizedBox(width: 8),
                        Text('Project Info'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.view_module),
                        SizedBox(width: 8),
                        Text('Modules'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people),
                        SizedBox(width: 8),
                        Text('Team'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Tab Content
          if (_selectedProjectId != null)
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildProjectInfoTab(),
                  _buildModulesTab(),
                  _buildTeamTab(),
                ],
              ),
            )
          else
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_open, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Select a project to manage settings',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProjectInfoTab() {
    final project = _projects.firstWhere(
      (p) => p['id'] == _selectedProjectId,
      orElse: () => null,
    );

    if (project == null) {
      return const Center(child: Text('Project not found'));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      project['name'],
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showEditProjectDialog(project),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Project'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showDeleteProjectDialog(project),
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                project['description'] ?? 'No description available',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _buildInfoCard('Status', project['status'] ?? 'Active', Icons.flag),
                  const SizedBox(width: 16),
                  _buildInfoCard('Start Date', project['start_date'] ?? 'Not set', Icons.calendar_today),
                  const SizedBox(width: 16),
                  _buildInfoCard('End Date', project['end_date'] ?? 'Not set', Icons.event),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditProjectDialog(Map<String, dynamic> project) {
    final nameController = TextEditingController(text: project['name']);
    final descriptionController = TextEditingController(text: project['description'] ?? '');
    String selectedStatus = project['status'] ?? 'Active';
    DateTime? startDate = project['start_date'] != null ? DateTime.parse(project['start_date']) : null;
    DateTime? endDate = project['end_date'] != null ? DateTime.parse(project['end_date']) : null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Project'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Project Name *',
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
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedStatus,
                    items: ['Active', 'Planning', 'On Hold', 'Completed', 'Cancelled'].map((status) {
                      return DropdownMenuItem(value: status, child: Text(status));
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedStatus = value!);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: startDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (date != null) {
                              setDialogState(() => startDate = date);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Start Date',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              startDate != null
                                  ? startDate!.toIso8601String().substring(0, 10)
                                  : 'Select start date',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: endDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (date != null) {
                              setDialogState(() => endDate = date);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'End Date',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              endDate != null
                                  ? endDate!.toIso8601String().substring(0, 10)
                                  : 'Select end date',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
                  _updateProject(
                    project['id'],
                    nameController.text.trim(),
                    descriptionController.text.trim(),
                    selectedStatus,
                    startDate,
                    endDate,
                  );
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateProject(int projectId, String name, String description, String status, DateTime? startDate, DateTime? endDate) async {
    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.put(
        Uri.parse('$apiBase/task/api/admin/projects/$projectId'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'description': description,
          'status': status,
          'start_date': startDate?.toIso8601String().substring(0, 10),
          'end_date': endDate?.toIso8601String().substring(0, 10),
        }),
      );

      if (response.statusCode == 200) {
        // Update local state with the response from server
        final updatedProject = jsonDecode(response.body);
        setState(() {
          final projectIndex = _projects.indexWhere((p) => p['id'] == projectId);
          if (projectIndex != -1) {
            _projects[projectIndex] = updatedProject;
          }
        });

        _showSuccessMessage('Project updated successfully');

        // Reload projects to ensure consistency
        _loadProjects();
      } else {
        String errorMessage = 'Failed to update project';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = 'Failed to update project: ${errorData['error'] ?? 'Unknown error'}';
        } catch (e) {
          errorMessage = 'Failed to update project: ${response.statusCode}';
        }
        _showErrorMessage(errorMessage);
      }
    } catch (e) {
      _showErrorMessage('Error updating project: $e');
    }
  }

  void _showDeleteProjectDialog(Map<String, dynamic> project) {
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete the project "${project['name']}"?'),
            const SizedBox(height: 16),
            const Text(
              'This action cannot be undone. All associated modules, tasks, and data will be permanently deleted.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Type "delete me" to confirm:'),
            const SizedBox(height: 8),
            TextField(
              controller: confirmController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'delete me',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (confirmController.text.trim() == 'delete me') {
                _deleteProject(project['id']);
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please type "delete me" to confirm deletion')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Project'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProject(int projectId) async {
    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.delete(
        Uri.parse('$apiBase/task/api/admin/projects/$projectId'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _projects.removeWhere((p) => p['id'] == projectId);
          if (_selectedProjectId == projectId) {
            _selectedProjectId = null;
            _modules.clear();
            _projectTeam.clear();
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Project deleted successfully'), backgroundColor: Colors.green),
          );
        }
      } else {
        String errorMessage = 'Failed to delete project';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = 'Failed to delete project: ${errorData['error'] ?? 'Unknown error'}';
        } catch (e) {
          errorMessage = 'Failed to delete project: ${response.statusCode}';
        }
        _showErrorMessage(errorMessage);
      }
    } catch (e) {
      _showErrorMessage('Error deleting project: $e');
    }
  }

  Widget _buildModulesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Add Module Button
          Row(
            children: [
              const Text(
                'Project Modules',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showAddModuleDialog,
                icon: const Icon(Icons.add),
                label: const Text('Create Module'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Modules List
          Expanded(
            child: _modules.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.view_module, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No modules found', style: TextStyle(fontSize: 18, color: Colors.grey)),
                        Text('Add modules to organize your project tasks', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _modules.length,
                    itemBuilder: (context, index) {
                      final module = _modules[index];
                      final completionPercentage = module['taskCount'] > 0
                          ? (module['completedTasks'] / module['taskCount']) * 100
                          : 0.0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.view_module,
                                    color: Colors.blue.shade700,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          module['name'],
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          module['description'] ?? 'No description',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (action) => _handleModuleAction(action, module),
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'view_tasks',
                                        child: Row(
                                          children: [
                                            Icon(Icons.task, size: 16),
                                            SizedBox(width: 8),
                                            Text('View Tasks'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 16),
                                            SizedBox(width: 8),
                                            Text('Edit Module'),
                                          ],
                                        ),
                                      ),

                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete, size: 16, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Delete Module'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Progress and stats
                              Row(
                                children: [
                                  Chip(
                                    label: Text(
                                      module['status'] ?? 'Active',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    backgroundColor: module['status'] == 'Active'
                                        ? Colors.green.shade100
                                        : Colors.orange.shade100,
                                  ),
                                  const SizedBox(width: 8),
                                  Chip(
                                    label: Text(
                                      module['category'] ?? 'General',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    backgroundColor: Colors.blue.shade100,
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${module['completedTasks']}/${module['taskCount']} tasks',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Progress bar
                              LinearProgressIndicator(
                                value: completionPercentage / 100,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  completionPercentage == 100 ? Colors.green : Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${completionPercentage.toStringAsFixed(1)}% complete',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 11,
                                ),
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

  void _handleModuleAction(String action, Map<String, dynamic> module) {
    switch (action) {
      case 'view_tasks':
        _viewModuleTasks(module);
        break;
      case 'edit':
        _editModule(module);
        break;

      case 'delete':
        _deleteModule(module);
        break;
    }
  }

  void _viewModuleTasks(Map<String, dynamic> module) {
    // Navigate to module tasks view
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Navigate to tasks for ${module['name']}')),
    );
    // TODO: Implement navigation to module tasks
  }

  void _editModule(Map<String, dynamic> module) {
    final nameController = TextEditingController(text: module['name']);
    final descriptionController = TextEditingController(text: module['description'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Module'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Module Name',
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                _updateModule(
                  module['id'],
                  nameController.text.trim(),
                  descriptionController.text.trim(),
                );
                Navigator.of(context).pop();
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateModule(int moduleId, String name, String description) async {
    if (_selectedProjectId == null) return;

    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.put(
        Uri.parse('$apiBase/task/api/projects/$_selectedProjectId/modules/$moduleId'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'description': description,
        }),
      );

      if (response.statusCode == 200) {
        // Update local state with the response from server
        final updatedModule = jsonDecode(response.body);
        setState(() {
          final index = _modules.indexWhere((m) => m['id'] == moduleId);
          if (index != -1) {
            _modules[index] = updatedModule;
          }
        });

        _showSuccessMessage('Module updated successfully');

        // Reload modules to ensure consistency
        _loadModules();
      } else {
        String errorMessage = 'Failed to update module';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = 'Failed to update module: ${errorData['error'] ?? 'Unknown error'}';
        } catch (e) {
          errorMessage = 'Failed to update module: ${response.statusCode}';
        }
        _showErrorMessage(errorMessage);
      }
    } catch (e) {
      _showErrorMessage('Error updating module: $e');
    }
  }



  void _deleteModule(Map<String, dynamic> module) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Module'),
        content: Text('Are you sure you want to permanently delete "${module['name']}"?\n\nThis will also delete all associated tasks and cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _modules.removeWhere((m) => m['id'] == module['id']);
              });
              Navigator.of(context).pop();
              _showSuccessMessage('Module deleted successfully');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Add Team Member Section
          Row(
            children: [
              const Text(
                'Project Team',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showAddTeamMemberDialog,
                icon: const Icon(Icons.person_add),
                label: const Text('Add Member'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Team Members List
          Expanded(
            child: _projectTeam.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No team members assigned', style: TextStyle(fontSize: 18, color: Colors.grey)),
                        Text('Add team members to collaborate on this project', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _projectTeam.length,
                    itemBuilder: (context, index) {
                      final teamMember = _projectTeam[index];

                      // Additional safety check: only show team members for current project
                      if (teamMember['projectId'] != null && teamMember['projectId'] != _selectedProjectId) {
                        return const SizedBox.shrink(); // Hide if not for current project
                      }

                      final user = _users.firstWhere(
                        (u) => u['id'] == teamMember['userId'],
                        orElse: () => {'name': 'Unknown User', 'email': 'unknown@example.com'},
                      );

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: Text(
                              user['name'][0].toUpperCase(),
                              style: TextStyle(color: Colors.blue.shade700),
                            ),
                          ),
                          title: Text(user['name']),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user['email']),
                              Text('Role: ${teamMember['role']}', style: const TextStyle(fontSize: 12)),
                              Text('Added: ${teamMember['assignedAt']}', style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          trailing: IconButton(
                            onPressed: () => _removeTeamMember(teamMember['userId']),
                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                            tooltip: 'Remove from project',
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

  void _showAddTeamMemberDialog() {
    int? selectedUserId;
    String selectedRole = 'Developer';
    final availableUsers = _users.where((u) => !_projectTeam.any((tm) => tm['userId'] == u['id'])).toList();

    if (availableUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All users are already assigned to this project')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Team Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'Select User',
                  border: OutlineInputBorder(),
                ),
                value: selectedUserId,
                items: availableUsers.map<DropdownMenuItem<int>>((user) {
                  return DropdownMenuItem<int>(
                    value: user['id'],
                    child: Text('${user['name']} (${user['email']})'),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() => selectedUserId = value);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                value: selectedRole,
                items: ['Project Manager', 'Team Lead', 'Developer', 'Designer', 'Tester'].map((role) {
                  return DropdownMenuItem(value: role, child: Text(role));
                }).toList(),
                onChanged: (value) {
                  setDialogState(() => selectedRole = value!);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedUserId != null) {
                  _addTeamMember(selectedUserId!, selectedRole);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addTeamMember(int userId, String role) async {
    if (_selectedProjectId == null) return;

    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.post(
        Uri.parse('$apiBase/task/api/admin/projects/$_selectedProjectId/team'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'role': role,
        }),
      );

      if (response.statusCode == 201) {
        _showSuccessMessage('Team member added successfully');
        _loadProjectTeam(); // Reload team to get updated data
      } else {
        String errorMessage = 'Failed to add team member';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = 'Failed to add team member: ${errorData['error'] ?? 'Unknown error'}';
        } catch (e) {
          errorMessage = 'Failed to add team member: ${response.statusCode}';
        }
        _showErrorMessage(errorMessage);
      }
    } catch (e) {
      _showErrorMessage('Error adding team member: $e');
    }
  }

  void _removeTeamMember(int userId) {
    final user = _users.firstWhere((u) => u['id'] == userId);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Team Member'),
        content: Text('Are you sure you want to remove ${user['name']} from this project?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _removeTeamMemberFromProject(userId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeTeamMemberFromProject(int userId) async {
    if (_selectedProjectId == null) return;

    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.delete(
        Uri.parse('$apiBase/task/api/admin/projects/$_selectedProjectId/team/$userId'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        _showSuccessMessage('Team member removed successfully');
        _loadProjectTeam(); // Reload team to get updated data
      } else {
        String errorMessage = 'Failed to remove team member';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = 'Failed to remove team member: ${errorData['error'] ?? 'Unknown error'}';
        } catch (e) {
          errorMessage = 'Failed to remove team member: ${response.statusCode}';
        }
        _showErrorMessage(errorMessage);
      }
    } catch (e) {
      _showErrorMessage('Error removing team member: $e');
    }
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.blue),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
