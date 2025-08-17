import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'constants/task_constants.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3003');

class SidebarNavigation extends StatefulWidget {
  final bool isCollapsed;
  final VoidCallback onToggle;
  
  const SidebarNavigation({
    super.key, 
    required this.isCollapsed, 
    required this.onToggle
  });

  @override
  State<SidebarNavigation> createState() => _SidebarNavigationState();
}

class _SidebarNavigationState extends State<SidebarNavigation> {
  List<dynamic> _projects = [];
  Map<int, List<dynamic>> _projectModules = {};
  Map<int, List<dynamic>> _moduleTasks = {};
  Set<int> _expandedProjects = {};
  Set<int> _expandedModules = {};
  bool _isAdmin = false;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadProjects();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAdmin = prefs.getBool('isAdmin') ?? false;
      _userEmail = prefs.getString('email');
    });
  }

  Future<void> _loadProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString('jwt');
    if (jwt == null) return;

    try {
      final response = await http.get(
        Uri.parse('$apiBase/task/api/projects'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        final projects = jsonDecode(response.body) as List;
        setState(() => _projects = projects);
        
        // Load modules for each project
        for (final project in projects) {
          _loadProjectModules(project['id']);
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadProjectModules(int projectId) async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString('jwt');
    if (jwt == null) return;

    try {
      final response = await http.get(
        Uri.parse('$apiBase/task/api/projects/$projectId/modules'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        final modules = jsonDecode(response.body) as List;
        setState(() => _projectModules[projectId] = modules);

        // Load tasks for each module
        for (final module in modules) {
          _loadTasksForModule(module['id']);
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadTasksForModule(int moduleId) async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString('jwt');
    if (jwt == null) return;

    try {
      // Mock tasks for development
      final mockTasks = [
        {
          'id': 1,
          'task_id': 'JSR-20250117-001',
          'title': 'Implement authentication',
          'status': 'In Progress',
          'priority': 'Important & Urgent',
          'assigned_to': 'John Doe',
        },
        {
          'id': 2,
          'task_id': 'JSR-20250117-002',
          'title': 'Design user interface',
          'status': 'Open',
          'priority': 'Important & Not Urgent',
          'assigned_to': 'Jane Smith',
        },
      ];

      setState(() => _moduleTasks[moduleId] = mockTasks);
    } catch (e) {
      // Handle error silently
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.isCollapsed ? 60 : 280,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.blue,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 2,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onToggle,
                  icon: const Icon(Icons.menu, color: Colors.white),
                ),
                if (!widget.isCollapsed) ...[
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Task Tool',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildNavItem(
                  icon: Icons.dashboard,
                  title: 'Dashboard',
                  route: '/dashboard',
                ),
                
                // Projects Section
                _buildExpandableSection(
                  icon: Icons.folder,
                  title: 'Projects',
                  children: _projects.map((project) => _buildProjectItem(project)).toList(),
                ),
                
                _buildNavItem(
                  icon: Icons.timeline,
                  title: 'PERT',
                  route: '/pert',
                ),
                
                _buildNavItem(
                  icon: Icons.calendar_today,
                  title: 'Calendar',
                  route: '/calendar',
                ),
                
                _buildNavItem(
                  icon: Icons.chat,
                  title: 'Chat',
                  route: '/chat',
                ),
                
                _buildNavItem(
                  icon: Icons.notifications,
                  title: 'Alerts',
                  route: '/alerts',
                ),
                
                // Admin Section (only for admins)
                if (_isAdmin) ...[
                  const Divider(),
                  _buildExpandableSection(
                    icon: Icons.admin_panel_settings,
                    title: 'Admin',
                    children: [
                      _buildSubSection('Reporting', Icons.bar_chart, [
                        _buildNavItem(
                          icon: Icons.today,
                          title: 'Daily Summary',
                          route: '/admin/reporting/daily-summary',
                          isSubItem: true,
                        ),
                        _buildExpandableSection(
                          icon: Icons.assignment,
                          title: 'JSR (Job Status Report)',
                          isSubItem: true,
                          children: [
                            _buildNavItem(
                              icon: Icons.schedule,
                              title: 'Planned',
                              route: '/admin/reporting/jsr/planned',
                              isSubItem: true,
                            ),
                            _buildNavItem(
                              icon: Icons.check_circle,
                              title: 'Completed',
                              route: '/admin/reporting/jsr/completed',
                              isSubItem: true,
                            ),
                          ],
                        ),
                      ]),
                      _buildSubSection('Project Management', Icons.folder_special, [
                        _buildNavItem(
                          icon: Icons.add,
                          title: 'Create Project',
                          route: '/admin/projects/create',
                          isSubItem: true,
                        ),
                        _buildNavItem(
                          icon: Icons.settings,
                          title: 'Edit Project Settings',
                          route: '/admin/projects/settings',
                          isSubItem: true,
                        ),
                      ]),
                      _buildSubSection('User Management', Icons.people, [
                        _buildNavItem(
                          icon: Icons.people,
                          title: 'Manage Users',
                          route: '/admin/users/manage',
                          isSubItem: true,
                        ),
                      ]),
                      _buildSubSection('Role & Access Control', Icons.security, [
                        _buildNavItem(
                          icon: Icons.assignment_ind,
                          title: 'Assign User to Role',
                          route: '/admin/roles/assign',
                          isSubItem: true,
                        ),
                        _buildNavItem(
                          icon: Icons.edit_attributes,
                          title: 'Add/Edit Role and Access',
                          route: '/admin/roles/manage',
                          isSubItem: true,
                        ),
                      ]),
                      _buildNavItem(
                        icon: Icons.edit_note,
                        title: 'Edit Master Data Fields',
                        route: '/admin/master-data',
                        isSubItem: true,
                      ),
                    ],
                  ),
                ],
                
                // Personal Section
                const Divider(),
                _buildExpandableSection(
                  icon: Icons.person,
                  title: 'Personal',
                  children: [
                    _buildNavItem(
                      icon: Icons.note,
                      title: 'Notes',
                      route: '/personal/notes',
                      isSubItem: true,
                    ),
                    _buildNavItem(
                      icon: Icons.palette,
                      title: 'Customize',
                      route: '/personal/customize',
                      isSubItem: true,
                    ),
                    _buildNavItem(
                      icon: Icons.edit,
                      title: 'Edit Profile',
                      route: '/personal/profile',
                      isSubItem: true,
                    ),
                    _buildNavItem(
                      icon: Icons.notifications_active,
                      title: 'Configure Notifications',
                      route: '/personal/notifications',
                      isSubItem: true,
                    ),
                  ],
                ),
                
                _buildNavItem(
                  icon: Icons.people_outline,
                  title: 'Other People\'s Tasks',
                  route: '/others-tasks',
                ),
              ],
            ),
          ),
          
          // User Info Footer
          if (!widget.isCollapsed) ...[
            const Divider(),
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Text(
                      (_userEmail?.substring(0, 1).toUpperCase()) ?? 'U',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _userEmail ?? 'User',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _isAdmin ? 'Administrator' : 'User',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String title,
    required String route,
    bool isSubItem = false,
  }) {
    final isSelected = GoRouter.of(context).routerDelegate.currentConfiguration.uri.path == route;
    
    return Container(
      margin: EdgeInsets.only(
        left: isSubItem ? 32 : 8,
        right: 8,
        bottom: 2,
      ),
      child: ListTile(
        dense: true,
        leading: widget.isCollapsed 
          ? null 
          : Icon(
              icon, 
              size: isSubItem ? 18 : 20,
              color: isSelected ? Colors.blue : Colors.grey.shade600,
            ),
        title: widget.isCollapsed 
          ? Icon(icon, color: isSelected ? Colors.blue : Colors.grey.shade600)
          : Text(
              title,
              style: TextStyle(
                fontSize: isSubItem ? 13 : 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.blue : Colors.grey.shade800,
              ),
            ),
        selected: isSelected,
        selectedTileColor: Colors.blue.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: () => context.go(route),
      ),
    );
  }

  Widget _buildExpandableSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
    bool isSubItem = false,
  }) {
    if (widget.isCollapsed) {
      return _buildNavItem(icon: icon, title: title, route: '/${title.toLowerCase()}');
    }

    return ExpansionTile(
      leading: Icon(icon, size: isSubItem ? 18 : 20),
      title: Text(
        title,
        style: TextStyle(
          fontSize: isSubItem ? 13 : 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      children: children,
    );
  }

  Widget _buildSubSection(String title, IconData icon, List<Widget> children) {
    return ExpansionTile(
      leading: Icon(icon, size: 18),
      title: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      children: children,
    );
  }

  Widget _buildProjectItem(Map<String, dynamic> project) {
    final projectId = project['id'] as int;
    final modules = _projectModules[projectId] ?? [];
    final isExpanded = _expandedProjects.contains(projectId);

    return ExpansionTile(
      leading: Icon(
        isExpanded ? Icons.folder_open : Icons.folder,
        size: 18,
        color: Colors.blue,
      ),
      title: Text(
        project['name'] ?? 'Unnamed Project',
        style: const TextStyle(fontSize: 13),
      ),
      onExpansionChanged: (expanded) {
        setState(() {
          if (expanded) {
            _expandedProjects.add(projectId);
          } else {
            _expandedProjects.remove(projectId);
          }
        });
      },
      children: modules.map<Widget>((module) {
        final moduleId = module['id'] as int;
        final tasks = _moduleTasks[moduleId] ?? [];
        final isModuleExpanded = _expandedModules.contains(moduleId);

        return Container(
          margin: const EdgeInsets.only(left: 16),
          child: ExpansionTile(
            dense: true,
            leading: Icon(
              isModuleExpanded ? Icons.folder_open : Icons.view_module,
              size: 16,
              color: Colors.green,
            ),
            title: Text(
              module['name'] ?? 'Unnamed Module',
              style: const TextStyle(fontSize: 12),
            ),
            onExpansionChanged: (expanded) {
              setState(() {
                if (expanded) {
                  _expandedModules.add(moduleId);
                } else {
                  _expandedModules.remove(moduleId);
                }
              });
            },
            children: tasks.map<Widget>((task) {
              return Container(
                margin: const EdgeInsets.only(left: 16),
                child: ListTile(
                  dense: true,
                  leading: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _getTaskStatusColor(task['status']),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  title: Text(
                    task['title'] ?? 'Untitled Task',
                    style: const TextStyle(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    task['task_id'] ?? '',
                    style: const TextStyle(fontSize: 9, color: Colors.grey),
                  ),
                  onTap: () => _showTaskDetailDialog(task),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Color _getTaskStatusColor(String? status) {
    return TaskStatus.getColor(status ?? TaskStatus.open);
  }

  void _showTaskDetailDialog(Map<String, dynamic> task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(task['title'] ?? 'Task Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task['task_id'] != null) ...[
              Row(
                children: [
                  const Icon(Icons.tag, size: 16),
                  const SizedBox(width: 4),
                  Text('ID: ${task['task_id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Text('Status: ${task['status'] ?? 'Unknown'}'),
            const SizedBox(height: 8),
            Text('Priority: ${task['priority'] ?? 'Unknown'}'),
            const SizedBox(height: 8),
            Text('Assigned to: ${task['assigned_to'] ?? 'Unassigned'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Navigate to task edit screen or start timer
            },
            child: const Text('Start Timer'),
          ),
        ],
      ),
    );
  }
}
