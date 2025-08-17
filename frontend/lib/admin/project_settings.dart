import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../main_layout.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3003');

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
        setState(() => _projects = jsonDecode(response.body));
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
        _showErrorMessage('Failed to create module');
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

    // Mock project team data
    setState(() => _projectTeam = [
      {'userId': 1, 'role': 'Project Manager', 'assignedAt': '2025-01-10'},
      {'userId': 2, 'role': 'Developer', 'assignedAt': '2025-01-12'},
    ]);
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
            child: Row(
              children: [
                const Icon(Icons.settings, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Project Settings',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                SizedBox(
                  width: 300,
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
                      setState(() => _selectedProjectId = value);
                      if (value != null) _loadModules();
                    },
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
                  _buildInfoCard('Status', project['status'] ?? 'Unknown', Icons.flag),
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

  void _updateProject(int projectId, String name, String description, String status, DateTime? startDate, DateTime? endDate) {
    setState(() {
      final projectIndex = _projects.indexWhere((p) => p['id'] == projectId);
      if (projectIndex != -1) {
        _projects[projectIndex] = {
          ..._projects[projectIndex],
          'name': name,
          'description': description,
          'status': status,
          'start_date': startDate?.toIso8601String().substring(0, 10),
          'end_date': endDate?.toIso8601String().substring(0, 10),
          'updated_at': DateTime.now().toIso8601String(),
        };
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Project updated successfully'), backgroundColor: Colors.green),
    );
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

  void _deleteProject(int projectId) {
    setState(() {
      _projects.removeWhere((p) => p['id'] == projectId);
      if (_selectedProjectId == projectId) {
        _selectedProjectId = null;
        _modules.clear();
        _projectTeam.clear();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Project deleted successfully'), backgroundColor: Colors.orange),
    );
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
                label: const Text('Add Module'),
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
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.view_module, color: Colors.blue),
                          title: Text(module['name']),
                          subtitle: Text(module['description'] ?? 'No description'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            // Navigate to module details
                          },
                        ),
                      );
                    },
                  ),
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

  void _addTeamMember(int userId, String role) {
    setState(() {
      _projectTeam.add({
        'userId': userId,
        'role': role,
        'assignedAt': DateTime.now().toIso8601String().substring(0, 10),
      });
    });

    final user = _users.firstWhere((u) => u['id'] == userId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${user['name']} added to project team')),
    );
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
            onPressed: () {
              setState(() {
                _projectTeam.removeWhere((tm) => tm['userId'] == userId);
              });
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${user['name']} removed from project team')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
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
