import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  String? _token;
  bool _isLoading = false;

  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null && _user != null;

  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.login(email, password);
      _token = response['token'];
      _user = User.fromJson(response['user']);
      
      await _saveTokenToStorage(_token!);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> setUserFromDemo(Map<String, dynamic> demoResponse) async {
    _token = demoResponse['tokens']['accessToken'];
    _user = User.fromJson(demoResponse['user']);
    
    // Save token to API service and storage
    await ApiService.saveToken(_token!);
    await _saveTokenToStorage(_token!);
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    
    notifyListeners();
  }

  Future<void> loadTokenFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    
    if (_token != null) {
      try {
        // For demo tokens, create a demo user
        if (_token!.startsWith('demo-token-')) {
          _user = User(
            id: 'demo-user-id',
            email: 'demo@example.com',
            name: 'Demo User',
            isAdmin: false,
            isActive: true,
          );
          notifyListeners();
        } else {
          final userResponse = await ApiService.getCurrentUser(_token!);
          _user = User.fromJson(userResponse);
          notifyListeners();
        }
      } catch (e) {
        await logout();
      }
    }
  }

  Future<void> _saveTokenToStorage(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }
}
