import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'auth.dart';
import 'projects.dart';
import 'profile.dart';
import 'modules.dart';
import 'tasks.dart';

class AppRouter {
  late final GoRouter router;

  AppRouter() {
    router = GoRouter(
      initialLocation: '/',
      redirect: (context, state) async {
        final prefs = await SharedPreferences.getInstance();
        final jwt = prefs.getString('jwt');
        final loggingIn = state.fullPath == '/login';
        if (jwt == null && !loggingIn) return '/login';
        if (jwt != null && loggingIn) return '/';
        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (ctx, st) => const HomeScreen()),
        GoRoute(path: '/login', builder: (ctx, st) => const LoginScreen()),
        GoRoute(path: '/profile', builder: (ctx, st) => const ProfileEditScreen()),
        GoRoute(path: '/projects', builder: (ctx, st) => const ProjectsScreen()),
        GoRoute(path: '/projects/:id/modules', builder: (ctx, st) => ModulesScreen(projectId: int.parse(st.pathParameters['id']!))),
        GoRoute(path: '/projects/:id/tasks', builder: (ctx, st) => TasksScreen(projectId: int.parse(st.pathParameters['id']!))),
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
      appBar: AppBar(title: const Text('Sign in')),
      body: Center(
        child: _busy
          ? const CircularProgressIndicator()
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_err != null) Text(_err!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _doLogin, child: const Text('Continue with Google')),
              ],
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

