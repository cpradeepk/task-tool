import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'master_data.dart';
import 'task_detail.dart';
import 'rbac.dart';
import 'socket.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3003');

class TasksScreen extends StatefulWidget {
  final int projectId;
  const TasksScreen({super.key, required this.projectId});
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

import 'socket.dart';

class _TasksScreenState extends State<TasksScreen> {
  Realtime? _rt;
  List<dynamic> _tasks = [];
  List<dynamic> _modules = [];
  Map<String, dynamic>? _md;
  int? _moduleFilter;
  bool _busy = false;
  List<String> _roles = const [];

  Future<String?> _jwt() async => (await SharedPreferences.getInstance()).getString('jwt');

  Future<void> _loadMD() async {
    final md = await fetchMasterData();
    setState(() { _md = md; });
  }

  Future<void> _loadRoles() async {
    final roles = await RBAC.roles();
    setState(() { _roles = roles; });
  }

  Future<void> _load() async {
    setState(() { _busy = true; });
    final jwt = await _jwt();
    final modulesRes = await http.get(Uri.parse('$apiBase/task/api/projects/${widget.projectId}/modules'), headers: { 'Authorization': 'Bearer $jwt' });
    _modules = jsonDecode(modulesRes.body) as List<dynamic>;
    final r = await http.get(Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks'), headers: { 'Authorization': 'Bearer $jwt' });
    final list = jsonDecode(r.body) as List<dynamic>;
    setState(() { _busy = false; _tasks = list; });
  }

  @override
  void initState() {
    super.initState();
    _loadMD();
    _load();
    _loadRoles();
    _rt = Realtime(apiBase);
    _rt!.connect();
    _rt!.on('task.created', (_) => _load());
    _rt!.on('task.updated', (_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final statuses = _md?['statuses'] as List<dynamic>? ?? [];
    final priorities = _md?['priorities'] as List<dynamic>? ?? [];
    final taskTypes = _md?['task_types'] as List<dynamic>? ?? [];

    List<dynamic> filtered = _tasks.where((t) => _moduleFilter == null || t['module_id'] == _moduleFilter).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            const Text('Module:'), const SizedBox(width: 8),
            DropdownButton<int?>(
              value: _moduleFilter,
              items: [const DropdownMenuItem(value: null, child: Text('All')), ..._modules.map((m) => DropdownMenuItem(value: m['id'] as int, child: Text(m['name'])))],
              onChanged: (v) => setState(() => _moduleFilter = v),
            ),
          ]),
          const Divider(),
          if (_busy) const LinearProgressIndicator(),
          Expanded(child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (ctx,i){
              final t = filtered[i];
              return ExpansionTile(
                title: Text(t['title'] ?? ''), subtitle: Text('Task #${t['id']}'),
                trailing: TextButton(onPressed: (){
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskDetailScreen(projectId: widget.projectId, taskId: t['id'] as int)));
                }, child: const Text('Open')),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Description: ${t['description'] ?? ''}'),
                      Row(children:[
                        const Text('Status:'), const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: t['status_id'] as int?,
                          items: [for (final s in statuses) DropdownMenuItem(value: s['id'] as int, child: Text(s['name']))],
                          onChanged: (_roles.contains('Admin') || _roles.contains('Project Manager')) ? (v) async {
                            final jwt = await _jwt();
                            final res = await http.put(Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks/${t['id']}'), headers: { 'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json' }, body: jsonEncode({'status_id': v}));
                            if (res.statusCode==200) _load();
                          } : null,
                        ),
                        const SizedBox(width:16),
                        const Text('Priority:'), const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: t['priority_id'] as int?,
                          items: [for (final p in priorities) DropdownMenuItem(value: p['id'] as int, child: Text(p['name']))],
                          onChanged: (_roles.contains('Admin') || _roles.contains('Project Manager')) ? (v) async {
                            final jwt = await _jwt();
                            final res = await http.put(Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks/${t['id']}'), headers: { 'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json' }, body: jsonEncode({'priority_id': v}));
                            if (res.statusCode==200) _load();
                          } : null,
                        ),
                        const SizedBox(width:16),
                        const Text('Type:'), const SizedBox(width:8),
                        DropdownButton<int>(
                          value: t['task_type_id'] as int?,
                          items: [for (final tp in taskTypes) DropdownMenuItem(value: tp['id'] as int, child: Text(tp['name']))],
                          onChanged: (_roles.contains('Admin') || _roles.contains('Project Manager')) ? (v) async {
                            final jwt = await _jwt();
                            final res = await http.put(Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks/${t['id']}'), headers: { 'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json' }, body: jsonEncode({'task_type_id': v}));
                            if (res.statusCode==200) _load();
                          } : null,
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Row(children:[
                        const Text('Planned end:'), const SizedBox(width: 8), Text('${t['planned_end_date'] ?? '-'}'),
                        const SizedBox(width: 12),
                        OutlinedButton(onPressed: () async {
                          final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
                          if (d != null) {
                            final jwt = await _jwt();
                            final res = await http.put(Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks/${t['id']}'), headers: { 'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json' }, body: jsonEncode({'planned_end_date': d.toIso8601String().substring(0,10)}));
                            if (res.statusCode==200) _load();
                          }
                        }, child: const Text('Change')),
                      ]),
                      const SizedBox(height: 8),
                      Row(children:[
                        ElevatedButton.icon(onPressed: () async {
                          // Timer start: creates a time entry with start now
                          final jwt = await _jwt();
                          await http.post(Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks/${t['id']}/time-entries'), headers: { 'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json' }, body: jsonEncode({'start': DateTime.now().toIso8601String()}));
                          _load();
                        }, icon: const Icon(Icons.play_arrow), label: const Text('Start')),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(onPressed: () async {
                          // Timer stop: update latest time entry by setting end and minutes
                          // For brevity this demo posts a manual entry
                          final jwt = await _jwt();
                          await http.post(Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks/${t['id']}/time-entries'), headers: { 'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json' }, body: jsonEncode({'end': DateTime.now().toIso8601String(), 'minutes': 30, 'notes': 'Manual add'}));
                          _load();
                        }, icon: const Icon(Icons.stop), label: const Text('Stop (demo)')),
                      ]),
                      const SizedBox(height: 8),
                      Row(children:[
                        if (_roles.contains('Admin') || _roles.contains('Project Manager'))
                          ElevatedButton.icon(onPressed: () async {
                            final jwt = await _jwt();
                            await http.delete(Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks/${t['id']}'), headers: { 'Authorization': 'Bearer $jwt' });
                            _load();
                          }, icon: const Icon(Icons.delete), label: const Text('Delete')),
                      ])
                    ]),
                  ),
                ],
              );
            }
          ))
        ]),
      ),
    );
  }
}

