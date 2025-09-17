import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://task.amtariksha.com');

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<dynamic> _users = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<String?> _getJwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    
    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.get(
        Uri.parse('$apiBase/task/api/admin/users'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _users = jsonDecode(response.body);
          _errorMessage = null;
        });
      } else {
        setState(() => _errorMessage = 'Failed to load users');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Network error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddUserDialog() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const AddUserDialog(),
    );

    if (result != null) {
      await _createUser(result);
    }
  }

  Future<void> _createUser(Map<String, String> userData) async {
    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.post(
        Uri.parse('$apiBase/task/api/admin/users'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(userData),
      );

      if (response.statusCode == 201) {
        _showSuccessMessage('User created successfully');
        _loadUsers(); // Refresh the list
      } else {
        final error = jsonDecode(response.body);
        _showErrorMessage(error['error'] ?? 'Failed to create user');
      }
    } catch (e) {
      _showErrorMessage('Network error: ${e.toString()}');
    }
  }

  Future<void> _deleteUser(int userId, String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete user "$email"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE6920E)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.delete(
        Uri.parse('$apiBase/task/api/admin/users/$userId'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        _showSuccessMessage('User deleted successfully');
        _loadUsers(); // Refresh the list
      } else {
        final error = jsonDecode(response.body);
        _showErrorMessage(error['error'] ?? 'Failed to delete user');
      }
    } catch (e) {
      _showErrorMessage('Network error: ${e.toString()}');
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

  void _showEditUserDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => EditUserDialog(
        user: user,
        onUserUpdated: () {
          _loadUsers(); // Refresh the user list
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Add User button
            Row(
              children: [
                const Icon(Icons.people, color: Color(0xFFFFA301), size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'User Management',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddUserDialog,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add User'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFA301),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Error message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECB3),
                  border: Border.all(color: const Color(0xFFE6920E)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Color(0xFFE6920E)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFE6920E)))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Users list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _users.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('No users found', style: TextStyle(fontSize: 18, color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _users.length,
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFFFFA301),
                                  child: Text(
                                    (user['email'] as String).substring(0, 1).toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(user['email'] ?? 'Unknown'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('ID: ${user['id']}'),
                                    Text('Created: ${user['created_at'] ?? 'Unknown'}'),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () => _showEditUserDialog(user),
                                      icon: const Icon(Icons.edit, color: Color(0xFFFFA301)),
                                      tooltip: 'Edit User',
                                    ),
                                    IconButton(
                                      onPressed: () => _deleteUser(user['id'], user['email']),
                                      icon: const Icon(Icons.delete, color: Color(0xFFE6920E)),
                                      tooltip: 'Delete User',
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

class EditUserDialog extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onUserUpdated;

  const EditUserDialog({
    super.key,
    required this.user,
    required this.onUserUpdated,
  });

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _emailController;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _departmentController;
  late TextEditingController _jobTitleController;
  late TextEditingController _bioController;
  late TextEditingController _newPinController;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.user['email'] ?? '');
    _firstNameController = TextEditingController(text: widget.user['first_name'] ?? '');
    _lastNameController = TextEditingController(text: widget.user['last_name'] ?? '');
    _phoneController = TextEditingController(text: widget.user['phone'] ?? '');
    _departmentController = TextEditingController(text: widget.user['department'] ?? '');
    _jobTitleController = TextEditingController(text: widget.user['job_title'] ?? '');
    _bioController = TextEditingController(text: widget.user['bio'] ?? '');
    _newPinController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _jobTitleController.dispose();
    _bioController.dispose();
    _newPinController.dispose();
    super.dispose();
  }

  Future<void> _updateUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');

      if (jwt == null) {
        throw Exception('No authentication token found');
      }

      final updateData = <String, dynamic>{};

      // Only include fields that have changed or are not empty
      if (_emailController.text.trim() != (widget.user['email'] ?? '')) {
        updateData['email'] = _emailController.text.trim();
      }

      if (_newPinController.text.trim().isNotEmpty) {
        updateData['new_pin'] = _newPinController.text.trim();
      }

      // Add other fields for a more comprehensive update endpoint
      updateData['first_name'] = _firstNameController.text.trim();
      updateData['last_name'] = _lastNameController.text.trim();
      updateData['phone'] = _phoneController.text.trim();
      updateData['department'] = _departmentController.text.trim();
      updateData['job_title'] = _jobTitleController.text.trim();
      updateData['bio'] = _bioController.text.trim();

      const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://task.amtariksha.com');

      final response = await http.put(
        Uri.parse('$apiBase/task/api/admin/users/${widget.user['id']}'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(updateData),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User updated successfully'),
              backgroundColor: Color(0xFFFFA301),
            ),
          );
          Navigator.of(context).pop();
          widget.onUserUpdated();
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to update user');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.edit, color: Color(0xFFFFA301)),
          const SizedBox(width: 8),
          Text('Edit User: ${widget.user['email']}'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFECB3),
                      border: Border.all(color: const Color(0xFFE6920E)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Color(0xFFE6920E)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Color(0xFFE6920E)),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Email field
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // First Name and Last Name
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'First Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Last Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Phone
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Department and Job Title
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _departmentController,
                        decoration: const InputDecoration(
                          labelText: 'Department',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _jobTitleController,
                        decoration: const InputDecoration(
                          labelText: 'Job Title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Bio
                TextFormField(
                  controller: _bioController,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // New PIN (optional)
                TextFormField(
                  controller: _newPinController,
                  decoration: const InputDecoration(
                    labelText: 'New PIN (optional)',
                    border: OutlineInputBorder(),
                    helperText: 'Leave empty to keep current PIN',
                  ),
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      if (!RegExp(r'^\d{4,6}$').hasMatch(value)) {
                        return 'PIN must be 4-6 digits';
                      }
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateUser,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFA301),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Update User'),
        ),
      ],
    );
  }
}

class AddUserDialog extends StatefulWidget {
  const AddUserDialog({super.key});

  @override
  State<AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<AddUserDialog> {
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  String _authType = 'pin'; // 'pin' or 'oauth'

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New User'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              value: _authType,
              decoration: const InputDecoration(
                labelText: 'Authentication Type',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.security),
              ),
              items: const [
                DropdownMenuItem(value: 'pin', child: Text('PIN Authentication')),
                DropdownMenuItem(value: 'oauth', child: Text('OAuth (Google)')),
              ],
              onChanged: (value) => setState(() => _authType = value!),
            ),
            
            if (_authType == 'pin') ...[
              const SizedBox(height: 16),
              TextField(
                controller: _pinController,
                decoration: const InputDecoration(
                  labelText: 'Initial PIN (4-6 digits)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                  helperText: 'User can change this after first login',
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: true,
              ),
            ],
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
            if (_emailController.text.isEmpty) return;
            if (_authType == 'pin' && _pinController.text.isEmpty) return;
            
            Navigator.of(context).pop({
              'email': _emailController.text,
              'auth_type': _authType,
              if (_authType == 'pin') 'pin': _pinController.text,
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFA301),
            foregroundColor: Colors.white,
          ),
          child: const Text('Add User'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _pinController.dispose();
    super.dispose();
  }
}
