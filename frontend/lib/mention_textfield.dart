import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3003');

class MentionTextField extends StatefulWidget {
  final TextEditingController controller;
  final void Function(String value) onSubmitted;
  final Future<List<String>> Function(String term)? searchFn;
  const MentionTextField({super.key, required this.controller, required this.onSubmitted, this.searchFn});
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
    if (widget.searchFn != null) {
      final list = await widget.searchFn!(q);
      setState(() { _suggestions = list.take(8).toList(); });
      _show();
      return;
    }
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
      return Stack(children: [
        Positioned.fill(child: GestureDetector(onTap: _hide, child: Container(color: Colors.transparent))),
        Positioned(
          left: pos.dx,
          top: pos.dy + box.size.height + 4,
          width: box.size.width,
          child: Material(
            elevation: 4,
            child: _SuggestionList(
              suggestions: _suggestions,
              onPick: (s){ _insertSuggestion(s); },
              onCancel: _hide,
            ),
          ),
        )
      ]);
    });
    Overlay.of(context).insert(_overlay!);
  }

  void _insertSuggestion(String s) {
    final base = widget.controller.text;
    final sel = widget.controller.selection;
    final caret = sel.start;
    final lastAt = base.lastIndexOf('@', caret >= 0 ? caret : base.length);
    final before = lastAt >= 0 ? base.substring(0, lastAt+1) : '${base.substring(0, caret)}@';
    final after = base.substring(caret);
    final newText = '$before$s$after';
    widget.controller.text = newText;
    final newOffset = (before + s).length;
    widget.controller.selection = TextSelection.fromPosition(TextPosition(offset: newOffset));
    _hide();
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


class _SuggestionList extends StatefulWidget {
  const _SuggestionList({required this.suggestions, required this.onPick, this.onCancel});
  final List<String> suggestions; final void Function(String) onPick; final VoidCallback? onCancel;
  @override State<_SuggestionList> createState() => _SuggestionListState();
}
class _SuggestionListState extends State<_SuggestionList> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (e) {
        if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.arrowDown) setState(()=>_index = (_index+1)%widget.suggestions.length);
        if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.arrowUp) setState(()=>_index = (_index-1+widget.suggestions.length)%widget.suggestions.length);
        if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.enter) widget.onPick(widget.suggestions[_index]);
      },
      child: ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: widget.suggestions.length,
        itemBuilder: (ctx,i){
          final s = widget.suggestions[i];
          return ListTile(
            selected: i==_index,
            title: Text(s),
            onTap: ()=>widget.onPick(s),
          );
        },
      ),
    );
  }
}
