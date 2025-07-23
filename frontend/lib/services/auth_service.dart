import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class AuthService {
  static Future<Map<String, dynamic>> loginWithGoogle(String googleToken) async {
    try {
      final response = await ApiService.post('/auth/google', {
        'token': googleToken,
      });
      
      if (response['tokens'] != null) {
        await ApiService.saveToken(response['tokens']['accessToken']);
      }
      
      return response;
    } catch (e) {
      throw Exception('Google login failed: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      final response = await ApiService.post('/auth/refresh', {
        'refreshToken': refreshToken,
      });
      
      if (response['tokens'] != null) {
        await ApiService.saveToken(response['tokens']['accessToken']);
      }
      
      return response;
    } catch (e) {
      throw Exception('Token refresh failed: ${e.toString()}');
    }
  }

  static Future<void> logout() async {
    try {
      await ApiService.post('/auth/logout', {});
    } catch (e) {
      // Continue with logout even if API call fails
    } finally {
      await ApiService.removeToken();
    }
  }

  static Future<String?> getToken() async {
    return await ApiService.getToken();
  }

  static Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      return await ApiService.get('/auth/me');
    } catch (e) {
      throw Exception('Failed to get current user: ${e.toString()}');
    }
  }

  // Demo login that simulates backend response
  static Future<Map<String, dynamic>> loginDemo() async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    
    // Return mock response matching your backend structure
    return {
      'message': 'Login successful',
      'user': {
        'id': 'demo-user-id',
        'email': 'demo@example.com',
        'name': 'Demo User',
        'profilePicture': null,
        'isAdmin': false,
        'preferences': {
          'theme': 'light',
          'notifications': true,
          'language': 'en'
        }
      },
      'tokens': {
        'accessToken': 'demo-token-${DateTime.now().millisecondsSinceEpoch}',
        'refreshToken': 'demo-refresh-token-${DateTime.now().millisecondsSinceEpoch}'
      }
    };
  }
}
