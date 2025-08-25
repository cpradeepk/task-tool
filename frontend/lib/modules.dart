import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'rbac.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://task.amtariksha.com');

class ModulesScreen extends StatefulWidget {
  final int projectId;
  const ModulesScreen({super.key, required this.projectId});
  @override
  State<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends State<ModulesScreen> {
  List<dynamic> _modules = [];
  bool _busy = false;
  final _nameCtl = TextEditingController();
  List<String> _roles = const [];

  Future<String?> _jwt() async => (await SharedPreferences.getInstance()).getString('jwt');

  Future<void> _load() async {
    setState(() { _busy = true; });
    final jwt = await _jwt();
    final r = await http.get(Uri.parse('$apiBase/task/api/projects/${widget.projectId}/modules'), headers: { 'Authorization': 'Bearer $jwt' });
    setState(() { _busy = false; _modules = jsonDecode(r.body) as List<dynamic>; });
  }

  Future<void> _create() async {
    final jwt = await _jwt();
    await http.post(Uri.parse('$apiBase/task/api/projects/${widget.projectId}/modules'), headers: { 'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json' }, body: jsonEncode({ 'name': _nameCtl.text }));
    _nameCtl.clear();
    _load();
  }

  Future<void> _rename(int id, String name) async {
    final jwt = await _jwt();
    await http.put(Uri.parse('$apiBase/task/api/projects/${widget.projectId}/modules/$id'), headers: { 'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json' }, body: jsonEncode({ 'name': name }));
    _load();
  }

  Future<void> _delete(int id) async {
    final jwt = await _jwt();
    await http.delete(Uri.parse('$apiBase/task/api/projects/${widget.projectId}/modules/$id'), headers: { 'Authorization': 'Bearer $jwt' });
    _load();
  }

  Future<void> _loadRoles() async {
    final roles = await RBAC.roles();
    setState(() { _roles = roles; });
  }

  void _confirmDelete(Map<String, dynamic> module) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Module'),
        content: Text('Are you sure you want to delete "${module['name']}"?\n\nThis action cannot be undone and will remove all associated tasks.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _delete(module['id'] as int);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE6920E)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showCreateTaskDialog(Map<String, dynamic> module) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create Task in ${module['name']}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Task Title *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Task Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                Navigator.of(context).pop();
                _createTask(module['id'] as int, titleController.text.trim(), descriptionController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA301)),
            child: const Text('Create Task'),
          ),
        ],
      ),
    );
  }

  Future<void> _createTask(int moduleId, String title, String description) async {
    try {
      final jwt = await _jwt();
      final response = await http.post(
        Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'title': title,
          'description': description,
          'module_id': moduleId,
        }),
      );

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task created successfully'),
              backgroundColor: Color(0xFFFFA301),
            ),
          );
          // Navigate to the tasks page for this module
          context.go('/projects/${widget.projectId}/modules/$moduleId');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create task: ${response.statusCode}'),
              backgroundColor: const Color(0xFFE6920E),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating task: $e'),
            backgroundColor: const Color(0xFFE6920E),
          ),
        );
      }
    }
  }

  @override
  void initState() { super.initState(); _loadRoles(); _load(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modules')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [ Expanded(child: TextField(controller: _nameCtl, decoration: const InputDecoration(labelText: 'New module'))), const SizedBox(width: 8), if (_roles.contains('Admin') || _roles.contains('Project Manager')) ElevatedButton(onPressed: _create, child: const Text('Add')) ]),
          const Divider(),
          if (_busy) const LinearProgressIndicator(),
          Expanded(child: ListView.builder(
            itemCount: _modules.length,
            itemBuilder: (ctx,i){
              final m = _modules[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.view_module, color: Color(0xFFFFA301)),
                  title: Text(m['name'] ?? ''),
                  subtitle: Text('Module ID: ${m['id']}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    // View Tasks Button
                    IconButton(
                      icon: const Icon(Icons.task_alt, color: Color(0xFFFFA301)),
                      tooltip: 'View Tasks',
                      onPressed: () {
                        context.go('/projects/${widget.projectId}/modules/${m['id']}');
                      },
                    ),
                    // Create Task Button
                    IconButton(
                      icon: const Icon(Icons.add_task, color: Color(0xFFFFA301)),
                      tooltip: 'Create Task',
                      onPressed: () {
                        _showCreateTaskDialog(m);
                      },
                    ),
                    if (_roles.contains('Admin') || _roles.contains('Project Manager')) IconButton(
                      icon: const Icon(Icons.edit, color: Color(0xFFFFA301)),
                      tooltip: 'Edit Module',
                      onPressed: () async {
                        final c = TextEditingController(text: m['name'] as String? ?? '');
                        final newName = await showDialog<String?>(context: context, builder: (ctx){
                          return AlertDialog(
                            title: const Text('Rename Module'),
                            content: TextField(
                              controller: c,
                              decoration: const InputDecoration(
                                labelText: 'Module Name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            actions: [
                              TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Cancel')),
                              ElevatedButton(
                                onPressed: ()=>Navigator.pop(ctx, c.text),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA301)),
                                child: const Text('Save'),
                              ),
                            ],
                          );
                        });
                        if (newName != null && newName.trim().isNotEmpty) _rename(m['id'] as int, newName.trim());
                      }
                    ),
                    if (_roles.contains('Admin') || _roles.contains('Project Manager')) IconButton(
                      icon: const Icon(Icons.delete, color: Color(0xFFE6920E)),
                      tooltip: 'Delete Module',
                      onPressed: () => _confirmDelete(m),
                    )
                  ]),
                ),
              );
            }
          ))
        ]),
      ),
    );
  }
}

