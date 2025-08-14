import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3003');

class AuthController extends ChangeNotifier {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile', 'openid'],
  );

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
    final account = await _googleSignIn.signIn();
    if (account == null) return; // cancelled

    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      throw Exception('Google ID token missing');
    }

    final r = await http.post(Uri.parse('$apiBase/task/api/auth/session'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}));
    if (r.statusCode == 200) {
      final body = jsonDecode(r.body);
      jwt = body['token'];
      email = body['user']['email'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt', jwt!);
      await prefs.setString('email', email!);
      notifyListeners();
    } else {
      throw Exception('Auth failed: ${r.statusCode}');
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    jwt = null;
    email = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt');
    await prefs.remove('email');
    notifyListeners();
  }
}

