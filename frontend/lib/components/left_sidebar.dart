import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://task.amtariksha.com');

class LeftSidebar extends StatefulWidget {
  final bool isAdmin;
  final String currentRoute;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;

  const LeftSidebar({
    super.key,
    required this.isAdmin,
    required this.currentRoute,
    required this.isCollapsed,
    required this.onToggleCollapse,
  });

  @override
  State<LeftSidebar> createState() => _LeftSidebarState();
}

class _LeftSidebarState extends State<LeftSidebar> {
  List<dynamic> _projects = [];
  Map<int, List<dynamic>> _projectModules = {};
  Map<int, bool> _projectExpanded = {};
  Map<int, bool> _adminExpanded = {};
  Map<int, bool> _personalExpanded = {};
  bool _isLoadingProjects = false;

  // Menu expansion states - default to expanded as per requirements
  bool _projectsExpanded = true;
  bool _adminMenuExpanded = true;
  bool _personalMenuExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadMenuStates();
    _loadProjectsAndModules();
  }

  Future<void> _loadMenuStates() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _projectsExpanded = prefs.getBool('projects_expanded') ?? true;
      _adminMenuExpanded = prefs.getBool('admin_expanded') ?? true;
      _personalMenuExpanded = prefs.getBool('personal_expanded') ?? true;
    });
  }

  Future<void> _saveMenuStates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('projects_expanded', _projectsExpanded);
    await prefs.setBool('admin_expanded', _adminMenuExpanded);
    await prefs.setBool('personal_expanded', _personalMenuExpanded);
  }

  Future<String?> _getJwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  Future<void> _loadProjectsAndModules() async {
    if (_isLoadingProjects) return;

    setState(() => _isLoadingProjects = true);

    final jwt = await _getJwt();
    if (jwt == null) {
      setState(() => _isLoadingProjects = false);
      return;
    }

    try {
      // Load projects
      final projectsResponse = await http.get(
        Uri.parse('$apiBase/task/api/projects'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (projectsResponse.statusCode == 200) {
        final projects = jsonDecode(projectsResponse.body) as List;
        setState(() {
          _projects = projects;
          // Initialize expansion states for projects
          for (final project in projects) {
            _projectExpanded[project['id']] = false;
          }
        });

        // Load modules for each project
        for (final project in projects) {
          try {
            final modulesResponse = await http.get(
              Uri.parse('$apiBase/task/api/projects/${project['id']}/modules'),
              headers: {'Authorization': 'Bearer $jwt'},
            );

            if (modulesResponse.statusCode == 200) {
              final modules = jsonDecode(modulesResponse.body) as List;
              setState(() => _projectModules[project['id']] = modules);
            }
          } catch (e) {
            print('Error loading modules for project ${project['id']}: $e');
          }
        }
      }
    } catch (e) {
      print('Error loading projects: $e');
    } finally {
      setState(() => _isLoadingProjects = false);
    }
  }

  void _toggleProjectExpansion(int projectId) {
    setState(() {
      _projectExpanded[projectId] = !(_projectExpanded[projectId] ?? false);
    });
  }

  void _toggleMenuExpansion(String menu) {
    setState(() {
      switch (menu) {
        case 'projects':
          _projectsExpanded = !_projectsExpanded;
          break;
        case 'admin':
          _adminMenuExpanded = !_adminMenuExpanded;
          break;
        case 'personal':
          _personalMenuExpanded = !_personalMenuExpanded;
          break;
      }
    });
    _saveMenuStates();
  }

  bool _isRouteActive(String route) {
    return widget.currentRoute.startsWith(route);
  }

  @override
  Widget build(BuildContext context) {
    const primaryOrange = Color(0xFFFFA301);
    final sidebarWidth = widget.isCollapsed ? 60.0 : 280.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Sidebar header with collapse toggle
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: Row(
              children: [
                if (!widget.isCollapsed) ...[
                  const Text(
                    'Navigation',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryOrange,
                    ),
                  ),
                  const Spacer(),
                ],
                IconButton(
                  icon: Icon(
                    widget.isCollapsed ? Icons.menu : Icons.menu_open,
                    color: primaryOrange,
                  ),
                  onPressed: widget.onToggleCollapse,
                  tooltip: widget.isCollapsed ? 'Expand Menu' : 'Collapse Menu',
                ),
              ],
            ),
          ),

          // Sidebar content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Dashboard
                _buildMenuItem(
                  icon: Icons.dashboard,
                  label: 'Dashboard',
                  route: '/dashboard',
                  isActive: _isRouteActive('/dashboard'),
                ),

                // Projects Section
                _buildExpandableMenuItem(
                  icon: Icons.folder,
                  label: 'Projects',
                  isExpanded: _projectsExpanded,
                  onToggle: () => _toggleMenuExpansion('projects'),
                  children: [
                    _buildMenuItem(
                      icon: Icons.folder_open,
                      label: 'All Projects',
                      route: '/projects',
                      isActive: widget.currentRoute == '/projects',
                      indent: 1,
                    ),
                    ..._buildProjectHierarchy(),
                  ],
                ),

                // PERT
                _buildMenuItem(
                  icon: Icons.timeline,
                  label: 'PERT',
                  route: '/pert',
                  isActive: _isRouteActive('/pert'),
                ),

                // Calendar
                _buildMenuItem(
                  icon: Icons.calendar_today,
                  label: 'Calendar',
                  route: '/calendar',
                  isActive: _isRouteActive('/calendar'),
                ),

                // Chat
                _buildMenuItem(
                  icon: Icons.chat,
                  label: 'Chat',
                  route: '/chat',
                  isActive: _isRouteActive('/chat'),
                ),

                // Alerts
                _buildMenuItem(
                  icon: Icons.notifications,
                  label: 'Alerts',
                  route: '/alerts',
                  isActive: _isRouteActive('/alerts'),
                ),

                // Admin Section
                if (widget.isAdmin) ...[
                  const SizedBox(height: 16),
                  _buildExpandableMenuItem(
                    icon: Icons.admin_panel_settings,
                    label: 'Admin',
                    isExpanded: _adminMenuExpanded,
                    onToggle: () => _toggleMenuExpansion('admin'),
                    children: [
                      _buildMenuItem(
                        icon: Icons.bar_chart,
                        label: 'Reporting',
                        route: '/admin/reporting',
                        isActive: _isRouteActive('/admin/reporting'),
                        indent: 1,
                      ),
                      _buildMenuItem(
                        icon: Icons.today,
                        label: 'Daily Summary',
                        route: '/admin/reporting/daily-summary',
                        isActive: _isRouteActive('/admin/reporting/daily-summary'),
                        indent: 2,
                      ),
                      _buildMenuItem(
                        icon: Icons.assessment,
                        label: 'JSR Reports',
                        route: '/admin/reporting/jsr',
                        isActive: _isRouteActive('/admin/reporting/jsr'),
                        indent: 2,
                      ),
                      _buildMenuItem(
                        icon: Icons.folder_special,
                        label: 'Project Management',
                        route: '/admin/projects',
                        isActive: _isRouteActive('/admin/projects'),
                        indent: 1,
                      ),
                      _buildMenuItem(
                        icon: Icons.add_box,
                        label: 'Create Project',
                        route: '/admin/projects/create',
                        isActive: _isRouteActive('/admin/projects/create'),
                        indent: 2,
                      ),
                      _buildMenuItem(
                        icon: Icons.settings,
                        label: 'Project Settings',
                        route: '/admin/projects/settings',
                        isActive: _isRouteActive('/admin/projects/settings'),
                        indent: 2,
                      ),
                      _buildMenuItem(
                        icon: Icons.view_module,
                        label: 'Module Management',
                        route: '/admin/modules',
                        isActive: _isRouteActive('/admin/modules'),
                        indent: 2,
                      ),
                      _buildMenuItem(
                        icon: Icons.people,
                        label: 'User Management',
                        route: '/admin/users/manage',
                        isActive: _isRouteActive('/admin/users'),
                        indent: 1,
                      ),
                      _buildMenuItem(
                        icon: Icons.security,
                        label: 'Role Management',
                        route: '/admin/roles/manage',
                        isActive: _isRouteActive('/admin/roles/manage'),
                        indent: 1,
                      ),
                      _buildMenuItem(
                        icon: Icons.assignment_ind,
                        label: 'Role Assignment',
                        route: '/admin/roles/assign',
                        isActive: _isRouteActive('/admin/roles/assign'),
                        indent: 1,
                      ),
                      _buildMenuItem(
                        icon: Icons.edit_note,
                        label: 'Master Data',
                        route: '/admin/master-data',
                        isActive: _isRouteActive('/admin/master-data'),
                        indent: 1,
                      ),
                    ],
                  ),
                ],

                // Personal Section
                const SizedBox(height: 16),
                _buildExpandableMenuItem(
                  icon: Icons.person,
                  label: 'Personal',
                  isExpanded: _personalMenuExpanded,
                  onToggle: () => _toggleMenuExpansion('personal'),
                  children: [
                    _buildMenuItem(
                      icon: Icons.note,
                      label: 'Notes',
                      route: '/personal/notes',
                      isActive: _isRouteActive('/personal/notes'),
                      indent: 1,
                    ),
                    _buildMenuItem(
                      icon: Icons.palette,
                      label: 'Customize',
                      route: '/personal/customize',
                      isActive: _isRouteActive('/personal/customize'),
                      indent: 1,
                    ),
                    _buildMenuItem(
                      icon: Icons.edit,
                      label: 'Edit Profile',
                      route: '/profile',
                      isActive: _isRouteActive('/profile'),
                      indent: 1,
                    ),
                    _buildMenuItem(
                      icon: Icons.notifications_active,
                      label: 'Notifications',
                      route: '/personal/notifications',
                      isActive: _isRouteActive('/personal/notifications'),
                      indent: 1,
                    ),
                  ],
                ),

                // Other People's Tasks
                _buildMenuItem(
                  icon: Icons.people_outline,
                  label: 'Other People\'s Tasks',
                  route: '/other-tasks',
                  isActive: _isRouteActive('/other-tasks'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildProjectHierarchy() {
    List<Widget> widgets = [];

    for (final project in _projects) {
      final projectId = project['id'] as int;
      final isProjectExpanded = _projectExpanded[projectId] ?? false;
      final modules = _projectModules[projectId] ?? [];

      // Project item
      widgets.add(
        _buildExpandableMenuItem(
          icon: Icons.folder,
          label: project['name'] ?? 'Unnamed Project',
          isExpanded: isProjectExpanded,
          onToggle: () => _toggleProjectExpansion(projectId),
          indent: 1,
          route: '/projects/$projectId',
          isActive: widget.currentRoute == '/projects/$projectId',
          children: [
            // Modules for this project
            ...modules.map((module) => _buildMenuItem(
              icon: Icons.view_module,
              label: module['name'] ?? 'Unnamed Module',
              route: '/projects/$projectId/modules/${module['id']}',
              isActive: _isRouteActive('/projects/$projectId/modules/${module['id']}'),
              indent: 2,
            )).toList(),
          ],
        ),
      );
    }

    return widgets;
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required String route,
    required bool isActive,
    int indent = 0,
  }) {
    if (widget.isCollapsed) {
      return Tooltip(
        message: label,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          child: IconButton(
            icon: Icon(
              icon,
              color: isActive ? const Color(0xFFFFA301) : Colors.grey.shade600,
              size: 20,
            ),
            onPressed: () => context.go(route),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 8),
      child: InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.only(
            left: 16.0 + (indent * 20.0),
            right: 16,
            top: 12,
            bottom: 12,
          ),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFFA301).withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isActive ? Border.all(color: const Color(0xFFFFA301), width: 1) : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? const Color(0xFFFFA301) : Colors.grey.shade600,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isActive ? const Color(0xFFFFA301) : Colors.grey.shade700,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableMenuItem({
    required IconData icon,
    required String label,
    required bool isExpanded,
    required VoidCallback onToggle,
    required List<Widget> children,
    int indent = 0,
    String? route,
    bool isActive = false,
  }) {
    if (widget.isCollapsed) {
      return Tooltip(
        message: label,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          child: IconButton(
            icon: Icon(
              icon,
              color: isActive ? const Color(0xFFFFA301) : Colors.grey.shade600,
              size: 20,
            ),
            onPressed: route != null ? () => context.go(route) : onToggle,
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 8),
          child: InkWell(
            onTap: route != null ? () => context.go(route) : onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: EdgeInsets.only(
                left: 16.0 + (indent * 20.0),
                right: 16,
                top: 12,
                bottom: 12,
              ),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFFFA301).withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isActive ? Border.all(color: const Color(0xFFFFA301), width: 1) : null,
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: isActive ? const Color(0xFFFFA301) : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isActive ? const Color(0xFFFFA301) : Colors.grey.shade700,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (children.isNotEmpty)
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (isExpanded && children.isNotEmpty) ...children,
      ],
    );
  }
}
