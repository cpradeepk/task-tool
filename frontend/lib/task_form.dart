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
  int? _statusId, _priorityId, _taskTypeId, _moduleId;
  DateTime? _plannedEnd;
  Map<String, dynamic>? _md;
  List<dynamic> _modules = [];

  Future<String?> _jwt() async => (await SharedPreferences.getInstance()).getString('jwt');

  Future<void> _loadMD() async {
    final md = await fetchMasterData();
    setState(() { _md = md; });
  }

  Future<void> _loadModules() async {
    final jwt = await _jwt();
    if (jwt == null) return;

    try {
      final response = await http.get(
        Uri.parse('$apiBase/task/api/projects/${widget.projectId}/modules'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        final modules = jsonDecode(response.body) as List;
        setState(() => _modules = modules);
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _save() async {
    // Validate required fields
    if (_titleCtl.text.isEmpty) {
      _showError('Title is required');
      return;
    }
    if (_moduleId == null) {
      _showError('Please select a module - tasks must be created within a module');
      return;
    }

    final jwt = await _jwt();
    final r = await http.post(Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks'),
      headers: { 'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json' },
      body: jsonEncode({
        'title': _titleCtl.text,
        'description': _descCtl.text,
        'module_id': _moduleId,
        'status_id': _statusId,
        'priority_id': _priorityId,
        'task_type_id': _taskTypeId,
        'planned_end_date': _plannedEnd?.toIso8601String().substring(0,10),
      })
    );

    if (r.statusCode == 201) {
      if (mounted) Navigator.of(context).pop(true);
    } else {
      final error = jsonDecode(r.body);
      _showError(error['error'] ?? 'Failed to create task');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMD();
    _loadModules();
  }

  @override
  Widget build(BuildContext context) {
    final statuses = _md?['statuses'] as List<dynamic>? ?? [];
    final priorities = _md?['priorities'] as List<dynamic>? ?? [];
    final taskTypes = _md?['task_types'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Task'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // Hierarchy Notice
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tasks must be created within a module to maintain proper project hierarchy',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),

            // Module Selection (Required)
            DropdownButtonFormField<int>(
              decoration: InputDecoration(
                labelText: 'Module *',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.view_module),
                helperText: 'Select the module this task belongs to',
                errorText: _moduleId == null ? 'Module selection is required' : null,
              ),
              value: _moduleId,
              items: [
                for (final module in _modules)
                  DropdownMenuItem(
                    value: module['id'] as int,
                    child: Text(module['name'] ?? 'Unnamed Module')
                  )
              ],
              onChanged: (v) => setState(() => _moduleId = v),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _titleCtl,
              decoration: const InputDecoration(
                labelText: 'Title *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              )
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descCtl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              )
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.flag),
              ),
              value: _statusId,
              items: [for (final s in statuses) DropdownMenuItem(value: s['id'] as int, child: Text(s['name']))],
              onChanged: (v) => setState(() => _statusId = v),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(
                labelText: 'Priority',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.priority_high),
              ),
              value: _priorityId,
              items: [for (final p in priorities) DropdownMenuItem(value: p['id'] as int, child: Text(p['name']))],
              onChanged: (v) => setState(() => _priorityId = v),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(
                labelText: 'Task Type',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              value: _taskTypeId,
              items: [for (final t in taskTypes) DropdownMenuItem(value: t['id'] as int, child: Text(t['name']))],
              onChanged: (v) => setState(() => _taskTypeId = v),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Planned End Date', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _plannedEnd == null
                            ? 'No date selected'
                            : _plannedEnd!.toIso8601String().substring(0,10),
                          style: TextStyle(
                            color: _plannedEnd == null ? Colors.grey : Colors.black,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _plannedEnd ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100)
                          );
                          if (d != null) setState(() => _plannedEnd = d);
                        },
                        icon: const Icon(Icons.date_range),
                        label: Text(_plannedEnd == null ? 'Select Date' : 'Change Date'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Task'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

