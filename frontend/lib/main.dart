import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth.dart';
import 'router.dart';
import 'nav.dart';
import 'theme/theme_provider.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3003');

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appRouter = AppRouter();
    final themeNotifier = ref.watch(themeProvider.notifier);
    final themeState = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'Task Tool',
      theme: themeNotifier.lightTheme,
      darkTheme: themeNotifier.darkTheme,
      themeMode: themeState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: appRouter.router,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _health = '-';
  String? _email;
  final _authCtl = AuthController();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await _authCtl.load();
    if (!_authCtl.isAuthed && mounted) {
      context.go('/login');
      return;
    }
    setState(() => _email = _authCtl.email);
  }

  Future<void> _checkHealth() async {
    try {
      final r = await http.get(Uri.parse('$apiBase/task/health'));
      setState(() => _health = r.statusCode == 200 ? 'OK' : 'ERR ${r.statusCode}');
    } catch (e) {
      setState(() => _health = 'ERR');
    }
  }

  Future<void> _login() async {
    await _authCtl.signIn();
    setState(() => _email = _authCtl.email);
  }

  Future<void> _logout() async {
    await _authCtl.signOut();
    setState(() => _email = null);
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppNav(),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('API base: $apiBase'),
            const SizedBox(height: 12),
            Row(children: [
              ElevatedButton(onPressed: _checkHealth, child: const Text('Check Health')),
              const SizedBox(width: 12),
              Text('Health: $_health')
            ]),
            const Divider(height: 32),
            if (_email == null)
              ElevatedButton(onPressed: _login, child: const Text('Login with Google'))
            else
              Row(children: [
                Text('Signed in as $_email'),
                const SizedBox(width: 12),
                TextButton(onPressed: _logout, child: const Text('Sign out')),
              ]),
          ],
        ),
      ),
    );
  }
}
