import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';


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

    final jwt = await _getJwt();
    if (jwt == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$apiBase/task/api/roles'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        final rolesData = jsonDecode(response.body) as List;
        setState(() {
          _roles = rolesData.map((role) => {
            'id': role['id'].toString(),
            'name': role['name'],
            'description': role['description'] ?? '',
            'permissions': role['permissions'] ?? [],
            'userCount': role['userCount'] ?? 0,
            'createdAt': role['created_at']?.toString().substring(0, 10) ?? '',
            'isSystem': role['isSystem'] ?? false,
          }).toList();
        });
      } else {
        print('Failed to load roles: ${response.statusCode} - ${response.body}');
        _showErrorMessage('Failed to load roles');
      }
    } catch (e) {
      print('Error loading roles: $e');
      _showErrorMessage('Error loading roles: $e');
    }

    setState(() => _isLoading = false);
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE6920E),
      ),
    );
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

  Future<void> _createRole(String name, String description, List<String> permissions) async {
    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.post(
        Uri.parse('$apiBase/task/api/roles'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'description': description,
          'permissions': permissions,
        }),
      );

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Role created successfully'), backgroundColor: Color(0xFFFFA301)),
          );
        }
        _loadRoles(); // Reload roles to get updated data
      } else {
        String errorMessage = 'Failed to create role';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = 'Failed to create role: ${errorData['error'] ?? 'Unknown error'}';
        } catch (e) {
          errorMessage = 'Failed to create role: ${response.statusCode}';
        }
        _showErrorMessage(errorMessage);
      }
    } catch (e) {
      _showErrorMessage('Error creating role: $e');
    }
  }

  void _editRole(Map<String, dynamic> role) {
    if (role['isSystem'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('System roles cannot be edited')),
      );
      return;
    }

    _showEditRoleDialog(role);
  }

  void _showEditRoleDialog(Map<String, dynamic> role) {
    final nameController = TextEditingController(text: role['name']);
    final descriptionController = TextEditingController(text: role['description']);
    final permissions = List<String>.from(role['permissions'] ?? []);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Role'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Role Name',
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
              const Text('Permissions (Coming Soon)', style: TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Role name is required')),
                );
                return;
              }

              Navigator.of(context).pop();
              await _updateRole(
                role['id'],
                nameController.text.trim(),
                descriptionController.text.trim(),
                permissions,
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateRole(String roleId, String name, String description, List<String> permissions) async {
    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.put(
        Uri.parse('$apiBase/task/api/roles/$roleId'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'description': description,
          'permissions': permissions,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Role updated successfully'), backgroundColor: Color(0xFFFFA301)),
          );
        }
        _loadRoles(); // Reload roles to get updated data
      } else {
        String errorMessage = 'Failed to update role';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = 'Failed to update role: ${errorData['error'] ?? 'Unknown error'}';
        } catch (e) {
          errorMessage = 'Failed to update role: ${response.statusCode}';
        }
        _showErrorMessage(errorMessage);
      }
    } catch (e) {
      _showErrorMessage('Error updating role: $e');
    }
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
            onPressed: () async {
              Navigator.of(context).pop();
              await _performDeleteRole(roleId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE6920E)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteRole(String roleId) async {
    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.delete(
        Uri.parse('$apiBase/task/api/roles/$roleId'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Role deleted successfully'), backgroundColor: Colors.orange),
          );
        }
        _loadRoles(); // Reload roles to get updated data
      } else {
        String errorMessage = 'Failed to delete role';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = 'Failed to delete role: ${errorData['error'] ?? 'Unknown error'}';
        } catch (e) {
          errorMessage = 'Failed to delete role: ${response.statusCode}';
        }
        _showErrorMessage(errorMessage);
      }
    } catch (e) {
      _showErrorMessage('Error deleting role: $e');
    }
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
                const Icon(Icons.security, color: Color(0xFFFFA301), size: 28),
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
                    backgroundColor: const Color(0xFFFFA301),
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _loadRoles,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFA301),
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
                                      color: role['isSystem'] ? const Color(0xFFE6920E) : const Color(0xFFFFA301),
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
                                      icon: const Icon(Icons.delete, size: 20, color: Color(0xFFE6920E)),
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
    );
  }
}
