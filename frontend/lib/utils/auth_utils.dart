import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Utility functions for authentication management
class AuthUtils {
  /// Check if JWT token is expired
  static bool isTokenExpired(String token) {
    try {
      // JWT tokens have 3 parts separated by dots
      final parts = token.split('.');
      if (parts.length != 3) return true;
      
      // Decode the payload (second part)
      final payload = parts[1];
      
      // Add padding if needed for base64 decoding
      String normalizedPayload = payload;
      switch (payload.length % 4) {
        case 1:
          normalizedPayload += '===';
          break;
        case 2:
          normalizedPayload += '==';
          break;
        case 3:
          normalizedPayload += '=';
          break;
      }
      
      final decodedBytes = base64Url.decode(normalizedPayload);
      final decodedPayload = utf8.decode(decodedBytes);
      final payloadMap = jsonDecode(decodedPayload);
      
      // Check expiration time
      final exp = payloadMap['exp'];
      if (exp == null) return true;
      
      final expirationTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      final now = DateTime.now();
      
      return now.isAfter(expirationTime);
    } catch (e) {
      // If we can't decode the token, consider it expired
      return true;
    }
  }
  
  /// Clear all authentication data from SharedPreferences
  static Future<void> clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt');
    await prefs.remove('email');
    await prefs.remove('user_email');
    await prefs.remove('isAdmin');
    await prefs.remove('is_admin');
  }
  
  /// Check if current stored token is valid
  static Future<bool> isCurrentTokenValid() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt');
    
    if (token == null) return false;
    
    return !isTokenExpired(token);
  }
  
  /// Clear auth data if token is expired
  static Future<bool> clearIfExpired() async {
    final isValid = await isCurrentTokenValid();
    if (!isValid) {
      await clearAuthData();
      return true; // Token was expired and cleared
    }
    return false; // Token is still valid
  }
  
  /// Get current user info from stored JWT token
  static Future<Map<String, dynamic>?> getCurrentUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt');
    
    if (token == null || isTokenExpired(token)) {
      return null;
    }
    
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      
      final payload = parts[1];
      String normalizedPayload = payload;
      switch (payload.length % 4) {
        case 1:
          normalizedPayload += '===';
          break;
        case 2:
          normalizedPayload += '==';
          break;
        case 3:
          normalizedPayload += '=';
          break;
      }
      
      final decodedBytes = base64Url.decode(normalizedPayload);
      final decodedPayload = utf8.decode(decodedBytes);
      return jsonDecode(decodedPayload);
    } catch (e) {
      return null;
    }
  }
}
