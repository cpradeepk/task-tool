import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3003');

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});
  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _nameCtl = TextEditingController();
  final _shortCtl = TextEditingController();
  bool _dark = false;
  bool _busy = false;

  Future<String?> _jwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  Future<void> _load() async {
    setState(() { _busy = true; });
    final jwt = await _jwt();
    final r = await http.get(Uri.parse('$apiBase/task/api/me/profile'), headers: { 'Authorization': 'Bearer $jwt' });
    if (r.statusCode == 200 && r.body.isNotEmpty) {
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      _nameCtl.text = (j['name'] ?? '') as String;
      _shortCtl.text = (j['short_name'] ?? '') as String;
      _dark = (j['theme'] ?? 'light') == 'dark';
    }
    setState(() { _busy = false; });
  }

  Future<void> _save() async {
    setState(() { _busy = true; });
    final jwt = await _jwt();
    final r = await http.put(Uri.parse('$apiBase/task/api/me/profile'),
      headers: { 'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json' },
      body: jsonEncode({ 'name': _nameCtl.text, 'short_name': _shortCtl.text, 'theme': _dark ? 'dark' : 'light' })
    );
    setState(() { _busy = false; });
    if (r.statusCode == 200) {
      if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
    }
  }

  @override
  void initState() { super.initState(); _load(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (_busy) const LinearProgressIndicator(),
            TextField(controller: _nameCtl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: _shortCtl, decoration: const InputDecoration(labelText: 'Short name')),
            Row(children: [ const Text('Dark mode'), Switch(value: _dark, onChanged: (v){ setState(()=>_dark=v); }) ]),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}

