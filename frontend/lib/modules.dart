import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
              return ListTile(
                title: Text(m['name'] ?? ''),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (_roles.contains('Admin') || _roles.contains('Project Manager')) IconButton(icon: const Icon(Icons.edit), onPressed: () async {
                    final c = TextEditingController(text: m['name'] as String? ?? '');
                    final newName = await showDialog<String?>(context: context, builder: (ctx){
                      return AlertDialog(title: const Text('Rename'), content: TextField(controller: c), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Cancel')), TextButton(onPressed: ()=>Navigator.pop(ctx, c.text), child: const Text('Save'))]);
                    });
                    if (newName != null) _rename(m['id'] as int, newName);
                  }),
                  if (_roles.contains('Admin') || _roles.contains('Project Manager')) IconButton(icon: const Icon(Icons.delete), onPressed: () => _delete(m['id'] as int))
                ]),
              );
            }
          ))
        ]),
      ),
    );
  }
}

