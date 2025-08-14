import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3003');

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});
  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  List<dynamic> _projects = [];
  bool _busy = false;
  final _nameCtl = TextEditingController();

  Future<String?> _jwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  Future<void> _load() async {
    setState(() { _busy = true; });
    final jwt = await _jwt();
    final r = await http.get(Uri.parse('$apiBase/task/api/projects'), headers: { 'Authorization': 'Bearer $jwt' });
    setState(() {
      _busy = false;
      if (r.statusCode == 200) {
        _projects = jsonDecode(r.body) as List<dynamic>;
      }
    });
  }

  Future<void> _create() async {
    final jwt = await _jwt();
    final r = await http.post(Uri.parse('$apiBase/task/api/projects'),
      headers: { 'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json' },
      body: jsonEncode({ 'name': _nameCtl.text })
    );
    if (r.statusCode == 201) {
      _nameCtl.clear();
      await _load();
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(children: [
              Expanded(child: TextField(controller: _nameCtl, decoration: const InputDecoration(labelText: 'New project name'))),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _create, child: const Text('Add'))
            ]),
            const Divider(height: 24),
            if (_busy) const LinearProgressIndicator(),
            Expanded(
              child: ListView.builder(
                itemCount: _projects.length,
                itemBuilder: (ctx, i) {
                  final p = _projects[i];
                  return ListTile(title: Text(p['name'] ?? ''), subtitle: Text('ID ${p['id']}'));
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}

