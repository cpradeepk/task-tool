import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/project.dart';
import '../services/api_service.dart';

class ProjectAssignmentModal extends StatefulWidget {
  final Project project;
  final VoidCallback? onAssignmentChanged;

  const ProjectAssignmentModal({
    Key? key,
    required this.project,
    this.onAssignmentChanged,
  }) : super(key: key);

  @override
  State<ProjectAssignmentModal> createState() => _ProjectAssignmentModalState();
}

class _ProjectAssignmentModalState extends State<ProjectAssignmentModal> {
  List<User> _allUsers = [];
  List<User> _selectedUsers = [];
  List<Map<String, dynamic>> _currentAssignments = [];
  String _selectedRole = 'MEMBER';
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isAssigning = false;
  String? _error;

  final List<String> _roles = ['OWNER', 'ADMIN', 'MEMBER', 'VIEWER'];
  final List<String> _roleDescriptions = [
    'Full project control and management',
    'Project administration and user management',
    'Standard project access and task management',
    'Read-only access to project information'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load all users and current assignments in parallel
      final results = await Future.wait([
        ApiService.getAllUsers(),
        ApiService.getProjectAssignments(widget.project.id),
      ]);

      final allUsers = (results[0] as List).map((json) => User.fromJson(json)).toList();
      final assignments = results[1] as List<Map<String, dynamic>>;

      setState(() {
        _allUsers = allUsers.where((user) => user.isActive).toList();
        _currentAssignments = assignments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  List<User> get _filteredUsers {
    final assignedUserIds = _currentAssignments.map((a) => a['user']['id']).toSet();
    
    return _allUsers.where((user) {
      // Filter out already assigned users
      if (assignedUserIds.contains(user.id)) return false;
      
      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return user.name.toLowerCase().contains(query) ||
               user.email.toLowerCase().contains(query);
      }
      
      return true;
    }).toList();
  }

  Future<void> _assignUsers() async {
    if (_selectedUsers.isEmpty) return;

    try {
      setState(() {
        _isAssigning = true;
        _error = null;
      });

      final userIds = _selectedUsers.map((user) => user.id).toList();
      
      await ApiService.assignUsersToProject(
        widget.project.id,
        userIds,
        _selectedRole,
      );

      // Reload assignments
      await _loadData();
      
      setState(() {
        _selectedUsers.clear();
        _isAssigning = false;
      });

      if (widget.onAssignmentChanged != null) {
        widget.onAssignmentChanged!();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully assigned ${userIds.length} users to project'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _error = 'Failed to assign users: $e';
        _isAssigning = false;
      });
    }
  }

  Future<void> _removeAssignment(String userId) async {
    try {
      await ApiService.removeUserFromProject(widget.project.id, userId);
      await _loadData();
      
      if (widget.onAssignmentChanged != null) {
        widget.onAssignmentChanged!();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User removed from project'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      setState(() {
        _error = 'Failed to remove user: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.group, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Project Assignments',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        widget.project.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red[600]),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: TextStyle(color: Colors.red[600]))),
                  ],
                ),
              ),

            if (_isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      const TabBar(
                        tabs: [
                          Tab(text: 'Current Assignments'),
                          Tab(text: 'Add Users'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildCurrentAssignmentsTab(),
                            _buildAddUsersTab(),
                          ],
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

  Widget _buildCurrentAssignmentsTab() {
    if (_currentAssignments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No users assigned to this project'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _currentAssignments.length,
      itemBuilder: (context, index) {
        final assignment = _currentAssignments[index];
        final user = assignment['user'];
        
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Text(user['name'][0].toUpperCase()),
            ),
            title: Text(user['name']),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['email']),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getRoleColor(assignment['role']),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    assignment['role'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            trailing: assignment['role'] != 'OWNER'
                ? IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => _removeAssignment(user['id']),
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildAddUsersTab() {
    return Column(
      children: [
        // Role selection and search
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Role selection
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: _roles.map((role) {
                  final index = _roles.indexOf(role);
                  return DropdownMenuItem(
                    value: role,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(role),
                        Text(
                          _roleDescriptions[index],
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Search field
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search users',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ],
          ),
        ),

        // User list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filteredUsers.length,
            itemBuilder: (context, index) {
              final user = _filteredUsers[index];
              final isSelected = _selectedUsers.contains(user);
              
              return Card(
                child: CheckboxListTile(
                  value: isSelected,
                  onChanged: (selected) {
                    setState(() {
                      if (selected == true) {
                        _selectedUsers.add(user);
                      } else {
                        _selectedUsers.remove(user);
                      }
                    });
                  },
                  secondary: CircleAvatar(
                    child: Text(user.name[0].toUpperCase()),
                  ),
                  title: Text(user.name),
                  subtitle: Text(user.email),
                ),
              );
            },
          ),
        ),

        // Assign button
        if (_selectedUsers.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isAssigning ? null : _assignUsers,
                child: _isAssigning
                    ? const CircularProgressIndicator()
                    : Text('Assign ${_selectedUsers.length} Users'),
              ),
            ),
          ),
      ],
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'OWNER':
        return Colors.purple;
      case 'ADMIN':
        return Colors.red;
      case 'MEMBER':
        return Colors.blue;
      case 'VIEWER':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}
