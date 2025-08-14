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

  List<List<dynamic>> _layers() {
    // Simple layering: Kahn's algorithm to compute levels
    final indeg = <int,int>{};
    final children = <int,List<int>>{};
    for (final t in _tasks) { indeg[t['id'] as int] = 0; children[t['id'] as int] = []; }
    for (final d in _deps) { indeg[d['task_id'] as int] = (indeg[d['task_id'] as int] ?? 0) + 1; children[d['depends_on_task_id'] as int]!.add(d['task_id'] as int); }
    final layers = <List<dynamic>>[];
    var frontier = _tasks.where((t) => (indeg[t['id'] as int] ?? 0) == 0).toList();
    final idToTask = {for (final t in _tasks) t['id'] as int : t};
    final seen = <int>{};
    while (frontier.isNotEmpty) {
      layers.add(frontier);
      final next = <dynamic>[];
      for (final f in frontier) {
        seen.add(f['id'] as int);
        for (final c in children[f['id'] as int]!) {
          indeg[c] = (indeg[c] ?? 0) - 1;
          if ((indeg[c] ?? 0) == 0) next.add(idToTask[c]);
        }
      }
      frontier = next;
    }
    // Append any remaining (in cycles) as last layer
    final remaining = _tasks.where((t) => !seen.contains(t['id'] as int)).toList();
    if (remaining.isNotEmpty) layers.add(remaining);
    return layers;
  }

  @override
  Widget build(BuildContext context) {
    final layers = _layers();
    return Scaffold(
      appBar: AppBar(title: const Text('Critical Path')),
      body: _busy ? const Center(child: CircularProgressIndicator()) : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tasks: ${_tasks.length}, Dependencies: ${_deps.length}, Layers: ${layers.length}'),
          const SizedBox(height: 8),
          Expanded(child: ListView.builder(
            itemCount: layers.length,
            itemBuilder: (ctx, i){
              final layer = layers[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Wrap(spacing: 8, children: [
                  for (final t in layer) Chip(label: Text('${t['id']}: ${t['title']}'))
                ]),
              );
            }
          )),
        ]),
      ),
    );
  }
}

