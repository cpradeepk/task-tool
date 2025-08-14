import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'master_data.dart';
import 'socket.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3003');

class TaskDetailScreen extends StatefulWidget {
  final int projectId;
  final int taskId;
  const TaskDetailScreen({super.key, required this.projectId, required this.taskId});
  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

import 'socket.dart';

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  Realtime? _rt;
  Map<String, dynamic>? _task;
  Map<String, dynamic>? _md;
  List<dynamic> _assignments = [];
  List<dynamic> _timeEntries = [];
  List<dynamic> _deps = [];
  Map<String, dynamic>? _pert;
  List<dynamic> _users = [];
  final _commentCtl = TextEditingController();
  final _messageCtl = TextEditingController();
  int? _threadId;

  Future<String?> _jwt() async => (await SharedPreferences.getInstance()).getString('jwt');

  Future<void> _loadMD() async { setState((){}); _md = await fetchMasterData(); }

  Future<void> _ensureThread() async {
    final jwt = await _jwt();
    final r = await http.post(Uri.parse('$apiBase/task/api/chat/threads'), headers: { 'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json' }, body: jsonEncode({'scope':'TASK','scope_id': widget.taskId}));
    final row = jsonDecode(r.body) as Map<String, dynamic>;
    _threadId = row['id'] as int?;
  }

  List<dynamic> _messages = [];

