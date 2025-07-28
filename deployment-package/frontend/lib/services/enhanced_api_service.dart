import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/environment.dart';
import 'auth_service.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? details;

  ApiException(this.message, {this.statusCode, this.details});

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class EnhancedApiService {
  static const Duration _timeout = Duration(seconds: 30);
  static const int _maxRetries = 3;

  static Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth) {
      final token = await AuthService.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  static Future<Map<String, String>> _getMultipartHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Uri _buildUri(String endpoint, {Map<String, String>? queryParams}) {
    final url = Environment.buildApiUrl(endpoint);
    final uri = Uri.parse(url);
    
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams);
    }
    
    return uri;
  }

  static Future<T> _handleResponse<T>(http.Response response) async {
    if (Environment.isDebugMode) {
      debugPrint('API Response: ${response.statusCode} - ${response.body}');
    }

    if (response.statusCode == 401) {
      // Token expired, try to refresh
      final refreshed = await AuthService.refreshToken();
      if (!refreshed) {
        await AuthService.logout();
        throw ApiException('Authentication failed', statusCode: 401);
      }
      throw ApiException('Token expired, please retry', statusCode: 401);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return null as T;
      }
      
      try {
        final decoded = json.decode(response.body);
        return decoded as T;
      } catch (e) {
        throw ApiException('Invalid JSON response: $e');
      }
    }

    // Handle error responses
    String errorMessage = 'Request failed';
    Map<String, dynamic>? errorDetails;

    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map<String, dynamic>) {
        errorMessage = errorBody['error'] ?? errorBody['message'] ?? errorMessage;
        errorDetails = errorBody;
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
    }

    throw ApiException(
      errorMessage,
      statusCode: response.statusCode,
      details: errorDetails,
    );
  }

  static Future<T> _makeRequest<T>(
    Future<http.Response> Function() request, {
    int retryCount = 0,
  }) async {
    try {
      final response = await request().timeout(_timeout);
      return await _handleResponse<T>(response);
    } on SocketException {
      throw ApiException('No internet connection');
    } on HttpException catch (e) {
      throw ApiException('Network error: ${e.message}');
    } on ApiException catch (e) {
      if (e.statusCode == 401 && retryCount < 1) {
        // Retry once for auth errors
        return _makeRequest<T>(request, retryCount: retryCount + 1);
      }
      rethrow;
    } catch (e) {
      if (retryCount < _maxRetries) {
        await Future.delayed(Duration(seconds: retryCount + 1));
        return _makeRequest<T>(request, retryCount: retryCount + 1);
      }
      throw ApiException('Unexpected error: $e');
    }
  }

  // GET request
  static Future<T> get<T>(
    String endpoint, {
    Map<String, String>? queryParams,
    bool includeAuth = true,
  }) async {
    return _makeRequest<T>(() async {
      final uri = _buildUri(endpoint, queryParams: queryParams);
      final headers = await _getHeaders(includeAuth: includeAuth);
      
      if (Environment.isDebugMode) {
        debugPrint('GET: $uri');
      }
      
      return http.get(uri, headers: headers);
    });
  }

  // POST request
  static Future<T> post<T>(
    String endpoint,
    Map<String, dynamic> data, {
    bool includeAuth = true,
  }) async {
    return _makeRequest<T>(() async {
      final uri = _buildUri(endpoint);
      final headers = await _getHeaders(includeAuth: includeAuth);
      
      if (Environment.isDebugMode) {
        debugPrint('POST: $uri');
        debugPrint('Data: ${json.encode(data)}');
      }
      
      return http.post(uri, headers: headers, body: json.encode(data));
    });
  }

  // PUT request
  static Future<T> put<T>(
    String endpoint,
    Map<String, dynamic> data, {
    bool includeAuth = true,
  }) async {
    return _makeRequest<T>(() async {
      final uri = _buildUri(endpoint);
      final headers = await _getHeaders(includeAuth: includeAuth);
      
      if (Environment.isDebugMode) {
        debugPrint('PUT: $uri');
        debugPrint('Data: ${json.encode(data)}');
      }
      
      return http.put(uri, headers: headers, body: json.encode(data));
    });
  }

  // PATCH request
  static Future<T> patch<T>(
    String endpoint,
    Map<String, dynamic> data, {
    bool includeAuth = true,
  }) async {
    return _makeRequest<T>(() async {
      final uri = _buildUri(endpoint);
      final headers = await _getHeaders(includeAuth: includeAuth);
      
      if (Environment.isDebugMode) {
        debugPrint('PATCH: $uri');
        debugPrint('Data: ${json.encode(data)}');
      }
      
      return http.patch(uri, headers: headers, body: json.encode(data));
    });
  }

  // DELETE request
  static Future<T?> delete<T>(
    String endpoint, {
    bool includeAuth = true,
  }) async {
    return _makeRequest<T?>(() async {
      final uri = _buildUri(endpoint);
      final headers = await _getHeaders(includeAuth: includeAuth);
      
      if (Environment.isDebugMode) {
        debugPrint('DELETE: $uri');
      }
      
      return http.delete(uri, headers: headers);
    });
  }

  // File upload
  static Future<T> uploadFile<T>(
    String endpoint,
    File file, {
    Map<String, String>? fields,
    String fieldName = 'file',
    bool includeAuth = true,
  }) async {
    return _makeRequest<T>(() async {
      final uri = _buildUri(endpoint);
      final headers = await _getMultipartHeaders();
      
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(headers);
      
      if (fields != null) {
        request.fields.addAll(fields);
      }
      
      request.files.add(await http.MultipartFile.fromPath(fieldName, file.path));
      
      if (Environment.isDebugMode) {
        debugPrint('UPLOAD: $uri');
        debugPrint('File: ${file.path}');
        debugPrint('Fields: $fields');
      }
      
      final streamedResponse = await request.send();
      return http.Response.fromStream(streamedResponse);
    });
  }

  // Multiple file upload
  static Future<T> uploadMultipleFiles<T>(
    String endpoint,
    List<File> files, {
    Map<String, String>? fields,
    String fieldName = 'files',
    bool includeAuth = true,
  }) async {
    return _makeRequest<T>(() async {
      final uri = _buildUri(endpoint);
      final headers = await _getMultipartHeaders();
      
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(headers);
      
      if (fields != null) {
        request.fields.addAll(fields);
      }
      
      for (final file in files) {
        request.files.add(await http.MultipartFile.fromPath(fieldName, file.path));
      }
      
      if (Environment.isDebugMode) {
        debugPrint('UPLOAD MULTIPLE: $uri');
        debugPrint('Files: ${files.map((f) => f.path).toList()}');
        debugPrint('Fields: $fields');
      }
      
      final streamedResponse = await request.send();
      return http.Response.fromStream(streamedResponse);
    });
  }

  // Download file
  static Future<List<int>> downloadFile(String endpoint) async {
    return _makeRequest<List<int>>(() async {
      final uri = _buildUri(endpoint);
      final headers = await _getHeaders();
      
      if (Environment.isDebugMode) {
        debugPrint('DOWNLOAD: $uri');
      }
      
      final response = await http.get(uri, headers: headers);
      return Future.value(response.bodyBytes);
    });
  }

  // Health check
  static Future<bool> healthCheck() async {
    try {
      await get<Map<String, dynamic>>('/health', includeAuth: false);
      return true;
    } catch (e) {
      return false;
    }
  }
}
