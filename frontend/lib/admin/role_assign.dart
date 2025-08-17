import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../main_layout.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3003');

class RoleAssignScreen extends StatefulWidget {
  const RoleAssignScreen({super.key});

  @override
  State<RoleAssignScreen> createState() => _RoleAssignScreenState();
}

class _RoleAssignScreenState extends State<RoleAssignScreen> {
  List<dynamic> _users = [];
  List<dynamic> _roles = [];
  List<dynamic> _userRoles = [];
  bool _isLoading = false;
  String? _selectedUserId;
  String? _selectedRoleId;

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

    // Load mock data for now
    _users = [
      {'id': '1', 'email': 'john@example.com', 'name': 'John Doe'},
      {'id': '2', 'email': 'jane@example.com', 'name': 'Jane Smith'},
      {'id': '3', 'email': 'mike@example.com', 'name': 'Mike Johnson'},
      {'id': '4', 'email': 'sarah@example.com', 'name': 'Sarah Wilson'},
    ];

    _roles = [
      {'id': '1', 'name': 'Admin', 'description': 'Full system access'},
      {'id': '2', 'name': 'Project Manager', 'description': 'Project management access'},
      {'id': '3', 'name': 'Team Lead', 'description': 'Team leadership access'},
      {'id': '4', 'name': 'Developer', 'description': 'Development access'},
      {'id': '5', 'name': 'Designer', 'description': 'Design access'},
      {'id': '6', 'name': 'Viewer', 'description': 'Read-only access'},
    ];

    _userRoles = [
      {'userId': '1', 'roleId': '1', 'assignedAt': '2025-01-15', 'assignedBy': 'admin'},
      {'userId': '2', 'roleId': '2', 'assignedAt': '2025-01-15', 'assignedBy': 'admin'},
      {'userId': '3', 'roleId': '4', 'assignedAt': '2025-01-15', 'assignedBy': 'admin'},
      {'userId': '4', 'roleId': '5', 'assignedAt': '2025-01-15', 'assignedBy': 'admin'},
    ];

    setState(() => _isLoading = false);
  }

  Future<void> _assignRole() async {
    if (_selectedUserId == null || _selectedRoleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both user and role')),
      );
      return;
    }

    // Check if user already has this role
    final existingAssignment = _userRoles.firstWhere(
      (ur) => ur['userId'] == _selectedUserId && ur['roleId'] == _selectedRoleId,
      orElse: () => null,
    );

    if (existingAssignment != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User already has this role assigned')),
      );
      return;
    }

    // Add new role assignment
    setState(() {
      _userRoles.add({
        'userId': _selectedUserId,
        'roleId': _selectedRoleId,
        'assignedAt': DateTime.now().toIso8601String().substring(0, 10),
        'assignedBy': 'admin',
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Role assigned successfully'), backgroundColor: Colors.green),
    );

    // Reset selections
    setState(() {
      _selectedUserId = null;
      _selectedRoleId = null;
    });
  }

  Future<void> _removeRole(String userId, String roleId) async {
    setState(() {
      _userRoles.removeWhere((ur) => ur['userId'] == userId && ur['roleId'] == roleId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Role removed successfully'), backgroundColor: Colors.orange),
    );
  }

  String _getUserName(String userId) {
    final user = _users.firstWhere((u) => u['id'] == userId, orElse: () => {'name': 'Unknown User'});
    return user['name'];
  }

  String _getRoleName(String roleId) {
    final role = _roles.firstWhere((r) => r['id'] == roleId, orElse: () => {'name': 'Unknown Role'});
    return role['name'];
  }

  List<String> _getUserRoles(String userId) {
    return _userRoles
        .where((ur) => ur['userId'] == userId)
        .map((ur) => _getRoleName(ur['roleId']))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Role Assignment',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.assignment_ind, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Role Assignment',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _loadData,
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

            // Assignment Form
            Container(
              padding: const EdgeInsets.all(24),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Assign Role to User',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Select User',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          value: _selectedUserId,
                          items: _users.map<DropdownMenuItem<String>>((user) {
                            return DropdownMenuItem<String>(
                              value: user['id'],
                              child: Text('${user['name']} (${user['email']})'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedUserId = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Select Role',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.security),
                          ),
                          value: _selectedRoleId,
                          items: _roles.map<DropdownMenuItem<String>>((role) {
                            return DropdownMenuItem<String>(
                              value: role['id'],
                              child: Text('${role['name']} - ${role['description']}'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedRoleId = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: _assignRole,
                        icon: const Icon(Icons.add),
                        label: const Text('Assign'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Current Assignments
            Expanded(
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
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.people, color: Colors.blue),
                          const SizedBox(width: 8),
                          const Text(
                            'Current Role Assignments',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Text(
                            '${_users.length} users',
                            style: TextStyle(color: Colors.blue.shade600),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _users.length,
                              itemBuilder: (context, index) {
                                final user = _users[index];
                                final userRoles = _getUserRoles(user['id']);
                                
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ExpansionTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blue.shade100,
                                      child: Text(
                                        user['name'][0].toUpperCase(),
                                        style: TextStyle(color: Colors.blue.shade700),
                                      ),
                                    ),
                                    title: Text(user['name']),
                                    subtitle: Text(user['email']),
                                    trailing: Chip(
                                      label: Text('${userRoles.length} roles'),
                                      backgroundColor: Colors.blue.shade50,
                                    ),
                                    children: userRoles.isEmpty
                                        ? [
                                            const Padding(
                                              padding: EdgeInsets.all(16),
                                              child: Text('No roles assigned'),
                                            ),
                                          ]
                                        : userRoles.map((roleName) {
                                            final roleId = _roles.firstWhere(
                                              (r) => r['name'] == roleName,
                                              orElse: () => {'id': ''},
                                            )['id'];
                                            
                                            return ListTile(
                                              leading: const Icon(Icons.security, color: Colors.green),
                                              title: Text(roleName),
                                              trailing: IconButton(
                                                onPressed: () => _removeRole(user['id'], roleId),
                                                icon: const Icon(Icons.remove_circle, color: Colors.red),
                                                tooltip: 'Remove Role',
                                              ),
                                            );
                                          }).toList(),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
