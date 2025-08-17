import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pin_auth.dart';
import 'projects.dart';
import 'profile.dart';
import 'modules.dart';
import 'dashboard.dart';
import 'main_layout.dart';
import 'tasks.dart';
import 'critical_path.dart';
import 'admin_login.dart';
import 'admin/user_management.dart';
import 'admin/daily_summary_report.dart';
import 'features/pert_analysis.dart';
import 'features/calendar_view.dart';
import 'features/chat_system.dart';
import 'features/alerts_system.dart';
import 'admin/jsr_reports.dart';
import 'admin/project_create.dart';
import 'admin/project_settings.dart';
import 'personal/notes_system.dart';
import 'personal/profile_edit.dart' as personal;

class AppRouter {
  late final GoRouter router;

  AppRouter() {
    router = GoRouter(
      initialLocation: '/login',
      redirect: (context, state) async {
        final prefs = await SharedPreferences.getInstance();
        final jwt = prefs.getString('jwt');
        if (jwt == null && state.uri.path != '/login') return '/login';
        if (jwt != null && state.uri.path == '/login') return '/dashboard';
        if (jwt != null && state.uri.path == '/') return '/dashboard';
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (ctx, st) => const LoginScreen()),

        // Dashboard as default landing page
        GoRoute(path: '/dashboard', builder: (ctx, st) => const DashboardScreen()),

        // Legacy home route redirects to dashboard
        GoRoute(path: '/', redirect: (ctx, st) => '/dashboard'),

        // Main application routes with new layout
        GoRoute(path: '/projects', builder: (ctx, st) => MainLayout(
          title: 'Projects',
          child: const ProjectsScreen(),
        )),
        GoRoute(path: '/profile', builder: (ctx, st) => MainLayout(
          title: 'Profile',
          child: const ProfileEditScreen(),
        )),
        GoRoute(path: '/projects/:id/modules', builder: (ctx, st) => MainLayout(
          title: 'Modules',
          child: ModulesScreen(projectId: int.parse(st.pathParameters['id']!)),
        )),
        GoRoute(path: '/projects/:id/tasks', builder: (ctx, st) => MainLayout(
          title: 'Tasks',
          child: TasksScreen(projectId: int.parse(st.pathParameters['id']!)),
        )),
        GoRoute(path: '/projects/:id/critical', builder: (ctx, st) => MainLayout(
          title: 'Critical Path',
          child: CriticalPathView(projectId: int.parse(st.pathParameters['id']!)),
        )),

        // New navigation routes
        GoRoute(path: '/pert', builder: (ctx, st) => const PertAnalysisScreen()),
        GoRoute(path: '/calendar', builder: (ctx, st) => const CalendarViewScreen()),
        GoRoute(path: '/chat', builder: (ctx, st) => const ChatSystemScreen()),
        GoRoute(path: '/alerts', builder: (ctx, st) => const AlertsSystemScreen()),
        GoRoute(path: '/others-tasks', builder: (ctx, st) => MainLayout(
          title: 'Other People\'s Tasks',
          child: const Center(child: Text('Other People\'s Tasks - Coming Soon')),
        )),

        // Admin routes
        GoRoute(path: '/admin/users/manage', builder: (ctx, st) => const UserManagementScreen()),
        GoRoute(path: '/admin/reporting/daily-summary', builder: (ctx, st) => const DailySummaryReportScreen()),
        GoRoute(path: '/admin/reporting/jsr', builder: (ctx, st) => const JSRReportsScreen()),
        GoRoute(path: '/admin/projects/create', builder: (ctx, st) => const ProjectCreateScreen()),
        GoRoute(path: '/admin/projects/settings', builder: (ctx, st) => const ProjectSettingsScreen()),
        GoRoute(path: '/admin/projects/:id/settings', builder: (ctx, st) => ProjectSettingsScreen(projectId: st.pathParameters['id'])),
        GoRoute(path: '/admin/reporting/jsr/planned', builder: (ctx, st) => const JSRReportsScreen()),
        GoRoute(path: '/admin/reporting/jsr/completed', builder: (ctx, st) => const JSRReportsScreen()),

        // Personal routes
        GoRoute(path: '/personal/notes', builder: (ctx, st) => const NotesSystemScreen()),
        GoRoute(path: '/personal/customize', builder: (ctx, st) => MainLayout(
          title: 'Customize',
          child: const Center(child: Text('Customize - Coming Soon')),
        )),
        GoRoute(path: '/personal/profile', builder: (ctx, st) => const personal.ProfileEditScreen()),
        GoRoute(path: '/personal/notifications', builder: (ctx, st) => MainLayout(
          title: 'Notifications',
          child: const Center(child: Text('Notifications - Coming Soon')),
        )),
      ],
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {



  void _showAdminLogin(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AdminLoginDialog(
        onSuccess: () {
          if (mounted) context.go('/dashboard');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Tool Login'),
        actions: [
          IconButton(
            onPressed: () => _showAdminLogin(context),
            icon: const Icon(Icons.admin_panel_settings),
            tooltip: 'Admin Login',
            color: Colors.red,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Task Tool', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),



              // PIN Authentication
              PinAuthWidget(
                onSuccess: () {
                  if (mounted) context.go('/');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? email;
  bool _dark = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      email = prefs.getString('email');
      _dark = (prefs.getString('theme_mode') ?? 'light') == 'dark';
    });
  }

  Future<void> _toggleTheme(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', v ? 'dark' : 'light');
    setState(() { _dark = v; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(email ?? ''),
            const SizedBox(height: 16),
            Row(children: [
              const Text('Dark mode'),
              const SizedBox(width: 12),
              Switch(value: _dark, onChanged: _toggleTheme),
            ])
          ],
        ),
      ),
    );
  }
}

