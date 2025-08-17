import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3003');

class AvatarPicker extends StatefulWidget {
  final void Function(String url) onUploaded;
  const AvatarPicker({super.key, required this.onUploaded});
  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  String? _preview;
  bool _busy = false;

  Future<String?> _jwt() async => (await SharedPreferences.getInstance()).getString('jwt');

  Future<void> _pick() async {
    final input = html.FileUploadInputElement()..accept = 'image/*';
    input.click();
    await input.onChange.first;
    if (input.files == null || input.files!.isEmpty) return;
    final file = input.files!.first;
    final jwt = await _jwt();

    setState(() { _busy = true; });
    final presign = await http.post(Uri.parse('$apiBase/task/api/uploads/presign'),
      headers: { 'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json' },
      body: jsonEncode({ 'filename': file.name, 'contentType': file.type })
    );
    final data = jsonDecode(presign.body) as Map<String, dynamic>;
    final url = data['url'] as String;
    final key = data['key'] as String;

    // Read file as bytes for upload
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoadEnd.first;
    final bytes = (reader.result as ByteBuffer).asUint8List();
    await http.put(Uri.parse(url), headers: { 'Content-Type': file.type }, body: bytes);
    final publicUrl = '${apiBase.replaceFirst(RegExp(r"^http"), 'https')}/task/uploads/$key';
    setState(() { _busy = false; _preview = publicUrl; });
    widget.onUploaded(publicUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_preview != null) CircleAvatar(radius: 32, backgroundImage: NetworkImage(_preview!)),
        const SizedBox(height: 8),
        ElevatedButton(onPressed: _busy ? null : _pick, child: Text(_busy ? 'Uploading...' : 'Upload Avatar')),
      ],
    );
  }
}

