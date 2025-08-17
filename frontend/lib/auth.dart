import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3003');

class AuthController extends ChangeNotifier {
  String? jwt;
  String? email;

  bool get isAuthed => jwt != null;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    jwt = prefs.getString('jwt');
    email = prefs.getString('email');
    notifyListeners();
  }

  Future<void> signIn() async {
    // Simple auth for testing - backend now accepts this test token
    email = 'test@swargfood.com';
    jwt = 'test-jwt-token';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt', jwt!);
    await prefs.setString('email', email!);
    notifyListeners();
  }

  Future<void> signOut() async {
    jwt = null;
    email = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt');
    await prefs.remove('email');
    notifyListeners();
  }
}

