import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/error_handler.dart';
import '../utils/auth_utils.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://task.amtariksha.com');

/// Centralized API service with consistent error handling and authentication
class ApiService {
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 1);

  /// Get JWT token from SharedPreferences, clearing if expired
  static Future<String?> _getJwt() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt');

    if (token != null && AuthUtils.isTokenExpired(token)) {
      // Clear expired token
      await AuthUtils.clearAuthData();
      return null;
    }

    return token;
  }

  /// Get default headers with authentication
  static Future<Map<String, String>> _getHeaders({
    bool includeContentType = true,
  }) async {
    final jwt = await _getJwt();
    final headers = <String, String>{};
    
    if (jwt != null) {
      headers['Authorization'] = 'Bearer $jwt';
    }
    
    if (includeContentType) {
      headers['Content-Type'] = 'application/json';
    }
    
    return headers;
  }

  /// Make a GET request with error handling and retries
  static Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, String>? queryParams,
    Duration? timeout,
    int? maxRetries,
  }) async {
    return _makeRequest<T>(
      'GET',
      endpoint,
      queryParams: queryParams,
      timeout: timeout,
      maxRetries: maxRetries,
    );
  }

  /// Make a POST request with error handling and retries
  static Future<ApiResponse<T>> post<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    Duration? timeout,
    int? maxRetries,
  }) async {
    return _makeRequest<T>(
      'POST',
      endpoint,
      body: body,
      queryParams: queryParams,
      timeout: timeout,
      maxRetries: maxRetries,
    );
  }

  /// Make a PUT request with error handling and retries
  static Future<ApiResponse<T>> put<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    Duration? timeout,
    int? maxRetries,
  }) async {
    return _makeRequest<T>(
      'PUT',
      endpoint,
      body: body,
      queryParams: queryParams,
      timeout: timeout,
      maxRetries: maxRetries,
    );
  }

  /// Make a DELETE request with error handling and retries
  static Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    Map<String, String>? queryParams,
    Duration? timeout,
    int? maxRetries,
  }) async {
    return _makeRequest<T>(
      'DELETE',
      endpoint,
      queryParams: queryParams,
      timeout: timeout,
      maxRetries: maxRetries,
    );
  }

  /// Internal method to make HTTP requests with comprehensive error handling
  static Future<ApiResponse<T>> _makeRequest<T>(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    Duration? timeout,
    int? maxRetries,
  }) async {
    final effectiveTimeout = timeout ?? _defaultTimeout;
    final effectiveMaxRetries = maxRetries ?? _maxRetries;
    
    // Build URL
    var url = endpoint.startsWith('http') ? endpoint : '$apiBase$endpoint';
    if (queryParams != null && queryParams.isNotEmpty) {
      final uri = Uri.parse(url);
      url = uri.replace(queryParameters: {
        ...uri.queryParameters,
        ...queryParams,
      }).toString();
    }

    Exception? lastException;
    
    // Retry logic
    for (int attempt = 0; attempt <= effectiveMaxRetries; attempt++) {
      try {
        final headers = await _getHeaders();
        http.Response response;

        switch (method.toUpperCase()) {
          case 'GET':
            response = await http.get(
              Uri.parse(url),
              headers: headers,
            ).timeout(effectiveTimeout);
            break;
          case 'POST':
            response = await http.post(
              Uri.parse(url),
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            ).timeout(effectiveTimeout);
            break;
          case 'PUT':
            response = await http.put(
              Uri.parse(url),
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            ).timeout(effectiveTimeout);
            break;
          case 'DELETE':
            response = await http.delete(
              Uri.parse(url),
              headers: headers,
            ).timeout(effectiveTimeout);
            break;
          default:
            throw ArgumentError('Unsupported HTTP method: $method');
        }

        // Handle response
        if (response.statusCode >= 200 && response.statusCode < 300) {
          // Success
          dynamic data;
          if (response.body.isNotEmpty) {
            try {
              data = jsonDecode(response.body);
            } catch (e) {
              // If JSON parsing fails, return raw body
              data = response.body;
            }
          }
          
          return ApiResponse<T>.success(
            data: data as T?,
            statusCode: response.statusCode,
            message: 'Request successful',
          );
        } else {
          // HTTP error
          String errorMessage = 'Request failed';
          try {
            final errorBody = jsonDecode(response.body);
            if (errorBody is Map<String, dynamic> && errorBody.containsKey('error')) {
              errorMessage = errorBody['error'].toString();
            }
          } catch (e) {
            errorMessage = _getStatusCodeMessage(response.statusCode);
          }

          return ApiResponse<T>.error(
            message: errorMessage,
            statusCode: response.statusCode,
            exception: HttpException(errorMessage, response.statusCode),
          );
        }
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        
        // Don't retry on certain errors
        if (e is TimeoutException || 
            (e.toString().contains('socket') && attempt < effectiveMaxRetries)) {
          // Wait before retry
          if (attempt < effectiveMaxRetries) {
            await Future.delayed(_retryDelay * (attempt + 1));
            continue;
          }
        }
        
        // Return error immediately for non-retryable errors
        break;
      }
    }

    // All retries failed
    return ApiResponse<T>.error(
      message: _getExceptionMessage(lastException),
      exception: lastException,
    );
  }

  /// Get user-friendly message based on HTTP status code
  static String _getStatusCodeMessage(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Invalid request. Please check your input.';
      case 401:
        return 'You are not authorized. Please log in again.';
      case 403:
        return 'You do not have permission to perform this action.';
      case 404:
        return 'The requested resource was not found.';
      case 408:
        return 'Request timeout. Please try again.';
      case 409:
        return 'Conflict occurred. The resource may already exist.';
      case 422:
        return 'Invalid data provided. Please check your input.';
      case 429:
        return 'Too many requests. Please wait and try again.';
      case 500:
        return 'Server error. Please try again later.';
      case 502:
        return 'Service temporarily unavailable. Please try again.';
      case 503:
        return 'Service unavailable. Please try again later.';
      case 504:
        return 'Request timeout. Please try again.';
      default:
        return 'An unexpected error occurred (${statusCode}).';
    }
  }

  /// Get user-friendly message based on exception type
  static String _getExceptionMessage(dynamic exception) {
    if (exception == null) return 'An unknown error occurred.';
    
    final exceptionStr = exception.toString().toLowerCase();
    
    if (exceptionStr.contains('timeout')) {
      return 'Request timed out. Please check your connection and try again.';
    } else if (exceptionStr.contains('socket') || exceptionStr.contains('network')) {
      return 'Network connection error. Please check your internet connection.';
    } else if (exceptionStr.contains('format') || exceptionStr.contains('parse')) {
      return 'Data format error. Please try again.';
    } else if (exceptionStr.contains('permission')) {
      return 'Permission denied. Please check your access rights.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }
}

/// Response wrapper for API calls
class ApiResponse<T> {
  final bool isSuccess;
  final T? data;
  final String message;
  final int? statusCode;
  final Exception? exception;

  ApiResponse._({
    required this.isSuccess,
    this.data,
    required this.message,
    this.statusCode,
    this.exception,
  });

  factory ApiResponse.success({
    T? data,
    required String message,
    int? statusCode,
  }) {
    return ApiResponse._(
      isSuccess: true,
      data: data,
      message: message,
      statusCode: statusCode,
    );
  }

  factory ApiResponse.error({
    required String message,
    int? statusCode,
    Exception? exception,
  }) {
    return ApiResponse._(
      isSuccess: false,
      message: message,
      statusCode: statusCode,
      exception: exception,
    );
  }

  bool get isError => !isSuccess;
}

/// Custom HTTP exception
class HttpException implements Exception {
  final String message;
  final int statusCode;

  HttpException(this.message, this.statusCode);

  @override
  String toString() => 'HttpException: $message (Status: $statusCode)';
}
