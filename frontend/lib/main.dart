import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3003');

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Tool',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue)),
      home: const HomeScreen(),
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
  String _auth = '-';

  Future<void> _checkHealth() async {
    try {
      final r = await http.get(Uri.parse('$apiBase/task/health'));
      setState(() => _health = r.statusCode == 200 ? 'OK' : 'ERR ${r.statusCode}');
    } catch (e) {
      setState(() => _health = 'ERR');
    }
  }

  Future<void> _mockLogin() async {
    // Placeholder for Google Sign-In web; will be replaced with real flow
    // For now, we show the endpoint and expected payload
    setState(() => _auth = 'POST /task/api/auth/session with Google ID token');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Task Tool')),
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
            const SizedBox(height: 24),
            Row(children: [
              ElevatedButton(onPressed: _mockLogin, child: const Text('Login (Google)')),
              const SizedBox(width: 12),
              Expanded(child: Text(_auth))
            ]),
          ],
        ),
      ),
    );
  }
}
