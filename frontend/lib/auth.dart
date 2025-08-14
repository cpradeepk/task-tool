import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3003');

class AuthController extends ChangeNotifier {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '356275987468-dserls2s2c9ehrfavo68jadfa9envi40.apps.googleusercontent.com',
    scopes: ['email', 'profile', 'openid'],
  );

  String? jwt;
  String? email;

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
      notifyListeners();
    } else {
      throw Exception('Auth failed: ${r.statusCode}');
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    jwt = null;
    email = null;
    notifyListeners();
  }
}