  Future<void> _load() async {
    final jwt = await _jwt();
    final tRes = await http.get(Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks'), headers: { 'Authorization': 'Bearer $jwt' });
    final tasks = jsonDecode(tRes.body) as List<dynamic>;
    _task = tasks.firstWhere((e) => e['id'] == widget.taskId);

    final aRes = await http.get(Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks/${widget.taskId}/time-entries'), headers: { 'Authorization': 'Bearer $jwt' });
    _timeEntries = jsonDecode(aRes.body) as List<dynamic>;

    final dRes = await http.get(Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks/${widget.taskId}/dependencies'), headers: { 'Authorization': 'Bearer $jwt' });
    _deps = jsonDecode(dRes.body) as List<dynamic>;

    final pRes = await http.get(Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks/${widget.taskId}/pert'), headers: { 'Authorization': 'Bearer $jwt' });
    _pert = jsonDecode(pRes.body) as Map<String, dynamic>?;

    if (_threadId != null) {
      final mRes = await http.get(Uri.parse('$apiBase/task/api/chat/threads/$_threadId/messages'), headers: { 'Authorization': 'Bearer $jwt' });
      _messages = jsonDecode(mRes.body) as List<dynamic>;
    }

    setState((){});
  }

  Future<void> _searchUsers(String q) async {
    final jwt = await _jwt();
    final r = await http.get(Uri.parse('$apiBase/task/api/users?email=$q'), headers: { 'Authorization': 'Bearer $jwt' });
    _users = jsonDecode(r.body) as List<dynamic>;
    setState((){});
  }

  Future<void> _assign(int userId, {bool owner=false}) async {
    final jwt = await _jwt();
    await http.post(Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks/${widget.taskId}/assignments'), headers: { 'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json' }, body: jsonEncode({'user_id': userId, 'is_owner': owner}));
    _load();
  }

  Future<void> _addDep(int dependsOnTaskId, String type) async {
    final jwt = await _jwt();
    await http.post(Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks/${widget.taskId}/dependencies'), headers: { 'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json' }, body: jsonEncode({'depends_on_task_id': dependsOnTaskId, 'type': type}));
    _load();
  }

  Future<void> _savePert(int o, int m, int p) async {
    final jwt = await _jwt();
    await http.post(Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks/${widget.taskId}/pert'), headers: { 'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json' }, body: jsonEncode({'optimistic': o, 'most_likely': m, 'pessimistic': p}));
    _load();
  }

  @override
  void initState() {
    super.initState();
    _loadMD();
    _ensureThread().then((_) => _load());
    _rt = Realtime(apiBase);
    _rt!.connect();
    _rt!.on('task.updated', (_) => _load());
    _rt!.on('chat.message', (_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final statuses = _md?['statuses'] as List<dynamic>? ?? [];
    final priorities = _md?['priorities'] as List<dynamic>? ?? [];
    final taskTypes = _md?['task_types'] as List<dynamic>? ?? [];
    final t = _task;

    return Scaffold(
      appBar: AppBar(title: const Text('Task Detail')),
      body: t == null ? const Center(child: CircularProgressIndicator()) : Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(children: [
          Text('Title: ${t['title'] ?? ''}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children:[
            const Text('Status:'), const SizedBox(width: 8),
            DropdownButton<int>(value: t['status_id'] as int?, items: [for (final s in statuses) DropdownMenuItem(value: s['id'] as int, child: Text(s['name']))], onChanged: (v) async {
              final jwt = await _jwt();
              final res = await http.put(Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks/${t['id']}'), headers: { 'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json' }, body: jsonEncode({'status_id': v}));
              if (res.statusCode==200) _load();
            }),
            const SizedBox(width: 16),
            const Text('Priority:'), const SizedBox(width: 8),
            DropdownButton<int>(value: t['priority_id'] as int?, items: [for (final p in priorities) DropdownMenuItem(value: p['id'] as int, child: Text(p['name']))], onChanged: (v) async {
              final jwt = await _jwt();
              final res = await http.put(Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks/${t['id']}'), headers: { 'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json' }, body: jsonEncode({'priority_id': v}));
              if (res.statusCode==200) _load();
            }),
            const SizedBox(width: 16),
            const Text('Type:'), const SizedBox(width: 8),
            DropdownButton<int>(value: t['task_type_id'] as int?, items: [for (final ty in taskTypes) DropdownMenuItem(value: ty['id'] as int, child: Text(ty['name']))], onChanged: (v) async {
              final jwt = await _jwt();
              final res = await http.put(Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks/${t['id']}'), headers: { 'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json' }, body: jsonEncode({'task_type_id': v}));
              if (res.statusCode==200) _load();
            }),
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
          const Divider(height: 24),
          // Assignments
          Text('Assignments', style: Theme.of(context).textTheme.titleMedium),
          Row(children:[
            Expanded(child: TextField(controller: _commentCtl, decoration: const InputDecoration(labelText: 'Search user by email'))),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: () => _searchUsers(_commentCtl.text), child: const Text('Search')),
          ]),
          Wrap(children: _users.map((u) => Padding(padding: const EdgeInsets.all(4), child: OutlinedButton(onPressed: ()=>_assign(u['id'] as int), child: Text(u['email'])))).toList()),
          const SizedBox(height: 8),
          Row(children:[TextButton(onPressed: (){ if(_users.isNotEmpty) _assign(_users.first['id'] as int, owner: true); }, child: const Text('Set first result as owner'))]),
          const Divider(height: 24),
          // Time entries list
          Text('Time entries', style: Theme.of(context).textTheme.titleMedium),
          ..._timeEntries.map((e) => ListTile(
            title: Text('${e['minutes'] ?? '-'} min - ${e['email'] ?? ''}'),
            subtitle: Text(e['notes'] ?? ''),
            trailing: Wrap(spacing: 8, children: [
              IconButton(icon: const Icon(Icons.edit), onPressed: () async {
                final c = TextEditingController(text: (e['minutes'] ?? '').toString());
                final n = TextEditingController(text: e['notes'] ?? '');
                final ok = await showDialog<bool>(context: context, builder: (ctx){
                  return AlertDialog(title: const Text('Edit entry'), content: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(controller: c, decoration: const InputDecoration(labelText: 'Minutes'), keyboardType: TextInputType.number),
                    TextField(controller: n, decoration: const InputDecoration(labelText: 'Notes')),
                  ]), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx,false), child: const Text('Cancel')), TextButton(onPressed: ()=>Navigator.pop(ctx,true), child: const Text('Save'))]);
                });
                if (ok==true) {
                  final jwt = await _jwt();
                  await http.put(Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks/${widget.taskId}/time-entries/${e['id']}'), headers: { 'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json' }, body: jsonEncode({'minutes': int.tryParse(c.text) ?? e['minutes'], 'notes': n.text}));
                  _load();
                }
              }),
              IconButton(icon: const Icon(Icons.delete), onPressed: () async {
                final jwt = await _jwt();
                await http.delete(Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks/${widget.taskId}/time-entries/${e['id']}'), headers: { 'Authorization': 'Bearer $jwt' });
                _load();
              })
            ]),
          )),
          Row(children:[
            ElevatedButton.icon(onPressed: () async {
              final jwt = await _jwt();
              await http.post(Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks/${widget.taskId}/time-entries'), headers: { 'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json' }, body: jsonEncode({'start': DateTime.now().toIso8601String(), 'notes': 'Started'}));
              _load();
            }, icon: const Icon(Icons.play_arrow), label: const Text('Start')),
            const SizedBox(width: 8),
            ElevatedButton.icon(onPressed: () async {
              final jwt = await _jwt();
              await http.put(Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks/${widget.taskId}/time-entries/stop'), headers: { 'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json' });
              _load();
            }, icon: const Icon(Icons.stop), label: const Text('Stop')),
          ]),
          const Divider(height: 24),
          // Comments
          Text('Comments', style: Theme.of(context).textTheme.titleMedium),
          Column(children: [
            ..._messages.map((m) => ListTile(title: Text(m['email'] ?? 'Unknown'), subtitle: Text(m['body'] ?? ''))),
            Row(children:[Expanded(child: TextField(controller: _messageCtl, decoration: const InputDecoration(labelText: 'Write a comment (use @email to mention)'))), const SizedBox(width: 8), ElevatedButton(onPressed: () async {
              if (_threadId == null) return; final jwt = await _jwt();
              await http.post(Uri.parse('$apiBase/task/api/chat/threads/$_threadId/messages'), headers: { 'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json' }, body: jsonEncode({'kind':'text','body': _messageCtl.text}));
              _messageCtl.clear();
              _load();
            }, child: const Text('Post'))])
          ]),
          const Divider(height: 24),
          // Dependencies
          Text('Dependencies', style: Theme.of(context).textTheme.titleMedium),
          ..._deps.map((d) => ListTile(title: Text('Depends on task ${d['depends_on_task_id']}'), subtitle: Text(d['type']))),
          Row(children:[
            ElevatedButton(onPressed: () async {
              final idCtl = TextEditingController();
              final type = await showDialog<String?>(context: context, builder: (ctx){
                String? pickedType = 'PRE';
                return AlertDialog(title: const Text('Add dependency'), content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(controller: idCtl, decoration: const InputDecoration(labelText: 'Depends on Task ID')),
                  DropdownButton<String>(value: pickedType, items: const [DropdownMenuItem(value:'PRE', child: Text('PRE')), DropdownMenuItem(value:'POST', child: Text('POST'))], onChanged: (v){ pickedType = v; }),
                ]), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Cancel')), TextButton(onPressed: ()=>Navigator.pop(ctx, pickedType), child: const Text('Add'))]);
              });
              if (type!=null) _addDep(int.tryParse(idCtl.text) ?? 0, type);
            }, child: const Text('Add dependency')),
          ]),
          const Divider(height: 24),
          // PERT
          Text('PERT', style: Theme.of(context).textTheme.titleMedium),
          Text('Current: ${_pert ?? {}}'),
          Row(children:[
            ElevatedButton(onPressed: () async {
              final oCtl = TextEditingController(text: (_pert?['optimistic'] ?? 1).toString());
              final mCtl = TextEditingController(text: (_pert?['most_likely'] ?? 1).toString());
              final pCtl = TextEditingController(text: (_pert?['pessimistic'] ?? 1).toString());
              final ok = await showDialog<bool>(context: context, builder: (ctx){
                return AlertDialog(title: const Text('Set PERT'), content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(controller: oCtl, decoration: const InputDecoration(labelText: 'Optimistic'), keyboardType: TextInputType.number),
                  TextField(controller: mCtl, decoration: const InputDecoration(labelText: 'Most likely'), keyboardType: TextInputType.number),
                  TextField(controller: pCtl, decoration: const InputDecoration(labelText: 'Pessimistic'), keyboardType: TextInputType.number),
                ]), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx,false), child: const Text('Cancel')), TextButton(onPressed: ()=>Navigator.pop(ctx,true), child: const Text('Save'))]);
              });
              if (ok==true) _savePert(int.tryParse(oCtl.text) ?? 1, int.tryParse(mCtl.text) ?? 1, int.tryParse(pCtl.text) ?? 1);
            }, child: const Text('Set PERT')),
          ]),
          const SizedBox(height: 40),
        ])
      ),
    );
  }
}

