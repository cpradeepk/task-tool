import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

// Global callback for refreshing sidebar
VoidCallback? _globalSidebarRefresh;

// Global function to refresh sidebar from anywhere in the app
void refreshSidebar() {
  _globalSidebarRefresh?.call();
}

class _SidebarNavigationState extends State<SidebarNavigation> {
  List<dynamic> _projects = [];
  Map<int, List<dynamic>> _projectModules = {};
  Set<int> _expandedProjects = {};
  bool _isAdmin = false;
  String? _userEmail;
  bool _isProjectsExpanded = true;
  bool _isAdminExpanded = true;
  bool _isPersonalExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadMenuStates();
    _loadUserInfo();
    _loadProjects();

    // Register global refresh callback
    _globalSidebarRefresh = () {
      if (mounted) {
        _loadProjects();
      }
    };
  }

  @override
  void dispose() {
    // Clear global callback
    _globalSidebarRefresh = null;
    super.dispose();
  }

  Future<void> _loadMenuStates() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isProjectsExpanded = prefs.getBool('menu_projects_expanded') ?? true;
      _isAdminExpanded = prefs.getBool('menu_admin_expanded') ?? true;
      _isPersonalExpanded = prefs.getBool('menu_personal_expanded') ?? true;
    });
  }

  Future<void> _saveMenuState(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
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
      } else {
        print('Failed to load modules for project $projectId: ${response.statusCode} - ${response.body}');
        setState(() => _projectModules[projectId] = []);
      }
    } catch (e) {
      print('Error loading modules for project $projectId: $e');
      setState(() => _projectModules[projectId] = []);
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
                      icon: Icons.schedule,
                      title: 'Availability',
                      route: '/availability',
                      isSubItem: true,
                    ),
                    _buildNavItem(
                      icon: Icons.palette,
                      title: 'Customize',
                      route: '/profile',
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

    // Determine initial expansion state based on title
    bool initiallyExpanded = true;
    String menuKey = '';

    switch (title.toLowerCase()) {
      case 'projects':
        initiallyExpanded = _isProjectsExpanded;
        menuKey = 'menu_projects_expanded';
        break;
      case 'admin':
        initiallyExpanded = _isAdminExpanded;
        menuKey = 'menu_admin_expanded';
        break;
      case 'personal':
        initiallyExpanded = _isPersonalExpanded;
        menuKey = 'menu_personal_expanded';
        break;
      default:
        initiallyExpanded = true;
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
      initiallyExpanded: initiallyExpanded,
      onExpansionChanged: (expanded) {
        if (menuKey.isNotEmpty) {
          _saveMenuState(menuKey, expanded);
          setState(() {
            switch (title.toLowerCase()) {
              case 'projects':
                _isProjectsExpanded = expanded;
                break;
              case 'admin':
                _isAdminExpanded = expanded;
                break;
              case 'personal':
                _isPersonalExpanded = expanded;
                break;
            }
          });
        }
      },
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
      title: GestureDetector(
        onTap: () {
          // Navigate to project overview when project name is clicked
          context.go('/projects/$projectId/tasks');
        },
        child: Text(
          project['name'] ?? 'Unnamed Project',
          style: const TextStyle(fontSize: 13, color: Colors.blue),
        ),
      ),
      onExpansionChanged: (expanded) {
        setState(() {
          if (expanded) {
            _expandedProjects.add(projectId);
            // Load modules when project is expanded
            if (modules.isEmpty) {
              _loadProjectModules(projectId);
            }
          } else {
            _expandedProjects.remove(projectId);
          }
        });
      },
      children: modules.map<Widget>((module) {
        final moduleId = module['id'] as int;

        return Container(
          margin: const EdgeInsets.only(left: 16),
          child: ListTile(
            dense: true,
            leading: Icon(
              Icons.view_module,
              size: 16,
              color: Colors.green,
            ),
            title: Text(
              module['name'] ?? 'Unnamed Module',
              style: const TextStyle(fontSize: 12, color: Colors.blue),
            ),
            onTap: () {
              // Navigate to module tasks when module is clicked
              final projectId = project['id'] as int;
              context.go('/projects/$projectId/modules/$moduleId');
            },
          ),
        );
      }).toList(),
    );
  }


}
