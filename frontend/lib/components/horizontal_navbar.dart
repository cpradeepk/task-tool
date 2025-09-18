import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/theme_provider.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://task.amtariksha.com');

class HorizontalNavbar extends ConsumerStatefulWidget {
  final String currentRoute;
  final bool isAdmin;
  final String? userEmail;
  final VoidCallback? onSignOut;

  const HorizontalNavbar({
    super.key,
    required this.currentRoute,
    this.isAdmin = false,
    this.userEmail,
    this.onSignOut,
  });

  @override
  ConsumerState<HorizontalNavbar> createState() => _HorizontalNavbarState();
}

class _HorizontalNavbarState extends ConsumerState<HorizontalNavbar> {
  bool _isMobileMenuOpen = false;
  List<dynamic> _projects = [];
  bool _projectsExpanded = false;
  bool _loadingProjects = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isAdmin) {
      _loadProjects();
    }
  }

  Future<String?> _getJwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  Future<void> _loadProjects() async {
    if (_loadingProjects) return;

    setState(() => _loadingProjects = true);

    try {
      final jwt = await _getJwt();
      if (jwt == null) return;

      final response = await http.get(
        Uri.parse('$apiBase/task/api/projects'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _projects = jsonDecode(response.body) as List<dynamic>;
        });
      }
    } catch (e) {
      print('Error loading projects: $e');
    } finally {
      setState(() => _loadingProjects = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border(
          bottom: BorderSide(
            color: DesignTokens.colors['gray200']!,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Top Header Row
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Logo and Title
                Expanded(
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.go('/dashboard'),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: DesignTokens.colors['primary'],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.task_alt,
                                color: DesignTokens.colors['black'],
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Amtariksha',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: DesignTokens.colors['black'],
                                  ),
                                ),
                                Text(
                                  _getRoleDisplayName(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: DesignTokens.colors['gray600'],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // User Menu
                Row(
                  children: [
                    if (!isMobile && widget.userEmail != null) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _getUserDisplayName(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: DesignTokens.colors['black'],
                            ),
                          ),
                          Text(
                            widget.userEmail!,
                            style: TextStyle(
                              fontSize: 12,
                              color: DesignTokens.colors['gray600'],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                    ],

                    // Admin Login Button (if not admin)
                    if (!widget.isAdmin) ...[
                      TextButton.icon(
                        onPressed: () => context.go('/admin-login'),
                        icon: Icon(
                          Icons.admin_panel_settings,
                          size: 16,
                          color: DesignTokens.colors['primary'],
                        ),
                        label: Text(
                          isMobile ? '' : 'Admin',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: DesignTokens.colors['primary'],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Logout Button
                    TextButton.icon(
                      onPressed: widget.onSignOut,
                      icon: Icon(
                        Icons.logout,
                        size: 16,
                        color: DesignTokens.colors['black'],
                      ),
                      label: Text(
                        isMobile ? '' : 'Logout',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: DesignTokens.colors['black'],
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: DesignTokens.colors['black'],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),

                    // Mobile menu button
                    if (isMobile) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _isMobileMenuOpen = !_isMobileMenuOpen;
                          });
                        },
                        icon: Icon(
                          _isMobileMenuOpen ? Icons.close : Icons.menu,
                          color: DesignTokens.colors['black'],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Navigation Tabs Row - Desktop
          if (!isMobile)
            Container(
              height: 56,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: DesignTokens.colors['gray100']!,
                    width: 1,
                  ),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    ..._getNavigationItems()
                        .where((item) => item.route != '/projects')
                        .map((item) => _buildNavTab(item, false))
                        .toList(),
                    if (!widget.isAdmin) _buildProjectsDropdown(),
                    ..._getNavigationItems()
                        .where((item) => item.route != '/projects' && item.route != '/dashboard' && item.route != '/tasks')
                        .map((item) => _buildNavTab(item, false))
                        .toList(),
                  ],
                ),
              ),
            ),

          // Mobile Navigation
          if (isMobile && _isMobileMenuOpen)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: DesignTokens.colors['gray200']!,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: _getNavigationItems()
                    .map((item) => _buildNavTab(item, true))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProjectsDropdown() {
    return PopupMenuButton<String>(
      offset: const Offset(0, 8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: widget.currentRoute.startsWith('/projects')
              ? DesignTokens.colors['primary']
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: widget.currentRoute.startsWith('/projects')
              ? Border.all(
                  color: DesignTokens.colors['primary600']!.withOpacity(0.3),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder,
              size: 16,
              color: widget.currentRoute.startsWith('/projects')
                  ? DesignTokens.colors['black']
                  : DesignTokens.colors['gray600'],
            ),
            const SizedBox(width: 8),
            Text(
              'Projects',
              style: TextStyle(
                fontSize: 14,
                fontWeight: widget.currentRoute.startsWith('/projects')
                    ? FontWeight.w600
                    : FontWeight.w500,
                color: widget.currentRoute.startsWith('/projects')
                    ? DesignTokens.colors['black']
                    : DesignTokens.colors['gray600'],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: widget.currentRoute.startsWith('/projects')
                  ? DesignTokens.colors['black']
                  : DesignTokens.colors['gray600'],
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: '/projects',
          child: Row(
            children: [
              Icon(Icons.folder, size: 16, color: DesignTokens.colors['gray600']),
              const SizedBox(width: 8),
              const Text('All Projects'),
            ],
          ),
        ),
        if (_projects.isNotEmpty) const PopupMenuDivider(),
        ..._projects.take(5).map((project) => PopupMenuItem<String>(
          value: '/projects/${project['id']}',
          child: Row(
            children: [
              Icon(Icons.folder_open, size: 16, color: DesignTokens.colors['primary']),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  project['name'] ?? 'Unnamed Project',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        )).toList(),
        if (_projects.length > 5) ...[
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: '/projects',
            child: Row(
              children: [
                Icon(Icons.more_horiz, size: 16, color: DesignTokens.colors['gray600']),
                const SizedBox(width: 8),
                Text('View All (${_projects.length})'),
              ],
            ),
          ),
        ],
      ],
      onSelected: (value) {
        context.go(value);
      },
    );
  }

  Widget _buildNavTab(NavigationItem item, bool isMobile) {
    final isActive = widget.currentRoute == item.route;

    return GestureDetector(
      onTap: () {
        context.go(item.route);
        if (isMobile) {
          setState(() {
            _isMobileMenuOpen = false;
          });
        }
      },
      child: Container(
        margin: isMobile 
            ? EdgeInsets.zero 
            : const EdgeInsets.symmetric(horizontal: 4),
        padding: isMobile
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? DesignTokens.colors['primary']
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? Border.all(
                  color: DesignTokens.colors['primary600']!.withOpacity(0.3),
                  width: 1,
                )
              : null,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: DesignTokens.colors['primary']!.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              size: 16,
              color: isActive
                  ? DesignTokens.colors['black']
                  : DesignTokens.colors['gray600'],
            ),
            const SizedBox(width: 8),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? DesignTokens.colors['black']
                    : DesignTokens.colors['gray600'],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<NavigationItem> _getNavigationItems() {
    final baseItems = [
      NavigationItem(
        route: '/dashboard',
        label: 'Dashboard',
        icon: Icons.home,
      ),
    ];

    if (widget.isAdmin) {
      return [
        ...baseItems,
        NavigationItem(
          route: '/users',
          label: 'User Management',
          icon: Icons.people,
        ),
        NavigationItem(
          route: '/settings',
          label: 'Settings',
          icon: Icons.settings,
        ),
      ];
    } else {
      return [
        ...baseItems,
        NavigationItem(
          route: '/tasks',
          label: 'Tasks',
          icon: Icons.add_task,
        ),
        NavigationItem(
          route: '/projects',
          label: 'Projects',
          icon: Icons.folder,
        ),
        NavigationItem(
          route: '/chat',
          label: 'Chat',
          icon: Icons.chat,
        ),
        NavigationItem(
          route: '/personal/notes',
          label: 'Notes',
          icon: Icons.note,
        ),
        NavigationItem(
          route: '/personal/profile',
          label: 'Profile',
          icon: Icons.person,
        ),
      ];
    }
  }

  String _getRoleDisplayName() {
    if (widget.isAdmin) {
      return 'Administrator';
    }
    return 'Team Member';
  }

  String _getUserDisplayName() {
    if (widget.userEmail == null) return 'User';
    final emailParts = widget.userEmail!.split('@');
    if (emailParts.isNotEmpty) {
      return emailParts[0].split('.').map((part) => 
        part.isNotEmpty ? part[0].toUpperCase() + part.substring(1) : part
      ).join(' ');
    }
    return 'User';
  }
}

class NavigationItem {
  final String route;
  final String label;
  final IconData icon;

  NavigationItem({
    required this.route,
    required this.label,
    required this.icon,
  });
}
