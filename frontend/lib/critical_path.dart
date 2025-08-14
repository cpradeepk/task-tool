import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3003');

class CriticalPathView extends StatefulWidget {
  final int projectId;
  const CriticalPathView({super.key, required this.projectId});
  @override
  State<CriticalPathView> createState() => _CriticalPathViewState();
}

class _CriticalPathViewState extends State<CriticalPathView> {
  List<dynamic> _tasks = [];
  List<dynamic> _deps = [];
  bool _busy = false;

  Future<String?> _jwt() async => (await SharedPreferences.getInstance()).getString('jwt');

  Future<void> _load() async {
    setState(() { _busy = true; });
    final jwt = await _jwt();
    final r = await http.get(Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks/project/${widget.projectId}/critical-path'.replaceFirst('/tasks/project/${widget.projectId}', '/project/${widget.projectId}')),
      headers: { 'Authorization': 'Bearer $jwt' });
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    _tasks = j['tasks'] as List<dynamic>;
    _deps = j['dependencies'] as List<dynamic>;
    setState(() { _busy = false; });
  }

  @override
  void initState() { super.initState(); _load(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Critical Path')),
      body: _busy ? const Center(child: CircularProgressIndicator()) : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tasks: ${_tasks.length}, Dependencies: ${_deps.length}'),
          const SizedBox(height: 8),
          Expanded(child: ListView(
            children: [
              ..._deps.map((d) => ListTile(title: Text('Task ${d['task_id']} depends on ${d['depends_on_task_id']}'), subtitle: Text(d['type']))),
            ],
          )),
        ]),
      ),
    );
  }
}

