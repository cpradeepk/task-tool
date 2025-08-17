import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sidebar_navigation.dart';
import 'admin_login.dart';

class MainLayout extends StatefulWidget {
  final Widget child;
  final String title;
  
  const MainLayout({
    super.key, 
    required this.child,
    this.title = 'Task Tool',
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
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
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      const SizedBox(width: 16),
                      
                      // Page Title
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      
                      // Top Right Actions
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
                          backgroundColor: Colors.blue,
                          radius: 16,
                          child: Text(
                            (_userEmail?.substring(0, 1).toUpperCase()) ?? 'U',
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
                              Navigator.of(context).pushNamed('/personal/profile');
                              break;
                            case 'settings':
                              Navigator.of(context).pushNamed('/personal/customize');
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
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
