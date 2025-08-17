import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'auth.dart';
import 'pin_auth.dart';
import 'projects.dart';
import 'profile.dart';
import 'modules.dart';
import 'dashboard.dart';
import 'main_layout.dart';
import 'tasks.dart';
import 'critical_path.dart';

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
        GoRoute(path: '/pert', builder: (ctx, st) => MainLayout(
          title: 'PERT Analysis',
          child: const Center(child: Text('PERT Analysis - Coming Soon')),
        )),
        GoRoute(path: '/calendar', builder: (ctx, st) => MainLayout(
          title: 'Calendar',
          child: const Center(child: Text('Calendar - Coming Soon')),
        )),
        GoRoute(path: '/chat', builder: (ctx, st) => MainLayout(
          title: 'Chat',
          child: const Center(child: Text('Chat - Coming Soon')),
        )),
        GoRoute(path: '/alerts', builder: (ctx, st) => MainLayout(
          title: 'Alerts',
          child: const Center(child: Text('Alerts - Coming Soon')),
        )),
        GoRoute(path: '/others-tasks', builder: (ctx, st) => MainLayout(
          title: 'Other People\'s Tasks',
          child: const Center(child: Text('Other People\'s Tasks - Coming Soon')),
        )),

        // Personal routes
        GoRoute(path: '/personal/notes', builder: (ctx, st) => MainLayout(
          title: 'My Notes',
          child: const Center(child: Text('Notes - Coming Soon')),
        )),
        GoRoute(path: '/personal/customize', builder: (ctx, st) => MainLayout(
          title: 'Customize',
          child: const Center(child: Text('Customize - Coming Soon')),
        )),
        GoRoute(path: '/personal/profile', builder: (ctx, st) => MainLayout(
          title: 'Edit Profile',
          child: const Center(child: Text('Edit Profile - Coming Soon')),
        )),
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
  final _auth = AuthController();
  bool _busy = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _checkExistingAuth();
  }

  Future<void> _checkExistingAuth() async {
    await _auth.load();
    if (_auth.isAuthed && mounted) {
      context.go('/');
    }
  }

  Future<void> _doLogin() async {
    setState(() { _busy = true; _err = null; });
    try {
      await _auth.signIn();
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      setState(() { _err = 'Login failed'; });
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Task Tool Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Task Tool', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),

              // Test Account Login
              Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.bug_report, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Test Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_err != null) ...[
                        Text(_err!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                      ],
                      ElevatedButton(
                        onPressed: _busy ? null : _doLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        child: _busy ? const CircularProgressIndicator() : const Text('Login with Test Account'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

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

