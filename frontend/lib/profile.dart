import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_avatar.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://task.amtariksha.com');

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});
  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _nameCtl = TextEditingController();
  final _shortCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _telegramCtl = TextEditingController();
  final _whatsappCtl = TextEditingController();
  bool _dark = false;
  bool _busy = false;
  String? _avatarUrl;
  String _font = 'System';
  Color _accent = const Color(0xFF64B5F6);

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
      _phoneCtl.text = (j['phone'] ?? '') as String;
      _telegramCtl.text = (j['telegram'] ?? '') as String;
      _whatsappCtl.text = (j['whatsapp'] ?? '') as String;
      _dark = (j['theme'] ?? 'light') == 'dark';
      _avatarUrl = j['avatar_url'] as String?;
      _font = (j['font'] ?? 'System') as String;
      _accent = Color(int.tryParse((j['accent_color'] ?? '0xFF64B5F6').toString()) ?? 0xFF64B5F6);
    }
    setState(() { _busy = false; });
  }

  Future<void> _save() async {
    setState(() { _busy = true; });
    final jwt = await _jwt();
    final r = await http.put(Uri.parse('$apiBase/task/api/me/profile'),
      headers: { 'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json' },
      body: jsonEncode({
        'name': _nameCtl.text,
        'short_name': _shortCtl.text,
        'phone': _phoneCtl.text,
        'telegram': _telegramCtl.text,
        'whatsapp': _whatsappCtl.text,
        'theme': _dark ? 'dark' : 'light',
        'avatar_url': _avatarUrl,
        'font': _font,
        'accent_color': _accent.toString(),
      })
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
        child: ListView(
          children: [
            if (_busy) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            // Avatar
            // ignore: prefer_const_constructors
            AvatarPicker(onUploaded: (url){ setState(()=>_avatarUrl=url); }),
            const SizedBox(height: 12),
            TextField(controller: _nameCtl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: _shortCtl, decoration: const InputDecoration(labelText: 'Short name')),
            TextField(controller: _phoneCtl, decoration: const InputDecoration(labelText: 'Phone')),
            TextField(controller: _telegramCtl, decoration: const InputDecoration(labelText: 'Telegram')),
            TextField(controller: _whatsappCtl, decoration: const InputDecoration(labelText: 'WhatsApp')),
            Row(children: [ const Text('Dark mode'), Switch(value: _dark, onChanged: (v){ setState(()=>_dark=v); }) ]),
            const SizedBox(height: 8),
            Row(children: [
              const Text('Accent color'),
              const SizedBox(width: 12),
              Container(width: 24, height: 24, decoration: BoxDecoration(color: _accent, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              OutlinedButton(onPressed: () async {
                final c = await showDialog<Color?>(context: context, builder: (ctx){
                  Color tmp = _accent;
                  return AlertDialog(
                    title: const Text('Pick color'),
                    content: StatefulBuilder(builder: (ctx, setS){
                      return Slider(
                        min: 0, max: 360, value: HSVColor.fromColor(tmp).hue,
                        onChanged: (v){ setS((){ tmp = HSVColor.fromAHSV(1, v, 0.5, 0.9).toColor(); }); },
                      );
                    }),
                    actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Cancel')), TextButton(onPressed: ()=>Navigator.pop(ctx, tmp), child: const Text('OK'))],
                  );
                });
                if (c!=null) setState(()=>_accent=c);
              }, child: const Text('Pick'))
            ]),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}

