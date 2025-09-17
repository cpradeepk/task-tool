import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://task.amtariksha.com');

class RBAC {
  static Future<List<String>> roles() async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString('jwt');
    final r = await http.get(Uri.parse('$apiBase/task/api/me/roles'), headers: { 'Authorization': 'Bearer $jwt' });
    if (r.statusCode==200) return (jsonDecode(r.body) as List).map((e)=>e.toString()).toList();
    return [];
  }
}

