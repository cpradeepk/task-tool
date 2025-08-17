import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../main_layout.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3003');

class RoleManageScreen extends StatefulWidget {
  const RoleManageScreen({super.key});

  @override
  State<RoleManageScreen> createState() => _RoleManageScreenState();
}

class _RoleManageScreenState extends State<RoleManageScreen> {
  List<dynamic> _roles = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<String?> _getJwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  Future<void> _loadRoles() async {
    setState(() => _isLoading = true);

    // Load mock roles data
    _roles = [
      {
        'id': '1',
        'name': 'Admin',
        'description': 'Full system access with all permissions',
        'permissions': ['*'],
        'userCount': 2,
        'createdAt': '2025-01-10',
        'isSystem': true,
      },
      {
        'id': '2',
        'name': 'Project Manager',
        'description': 'Project management and team coordination',
        'permissions': ['projects.*', 'tasks.*', 'reports.read', 'users.read'],
        'userCount': 3,
        'createdAt': '2025-01-10',
        'isSystem': true,
      },
      {
        'id': '3',
        'name': 'Team Lead',
        'description': 'Team leadership and task assignment',
        'permissions': ['tasks.*', 'projects.read', 'users.read'],
        'userCount': 5,
        'createdAt': '2025-01-10',
        'isSystem': false,
      },
      {
        'id': '4',
        'name': 'Developer',
        'description': 'Development tasks and code management',
        'permissions': ['tasks.read', 'tasks.update', 'projects.read'],
        'userCount': 8,
        'createdAt': '2025-01-10',
        'isSystem': false,
      },
      {
        'id': '5',
        'name': 'Designer',
        'description': 'Design tasks and creative work',
        'permissions': ['tasks.read', 'tasks.update', 'projects.read'],
        'userCount': 3,
        'createdAt': '2025-01-10',
        'isSystem': false,
      },
      {
        'id': '6',
        'name': 'Viewer',
        'description': 'Read-only access to projects and tasks',
        'permissions': ['tasks.read', 'projects.read'],
        'userCount': 12,
        'createdAt': '2025-01-10',
        'isSystem': false,
      },
    ];

    setState(() => _isLoading = false);
  }

  void _showCreateRoleDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    List<String> selectedPermissions = [];

    final availablePermissions = [
      'projects.create',
      'projects.read',
      'projects.update',
      'projects.delete',
      'tasks.create',
      'tasks.read',
      'tasks.update',
      'tasks.delete',
      'users.create',
      'users.read',
      'users.update',
      'users.delete',
      'reports.read',
      'reports.create',
      'admin.access',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New Role'),
          content: SizedBox(
            width: 500,
            height: 400,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Role Name *',
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
                  const Text(
                    'Permissions:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...availablePermissions.map((permission) {
                    return CheckboxListTile(
                      title: Text(permission),
                      value: selectedPermissions.contains(permission),
                      onChanged: (value) {
                        setDialogState(() {
                          if (value == true) {
                            selectedPermissions.add(permission);
                          } else {
                            selectedPermissions.remove(permission);
                          }
                        });
                      },
                    );
                  }),
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
                  _createRole(
                    nameController.text.trim(),
                    descriptionController.text.trim(),
                    selectedPermissions,
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

  void _createRole(String name, String description, List<String> permissions) {
    setState(() {
      _roles.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': name,
        'description': description,
        'permissions': permissions,
        'userCount': 0,
        'createdAt': DateTime.now().toIso8601String().substring(0, 10),
        'isSystem': false,
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Role created successfully'), backgroundColor: Colors.green),
    );
  }

  void _editRole(Map<String, dynamic> role) {
    if (role['isSystem'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('System roles cannot be edited')),
      );
      return;
    }

    // TODO: Implement edit role dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Edit Role: ${role['name']} - Coming Soon')),
    );
  }

  void _deleteRole(String roleId) {
    final role = _roles.firstWhere((r) => r['id'] == roleId);
    
    if (role['isSystem'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('System roles cannot be deleted')),
      );
      return;
    }

    if (role['userCount'] > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete role with assigned users')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Role'),
        content: Text('Are you sure you want to delete the role "${role['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _roles.removeWhere((r) => r['id'] == roleId);
              });
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Role deleted successfully'), backgroundColor: Colors.orange),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Role Management',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.security, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Role Management',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _showCreateRoleDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Role'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _loadRoles,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Roles List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _roles.length,
                      itemBuilder: (context, index) {
                        final role = _roles[index];
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
                                      role['isSystem'] ? Icons.lock : Icons.security,
                                      color: role['isSystem'] ? Colors.orange : Colors.blue,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        role['name'],
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (role['isSystem'])
                                      const Chip(
                                        label: Text('System', style: TextStyle(fontSize: 10)),
                                        backgroundColor: Colors.orange,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  role['description'],
                                  style: TextStyle(color: Colors.grey.shade600),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(Icons.people, size: 16, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${role['userCount']} users',
                                      style: TextStyle(color: Colors.grey.shade600),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${role['permissions'].length} permissions',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      onPressed: () => _editRole(role),
                                      icon: const Icon(Icons.edit, size: 20),
                                      tooltip: 'Edit Role',
                                    ),
                                    IconButton(
                                      onPressed: () => _deleteRole(role['id']),
                                      icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                      tooltip: 'Delete Role',
                                    ),
                                  ],
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
