import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://task.amtariksha.com');

Future<Map<String, dynamic>> fetchMasterData() async {
  final prefs = await SharedPreferences.getInstance();
  final jwt = prefs.getString('jwt');
  Future<List<dynamic>> load(String table) async {
    final r = await http.get(Uri.parse('$apiBase/task/api/master/$table'), headers: { 'Authorization': 'Bearer $jwt' });
    return (jsonDecode(r.body) as List<dynamic>);
  }
  final statuses = await load('statuses');
  final priorities = await load('priorities');
  final taskTypes = await load('task_types');
  final projectTypes = await load('project_types');
  return {
    'statuses': statuses,
    'priorities': priorities,
    'task_types': taskTypes,
    'project_types': projectTypes,
  };
}

