import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'components/left_sidebar.dart';
import 'admin_login.dart';
import 'theme/theme_provider.dart';
import 'components/animations.dart';

class ModernLayout extends ConsumerStatefulWidget {
  final Widget child;
  final String title;

  const ModernLayout({
    super.key,
    required this.child,
    this.title = 'KaryaSiddhi',
  });

  @override
  ConsumerState<ModernLayout> createState() => _ModernLayoutState();
}

class _ModernLayoutState extends ConsumerState<ModernLayout> {
  bool _isAdmin = false;
  String? _userEmail;
  bool _isSidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAdmin = prefs.getBool('is_admin') ?? false;
      _userEmail = prefs.getString('user_email');
      _isSidebarCollapsed = prefs.getBool('sidebar_collapsed') ?? false;
    });
  }

  void _toggleSidebar() async {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sidebar_collapsed', _isSidebarCollapsed);
  }

  void _showAdminLogin() {
    showDialog(
      context: context,
      builder: (context) => const AdminLoginDialog(),
    ).then((_) => _loadUserInfo());
  }

  Future<void> _signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      context.go('/');
    }
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

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final zoomLevel = themeState.zoomLevel;
    final currentRoute = GoRouterState.of(context).uri.path;

    return Transform.scale(
      scale: zoomLevel,
      alignment: Alignment.topLeft,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Row(
          children: [
            // Left Sidebar
            LeftSidebar(
              isAdmin: _isAdmin,
              currentRoute: currentRoute,
              isCollapsed: _isSidebarCollapsed,
              onToggleCollapse: _toggleSidebar,
            ),

            // Main Content Area
            Expanded(
              child: Column(
                children: [
                  // Top Header Bar with Logo and User Info
                  Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: const Border(
                        bottom: BorderSide(
                          color: Color(0xFFFFECB3),
                          width: 1,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    // Logo and Title
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFA301),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.task_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Amtariksha',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                      ],
                    ),
                    
                    const Spacer(),
                    
                    // Search Bar
                    Container(
                      width: 320,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFFFECB3)),
                      ),
                      child: const TextField(
                        decoration: InputDecoration(
                          hintText: 'Search tasks, projects...',
                          hintStyle: TextStyle(
                            color: Color(0xFFA0A0A0),
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Color(0xFFA0A0A0),
                            size: 18,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 24),
                    
                    // Zoom Controls
                    Row(
                      children: [
                        IconButton(
                          onPressed: _zoomOut,
                          icon: const Icon(Icons.zoom_out),
                          tooltip: 'Zoom Out',
                          iconSize: 18,
                          color: const Color(0xFFA0A0A0),
                        ),
                        GestureDetector(
                          onTap: _resetZoom,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${(zoomLevel * 100).round()}%',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF2D3748),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _zoomIn,
                          icon: const Icon(Icons.zoom_in),
                          tooltip: 'Zoom In',
                          iconSize: 18,
                          color: const Color(0xFFA0A0A0),
                        ),
                      ],
                    ),

                    const SizedBox(width: 16),

                    // Admin Login (if not admin)
                    if (!_isAdmin) ...[
                      IconButton(
                        onPressed: _showAdminLogin,
                        icon: const Icon(Icons.admin_panel_settings),
                        tooltip: 'Admin Login',
                        color: const Color(0xFFA0A0A0),
                      ),
                    ],
                    
                    // User Menu
                    PopupMenuButton<String>(
                      icon: CircleAvatar(
                        backgroundColor: const Color(0xFFFFA301),
                        radius: 16,
                        child: Text(
                          (_userEmail?.substring(0, 1).toUpperCase()) ?? 'A',
                          style: const TextStyle(
                            color: Colors.white,
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
                        const PopupMenuItem(
                          value: 'profile',
                          child: Row(
                            children: [
                              Icon(Icons.person, size: 18),
                              SizedBox(width: 8),
                              Text('Profile'),
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
                  ],
                ),
              ),
            ),
            
                  // Main Content Area
                  Expanded(
                    child: Container(
                      color: const Color(0xFFFAFAFA),
                      child: widget.child,
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
