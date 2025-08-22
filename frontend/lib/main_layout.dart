import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'sidebar_navigation.dart';
import 'admin_login.dart';
import 'theme/theme_provider.dart';
import 'components/animations.dart';

class MainLayout extends ConsumerStatefulWidget {
  final Widget child;
  final String title;

  const MainLayout({
    super.key,
    required this.child,
    this.title = 'Task Tool',
  });

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  bool _isSidebarCollapsed = false;
  bool _isAdmin = false;
  String? _userEmail;

  // Menu expansion states - default to expanded for main sections
  bool _projectsExpanded = true;
  bool _adminExpanded = true;
  bool _personalExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadSidebarState();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAdmin = prefs.getBool('isAdmin') ?? false;
      _userEmail = prefs.getString('email');
    });
  }

  Future<void> _loadSidebarState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isSidebarCollapsed = prefs.getBool('sidebar_collapsed') ?? false;
      _projectsExpanded = prefs.getBool('projects_expanded') ?? true;
      _adminExpanded = prefs.getBool('admin_expanded') ?? true;
      _personalExpanded = prefs.getBool('personal_expanded') ?? true;
    });
  }

  Future<void> _toggleSidebar() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
    await prefs.setBool('sidebar_collapsed', _isSidebarCollapsed);
  }

  Future<void> _toggleMenuSection(String section) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      switch (section) {
        case 'projects':
          _projectsExpanded = !_projectsExpanded;
          prefs.setBool('projects_expanded', _projectsExpanded);
          break;
        case 'admin':
          _adminExpanded = !_adminExpanded;
          prefs.setBool('admin_expanded', _adminExpanded);
          break;
        case 'personal':
          _personalExpanded = !_personalExpanded;
          prefs.setBool('personal_expanded', _personalExpanded);
          break;
      }
    });
  }

  void _zoomIn() {
    ref.read(themeProvider.notifier).zoomIn();
  }

  void _zoomOut() {
    ref.read(themeProvider.notifier).zoomOut();
  }

  void _resetZoom() {
    ref.read(themeProvider.notifier).resetZoom();
  }

  bool _shouldShowBreadcrumbs() {
    final currentRoute = GoRouterState.of(context).uri.path;
    return currentRoute.contains('/projects/') ||
           currentRoute.contains('/modules/') ||
           currentRoute.contains('/tasks/');
  }

  Widget _buildBreadcrumbs() {
    final currentRoute = GoRouterState.of(context).uri.path;
    final pathSegments = currentRoute.split('/').where((s) => s.isNotEmpty).toList();

    List<Widget> breadcrumbs = [];

    // Add Home
    breadcrumbs.add(
      GestureDetector(
        onTap: () => context.go('/dashboard'),
        child: Text(
          'Dashboard',
          style: TextStyle(
            color: Colors.blue.shade600,
            fontSize: 14,
          ),
        ),
      ),
    );

    // Parse path and build breadcrumbs
    for (int i = 0; i < pathSegments.length; i++) {
      final segment = pathSegments[i];

      if (segment == 'projects' && i + 1 < pathSegments.length) {
        breadcrumbs.add(const Text(' / ', style: TextStyle(color: Colors.grey)));
        final projectId = pathSegments[i + 1];
        breadcrumbs.add(
          GestureDetector(
            onTap: () => context.go('/projects/$projectId/tasks'),
            child: Text(
              'Project $projectId',
              style: TextStyle(
                color: Colors.blue.shade600,
                fontSize: 14,
              ),
            ),
          ),
        );
        i++; // Skip the project ID
      } else if (segment == 'modules' && i + 1 < pathSegments.length) {
        breadcrumbs.add(const Text(' / ', style: TextStyle(color: Colors.grey)));
        final moduleId = pathSegments[i + 1];
        breadcrumbs.add(
          Text(
            'Module $moduleId',
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
        i++; // Skip the module ID
      } else if (segment == 'tasks') {
        breadcrumbs.add(const Text(' / ', style: TextStyle(color: Colors.grey)));
        breadcrumbs.add(
          const Text(
            'Tasks',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      } else if (segment == 'kanban') {
        breadcrumbs.add(const Text(' / ', style: TextStyle(color: Colors.grey)));
        breadcrumbs.add(
          const Text(
            'Kanban Board',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Icon(Icons.home, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          ...breadcrumbs,
          const Spacer(),
          // Export options
          PopupMenuButton<String>(
            icon: Icon(Icons.download, color: Colors.grey.shade600),
            tooltip: 'Export Options',
            onSelected: (value) => _handleExport(value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(Icons.table_chart, size: 18),
                    SizedBox(width: 8),
                    Text('Export as CSV'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, size: 18),
                    SizedBox(width: 8),
                    Text('Export as PDF'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleExport(String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Export as ${format.toUpperCase()} functionality will be implemented'),
        backgroundColor: Colors.blue.shade600,
      ),
    );
  }

  void _showAdminLogin() {
    showDialog(
      context: context,
      builder: (context) => AdminLoginDialog(
        onSuccess: () {
          _loadUserInfo(); // Refresh user info after admin login
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Admin login successful')),
          );
        },
      ),
    );
  }

  Future<void> _signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final zoomLevel = themeState.zoomLevel;

    return Transform.scale(
      scale: zoomLevel,
      alignment: Alignment.topLeft,
      child: Scaffold(
        body: Row(
                children: [
                  // Sidebar Navigation
                  SidebarNavigation(
                    isCollapsed: _isSidebarCollapsed,
                    onToggle: _toggleSidebar,
                  ),

                  // Main Content Area
                  Expanded(
                    child: Column(
                      children: [
                // Top App Bar
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: DesignTokens.colors['gray200']!,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: DesignTokens.spacing16),

                      // Page Title
                      Expanded(
                        child: Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: DesignTokens.colors['black'],
                          ),
                        ),
                      ),
                      
                      // Top Right Actions
                      // Zoom Controls
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: _zoomOut,
                            icon: const Icon(Icons.zoom_out),
                            tooltip: 'Zoom Out',
                            color: Colors.grey.shade600,
                          ),
                          GestureDetector(
                            onTap: _resetZoom,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${(zoomLevel * 100).round()}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _zoomIn,
                            icon: const Icon(Icons.zoom_in),
                            tooltip: 'Zoom In',
                            color: Colors.grey.shade600,
                          ),
                        ],
                      ),

                      if (!_isAdmin) ...[
                        IconButton(
                          onPressed: _showAdminLogin,
                          icon: const Icon(Icons.admin_panel_settings),
                          tooltip: 'Admin Login',
                          color: Colors.grey.shade600,
                        ),
                      ],
                      
                      // User Menu
                      PopupMenuButton<String>(
                        icon: CircleAvatar(
                          backgroundColor: DesignTokens.primaryOrange,
                          radius: 16,
                          child: Text(
                            (_userEmail?.substring(0, 1).toUpperCase()) ?? 'U',
                            style: TextStyle(
                              color: DesignTokens.colors['black'],
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        onSelected: (value) {
                          switch (value) {
                            case 'profile':
                              context.go('/profile');
                              break;
                            case 'settings':
                              context.go('/profile');
                              break;
                            case 'logout':
                              _signOut();
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'profile',
                            child: Row(
                              children: [
                                const Icon(Icons.person, size: 18),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _userEmail ?? 'User',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
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
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'profile',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 18),
                                SizedBox(width: 8),
                                Text('Edit Profile'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'settings',
                            child: Row(
                              children: [
                                Icon(Icons.settings, size: 18),
                                SizedBox(width: 8),
                                Text('Settings'),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'logout',
                            child: Row(
                              children: [
                                Icon(Icons.logout, size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Sign Out', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(width: 16),
                    ],
                  ),
                ),
                
                // Main Content
                Expanded(
                  child: Container(
                    color: Colors.grey.shade50,
                    child: Column(
                      children: [
                        // Breadcrumbs
                        if (_shouldShowBreadcrumbs()) _buildBreadcrumbs(),

                        // Main content
                        Expanded(
                          child: widget.child,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
