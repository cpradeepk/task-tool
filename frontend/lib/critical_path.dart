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
  List<dynamic> _modules = [];
  List<dynamic> _assignments = [];
  bool _busy = false;
  int? _moduleFilter;
  String _assigneeFilter = '';

  Future<String?> _jwt() async => (await SharedPreferences.getInstance()).getString('jwt');

  Future<void> _load() async {
    setState(() { _busy = true; });
    final jwt = await _jwt();
    final r = await http.get(Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks/project/${widget.projectId}/critical-path'.replaceFirst('/tasks/project/${widget.projectId}', '/project/${widget.projectId}')),
      headers: { 'Authorization': 'Bearer $jwt' });
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    _tasks = j['tasks'] as List<dynamic>;
    _deps = j['dependencies'] as List<dynamic>;
    _modules = j['modules'] as List<dynamic>? ?? [];
    _assignments = j['assignments'] as List<dynamic>? ?? [];
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

  List<int> _longestPath(List<dynamic> tasks, List<dynamic> deps) {
    final idToIndex = {for (var i=0;i<tasks.length;i++) tasks[i]['id'] as int : i};
    final g = <int,List<int>>{ for (final t in tasks) t['id'] as int : [] };
    final w = <int,double>{ for (final t in tasks) t['id'] as int : (t['expected_time'] as num?)?.toDouble() ?? 1.0 };
    final indeg = <int,int>{ for (final t in tasks) t['id'] as int : 0 };
    for (final d in deps) { g[d['depends_on_task_id'] as int]!.add(d['task_id'] as int); indeg[d['task_id'] as int] = (indeg[d['task_id'] as int] ?? 0)+1; }
    // Topo order
    final q = <int>[]..addAll(tasks.where((t)=>indeg[t['id'] as int]==0).map((t)=>t['id'] as int));
    final order = <int>[];
    while (q.isNotEmpty) { final u = q.removeAt(0); order.add(u); for (final v in g[u]!) { indeg[v] = (indeg[v] ?? 0)-1; if (indeg[v]==0) q.add(v); } }
    // DP longest path
    final dist = <int,double>{ for (final t in tasks) t['id'] as int : double.negativeInfinity };
    final parent = <int,int?>{ for (final t in tasks) t['id'] as int : null };
    for (final u in order) {
      if (indeg[u]==0) dist[u] = w[u] ?? 1.0; // sources
      for (final v in g[u]!) {
        final base = dist[u] ?? double.negativeInfinity;
        final cand = ((base.isFinite ? base : 0.0) + (w[v] ?? 1.0));
        final dv = dist[v] ?? double.negativeInfinity;
        if (!dv.isFinite || cand > dv) { dist[v] = cand; parent[v] = u; }
      }
    }
    // Find sink with max dist
    var best = order.isNotEmpty ? order.last : (tasks.isNotEmpty ? tasks.last['id'] as int : -1);
    var bestVal = dist[best] ?? double.negativeInfinity;
    for (final t in tasks) { final id = t['id'] as int; final dv = dist[id] ?? double.negativeInfinity; if (dv.isFinite && dv > bestVal) { best = id; bestVal = dv; } }
    // Reconstruct path
    final path = <int>[]; int? cur = best; final seen = <int>{};
    while (cur != null && !seen.contains(cur)) { path.add(cur); seen.add(cur); cur = parent[cur]; }
    return path.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final modulesById = {for (final m in _modules) m['id'] as int : m['name']};
    final assignmentsByTask = <int, List<String>>{};
    for (final a in _assignments) { final tid = a['task_id'] as int; assignmentsByTask.putIfAbsent(tid, ()=>[]).add(a['email'] as String); }

    final layers = _layers();
    final critical = _longestPath(_tasks, _deps);
    return Scaffold(
      appBar: AppBar(title: const Text('Critical Path')),
      body: _busy ? const Center(child: CircularProgressIndicator()) : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tasks: ${_tasks.length}, Dependencies: ${_deps.length}, Layers: ${layers.length}'),
          const SizedBox(height: 8),
          Row(children:[
            const Text('Module:'), const SizedBox(width: 8),
            DropdownButton<int?>(
              value: _moduleFilter,
              items: [const DropdownMenuItem(value: null, child: Text('All')), ..._modules.map((m)=>DropdownMenuItem(value: m['id'] as int, child: Text(m['name'])))],
              onChanged: (v){ setState(()=>_moduleFilter=v); },
            ),
            const SizedBox(width: 16),
            const Text('Assignee:'), const SizedBox(width: 8),
            SizedBox(width: 200, child: TextField(decoration: const InputDecoration(hintText: 'email contains'), onChanged: (v){ setState(()=>_assigneeFilter=v); })),
          ]),
          const SizedBox(height: 8),
          Text('Critical chain: ${critical.join(' -> ')}'),
          const SizedBox(height: 8),
          Expanded(child: ListView.builder(
            itemCount: layers.length,
            itemBuilder: (ctx, i){
              var layer = [...layers[i]]; // copy to avoid mutating base
              layer.sort((a,b)=> ((b['expected_time']??1) as num).compareTo(((a['expected_time']??1) as num)));
              // apply filters
              if (_moduleFilter != null) layer = layer.where((t)=>t['module_id']==_moduleFilter).toList();
              if (_assigneeFilter.isNotEmpty) layer = layer.where((t)=> (assignmentsByTask[t['id']] ?? const <String>[]).any((e)=> e.toLowerCase().contains(_assigneeFilter.toLowerCase())) ).toList();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Wrap(spacing: 8, children: [
                  for (final t in layer) Chip(
                    label: Row(mainAxisSize: MainAxisSize.min, children:[
                      Text('${t['id']}: ${t['title']}'),
                      if (t['module_id'] != null) Padding(padding: const EdgeInsets.only(left:6), child: Chip(label: Text('M:${t['module_id']}'), visualDensity: VisualDensity.compact)),
                      if ((assignmentsByTask[t['id']] ?? const <String>[]).isNotEmpty) Padding(padding: const EdgeInsets.only(left:6), child: Chip(label: Text((assignmentsByTask[t['id']] ?? const <String>[]).join(',')), visualDensity: VisualDensity.compact)),
                    ]),
                    backgroundColor: critical.contains(t['id']) ? Colors.redAccent : null,
                  )
                ]),
              );
            }
          )),
        ]),
      ),
    );
  }
}

