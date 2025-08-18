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
import 'task_detail.dart';
import 'critical_path.dart';
import 'admin_login.dart';
import 'admin/user_management.dart';
import 'admin/daily_summary_report.dart';
import 'features/pert_analysis.dart';
import 'features/calendar_view.dart';
import 'features/chat_system.dart';
import 'features/alerts_system.dart';
import 'features/other_people_tasks.dart';
import 'features/tagging_system.dart';
import 'features/notification_system.dart';
import 'features/advanced_search.dart';
import 'admin/jsr_reports.dart';
import 'admin/project_create.dart';
import 'admin/project_settings.dart';
import 'admin/master_data.dart';
import 'admin/role_assign.dart';
import 'admin/role_manage.dart';
import 'admin/module_management.dart';
import 'personal/notes_system.dart';
import 'personal/profile_edit.dart' as personal;
import 'personal/availability_management.dart';
import 'kanban_board.dart';

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
        GoRoute(path: '/projects/:id/kanban', builder: (ctx, st) => MainLayout(
          title: 'Kanban Board',
          child: KanbanBoardScreen(projectId: int.parse(st.pathParameters['id']!)),
        )),
        GoRoute(path: '/projects/:projectId/modules/:moduleId', builder: (ctx, st) => MainLayout(
          title: 'Module Tasks',
          child: TasksScreen(
            projectId: int.parse(st.pathParameters['projectId']!),
            moduleId: int.parse(st.pathParameters['moduleId']!),
          ),
        )),
        GoRoute(path: '/projects/:projectId/modules/:moduleId/kanban', builder: (ctx, st) => MainLayout(
          title: 'Module Kanban Board',
          child: KanbanBoardScreen(
            projectId: int.parse(st.pathParameters['projectId']!),
            moduleId: int.parse(st.pathParameters['moduleId']!),
          ),
        )),
        GoRoute(path: '/projects/:projectId/modules/:moduleId/tasks/:taskId', builder: (ctx, st) => MainLayout(
          title: 'Task Details',
          child: TaskDetailScreen(
            projectId: int.parse(st.pathParameters['projectId']!),
            taskId: int.parse(st.pathParameters['taskId']!),
          ),
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
        GoRoute(path: '/others-tasks', builder: (ctx, st) => const OtherPeopleTasksScreen()),

        // Admin routes
        GoRoute(path: '/admin/users/manage', builder: (ctx, st) => const UserManagementScreen()),
        GoRoute(path: '/admin/reporting/daily-summary', builder: (ctx, st) => const DailySummaryReportScreen()),
        GoRoute(path: '/admin/reporting/jsr', builder: (ctx, st) => const JSRReportsScreen()),
        GoRoute(path: '/admin/projects/create', builder: (ctx, st) => const ProjectCreateScreen()),
        GoRoute(path: '/admin/projects/settings', builder: (ctx, st) => const ProjectSettingsScreen()),
        GoRoute(path: '/admin/projects/:id/settings', builder: (ctx, st) => ProjectSettingsScreen(projectId: st.pathParameters['id'])),
        GoRoute(path: '/admin/reporting/jsr/planned', builder: (ctx, st) => const JSRReportsScreen()),
        GoRoute(path: '/admin/reporting/jsr/completed', builder: (ctx, st) => const JSRReportsScreen()),
        GoRoute(path: '/admin/master-data', builder: (ctx, st) => const MasterDataScreen()),
        GoRoute(path: '/admin/tags', builder: (ctx, st) => const TaggingSystemScreen()),
        GoRoute(path: '/notifications', builder: (ctx, st) => const NotificationSystemScreen()),
        GoRoute(path: '/search', builder: (ctx, st) => const AdvancedSearchScreen()),
        GoRoute(path: '/admin/roles/assign', builder: (ctx, st) => const RoleAssignScreen()),
        GoRoute(path: '/admin/roles/manage', builder: (ctx, st) => const RoleManageScreen()),
        GoRoute(path: '/admin/modules/manage', builder: (ctx, st) => const ModuleManagementScreen()),

        // Personal routes
        GoRoute(path: '/personal/notes', builder: (ctx, st) => const NotesSystemScreen()),
        GoRoute(path: '/availability', builder: (ctx, st) => const AvailabilityManagementScreen()),
        GoRoute(path: '/personal/customize', builder: (ctx, st) => const personal.ProfileEditScreen()),
        GoRoute(path: '/personal/profile', builder: (ctx, st) => const personal.ProfileEditScreen()),
        GoRoute(path: '/personal/notifications', builder: (ctx, st) => const AlertsSystemScreen()),
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

