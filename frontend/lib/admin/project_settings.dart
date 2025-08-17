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
        }
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
              color: Colors.black.withOpacity(0.05),
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
              Text(
                project['name'],
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Team Management', style: TextStyle(fontSize: 18, color: Colors.grey)),
            Text('Coming soon - Assign team members to projects', style: TextStyle(color: Colors.grey)),
          ],
        ),
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
