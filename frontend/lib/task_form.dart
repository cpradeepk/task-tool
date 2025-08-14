import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'master_data.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3003');

class TaskForm extends StatefulWidget {
  final int projectId;
  const TaskForm({super.key, required this.projectId});
  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  final _titleCtl = TextEditingController();
  final _descCtl = TextEditingController();
  int? _statusId, _priorityId, _taskTypeId;
  DateTime? _plannedEnd;
  Map<String, dynamic>? _md;

  Future<String?> _jwt() async => (await SharedPreferences.getInstance()).getString('jwt');

  Future<void> _loadMD() async {
    final md = await fetchMasterData();
    setState(() { _md = md; });
  }

  Future<void> _save() async {
    final jwt = await _jwt();
    final r = await http.post(Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks'),
      headers: { 'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json' },
      body: jsonEncode({
        'title': _titleCtl.text,
        'description': _descCtl.text,
        'status_id': _statusId,
        'priority_id': _priorityId,
        'task_type_id': _taskTypeId,
        'planned_end_date': _plannedEnd?.toIso8601String().substring(0,10),
      })
    );
    if (r.statusCode == 201) Navigator.of(context).pop(true);
  }

  @override
  void initState() { super.initState(); _loadMD(); }

  @override
  Widget build(BuildContext context) {
    final statuses = _md?['statuses'] as List<dynamic>? ?? [];
    final priorities = _md?['priorities'] as List<dynamic>? ?? [];
    final taskTypes = _md?['task_types'] as List<dynamic>? ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('New Task')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(controller: _titleCtl, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: _descCtl, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: 'Status'),
              value: _statusId,
              items: [for (final s in statuses) DropdownMenuItem(value: s['id'] as int, child: Text(s['name']))],
              onChanged: (v) => setState(() => _statusId = v),
            ),
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: 'Priority'),
              value: _priorityId,
              items: [for (final p in priorities) DropdownMenuItem(value: p['id'] as int, child: Text(p['name']))],
              onChanged: (v) => setState(() => _priorityId = v),
            ),
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: 'Task Type'),
              value: _taskTypeId,
              items: [for (final t in taskTypes) DropdownMenuItem(value: t['id'] as int, child: Text(t['name']))],
              onChanged: (v) => setState(() => _taskTypeId = v),
            ),
            const SizedBox(height: 8),
            Row(children: [
              const Text('Planned end:'),
              const SizedBox(width: 12),
              Text(_plannedEnd == null ? '-' : _plannedEnd!.toIso8601String().substring(0,10)),
              const SizedBox(width: 12),
              OutlinedButton(onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
                if (d != null) setState(() => _plannedEnd = d);
              }, child: const Text('Pick'))
            ]),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _save, child: const Text('Create'))
          ],
        ),
      ),
    );
  }
}

