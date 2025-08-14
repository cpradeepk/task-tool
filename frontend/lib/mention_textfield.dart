import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3003');

class MentionTextField extends StatefulWidget {
  final TextEditingController controller;
  final void Function(String value) onSubmitted;
  const MentionTextField({super.key, required this.controller, required this.onSubmitted});
  @override
  State<MentionTextField> createState() => _MentionTextFieldState();
}

class _MentionTextFieldState extends State<MentionTextField> {
  final _focus = FocusNode();
  final _debouncer = Debouncer(const Duration(milliseconds: 250));
  OverlayEntry? _overlay;
  List<String> _suggestions = [];

  Future<String?> _jwt() async => (await SharedPreferences.getInstance()).getString('jwt');

  Future<void> _queryUsers(String q) async {
    if (q.isEmpty) { _hide(); return; }
    final jwt = await _jwt();
    final r = await http.get(Uri.parse('$apiBase/task/api/users?email=$q'), headers: { 'Authorization': 'Bearer $jwt' });
    if (r.statusCode == 200) {
      final list = (jsonDecode(r.body) as List<dynamic>).map((e)=> e['email'] as String).toList();
      setState(() { _suggestions = list.take(8).toList(); });
      _show();
    }
  }

  void _show() {
    _hide();
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset pos = box.localToGlobal(Offset.zero);
    _overlay = OverlayEntry(builder: (ctx) {
      return Positioned(
        left: pos.dx,
        top: pos.dy + box.size.height + 4,
        width: box.size.width,
        child: Material(
          elevation: 4,
          child: ListView(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            children: _suggestions.map((s) => ListTile(title: Text(s), onTap: (){
              final base = widget.controller.text;
              final idx = base.lastIndexOf('@');
              final before = idx >= 0 ? base.substring(0, idx+1) : '$base@';
              final newText = '$before$s';
              widget.controller.text = newText;
              widget.controller.selection = TextSelection.fromPosition(TextPosition(offset: newText.length));
              _hide();
            })).toList(),
          ),
        ),
      );
    });
    Overlay.of(context).insert(_overlay!);
  }

  void _hide() { _overlay?.remove(); _overlay = null; }

  @override
  void dispose() { _hide(); _focus.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return TextField(
      focusNode: _focus,
      controller: widget.controller,
      decoration: const InputDecoration(labelText: 'Write a comment (use @email to mention)'),
      onChanged: (v) {
        final idx = v.lastIndexOf('@');
        if (idx >= 0) {
          final term = v.substring(idx+1).trim();
          _debouncer.run(() => _queryUsers(term));
        } else {
          _hide();
        }
      },
      onSubmitted: (v){ _hide(); widget.onSubmitted(v); },
    );
  }
}

class Debouncer {
  Debouncer(this.duration);
  final Duration duration;
  Timer? _t;
  void run(void Function() f) { _t?.cancel(); _t = Timer(duration, f); }
}

