import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';


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

    final jwt = await _getJwt();
    if (jwt == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Load users, roles, and user role assignments in parallel
      final futures = await Future.wait([
        http.get(Uri.parse('$apiBase/task/api/users'), headers: {'Authorization': 'Bearer $jwt'}),
        http.get(Uri.parse('$apiBase/task/api/roles'), headers: {'Authorization': 'Bearer $jwt'}),
        http.get(Uri.parse('$apiBase/task/api/user-roles'), headers: {'Authorization': 'Bearer $jwt'}),
      ]);

      final usersResponse = futures[0];
      final rolesResponse = futures[1];
      final userRolesResponse = futures[2];

      if (usersResponse.statusCode == 200) {
        final usersData = jsonDecode(usersResponse.body) as List;
        _users = usersData.map((user) => {
          'id': user['id'].toString(),
          'email': user['email'],
          'name': user['name'] ?? user['display_name'] ?? user['email'],
        }).toList();
      }

      if (rolesResponse.statusCode == 200) {
        final rolesData = jsonDecode(rolesResponse.body) as List;
        _roles = rolesData.map((role) => {
          'id': role['id'].toString(),
          'name': role['name'],
          'description': role['description'] ?? '',
        }).toList();
      }

      if (userRolesResponse.statusCode == 200) {
        final userRolesData = jsonDecode(userRolesResponse.body) as List;
        _userRoles = userRolesData.map((userRole) => {
          'userId': userRole['user_id'].toString(),
          'roleId': userRole['role_id'].toString(),
          'assignedAt': userRole['assigned_at']?.toString().substring(0, 10) ?? '',
          'assignedBy': 'admin', // TODO: Get actual assigner
          'userEmail': userRole['user_email'],
          'userName': userRole['user_name'],
          'roleName': userRole['role_name'],
        }).toList();
      }

    } catch (e) {
      print('Error loading data: $e');
      _showErrorMessage('Error loading data: $e');
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

    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.post(
        Uri.parse('$apiBase/task/api/user-roles'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': int.parse(_selectedUserId!),
          'role_id': int.parse(_selectedRoleId!),
        }),
      );

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Role assigned successfully'), backgroundColor: Color(0xFFFFA301)),
          );
        }

        // Reset selections and reload data
        setState(() {
          _selectedUserId = null;
          _selectedRoleId = null;
        });
        _loadData();
      } else {
        String errorMessage = 'Failed to assign role';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = 'Failed to assign role: ${errorData['error'] ?? 'Unknown error'}';
        } catch (e) {
          errorMessage = 'Failed to assign role: ${response.statusCode}';
        }
        _showErrorMessage(errorMessage);
      }
    } catch (e) {
      _showErrorMessage('Error assigning role: $e');
    }
  }

  Future<void> _removeRole(String userId, String roleId) async {
    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.delete(
        Uri.parse('$apiBase/task/api/user-roles/$userId/$roleId'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Role removed successfully'), backgroundColor: Colors.orange),
          );
        }
        _loadData(); // Reload data to get updated assignments
      } else {
        String errorMessage = 'Failed to remove role';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = 'Failed to remove role: ${errorData['error'] ?? 'Unknown error'}';
        } catch (e) {
          errorMessage = 'Failed to remove role: ${response.statusCode}';
        }
        _showErrorMessage(errorMessage);
      }
    } catch (e) {
      _showErrorMessage('Error removing role: $e');
    }
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
    return Padding(
      padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.assignment_ind, color: Color(0xFFFFA301), size: 28),
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
                    backgroundColor: const Color(0xFFFFA301),
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
                    color: Colors.black.withOpacity(0.05),
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
                          backgroundColor: const Color(0xFFFFA301),
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
                      color: Colors.black.withOpacity(0.05),
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
                        color: const Color(0xFFFFECB3),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.people, color: Color(0xFFFFA301)),
                          const SizedBox(width: 8),
                          const Text(
                            'Current Role Assignments',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Text(
                            '${_users.length} users',
                            style: TextStyle(color: Color(0xFFFFA301)),
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
                                      backgroundColor: const Color(0xFFFFECB3),
                                      child: Text(
                                        user['name'][0].toUpperCase(),
                                        style: const TextStyle(color: Color(0xFFFFA301)),
                                      ),
                                    ),
                                    title: Text(user['name']),
                                    subtitle: Text(user['email']),
                                    trailing: Chip(
                                      label: Text('${userRoles.length} roles'),
                                      backgroundColor: const Color(0xFFFFECB3),
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
                                              leading: const Icon(Icons.security, color: Color(0xFFFFA301)),
                                              title: Text(roleName),
                                              trailing: IconButton(
                                                onPressed: () => _removeRole(user['id'], roleId),
                                                icon: const Icon(Icons.remove_circle, color: Color(0xFFE6920E)),
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
    );
  }
}
