import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:3000/api';
  static String? _token;

  // Initialize token from storage
  static Future<void> initializeToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  static bool isDemoMode() {
    return _token != null && _token!.startsWith('demo-token-');
  }

  static Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Request failed: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> get(String endpoint, {Map<String, dynamic>? queryParams}) async {
    // For demo tokens, simulate successful response
    if (_token != null && _token!.startsWith('demo-token-')) {
      await Future.delayed(const Duration(milliseconds: 500)); // Simulate network delay
      
      if (endpoint == '/projects') {
        return {
          'projects': [
            {
              'id': '1',
              'name': 'Mobile App Development',
              'description': 'Flutter mobile application for task management',
              'status': 'ACTIVE',
              'priority': 'HIGH',
              'createdAt': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
              'updatedAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
              'ownerId': 'demo-user-id',
              'createdBy': {
                'id': 'demo-user-id',
                'name': 'Demo User',
                'email': 'demo@example.com'
              },
              'members': [],
              '_count': {
                'tasks': 5,
                'subProjects': 0
              }
            },
            {
              'id': '2',
              'name': 'Website Redesign',
              'description': 'Complete redesign of company website',
              'status': 'IN_PROGRESS',
              'priority': 'MEDIUM',
              'createdAt': DateTime.now().subtract(const Duration(days: 15)).toIso8601String(),
              'updatedAt': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
              'ownerId': 'demo-user-id',
              'createdBy': {
                'id': 'demo-user-id',
                'name': 'Demo User',
                'email': 'demo@example.com'
              },
              'members': [],
              '_count': {
                'tasks': 3,
                'subProjects': 1
              }
            }
          ]
        };
      }
      
      if (endpoint == '/users/profile') {
        return {
          'id': 'demo-user-id',
          'email': 'demo@example.com',
          'name': 'Demo User',
          'isAdmin': false,
          'isActive': true,
          'createdAt': DateTime.now().subtract(const Duration(days: 30)).toIso8601String()
        };
      }
    }

    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Request failed: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Request failed: ${response.body}');
    }
  }

  static Future<void> delete(String endpoint) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Delete failed: ${response.body}');
    }
  }

  static Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<void> removeToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  static Future<String?> getToken() async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    return _token;
  }

  static Future<void> logout() async {
    await removeToken();
  }

  static Future<void> clearDemoToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    _token = null;
  }

  // Auth endpoints
  static Future<Map<String, dynamic>> googleLogin(String token) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Google login failed: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Token refresh failed: ${response.body}');
    }
  }

  // User endpoints
  static Future<Map<String, dynamic>> getUserProfile() async {
    return await get('/users/profile');
  }

  static Future<Map<String, dynamic>> updateUserProfile(Map<String, dynamic> data) async {
    return await put('/users/profile', data);
  }

  static Future<List<dynamic>> getAllUsers() async {
    final response = await get('/users');
    return response['users'] ?? response;
  }

  // Project endpoints
  static Future<List<dynamic>> getProjects() async {
    // For demo tokens, simulate successful response
    if (_token != null && _token!.startsWith('demo-token-')) {
      await Future.delayed(const Duration(milliseconds: 500)); // Simulate network delay
      
      return [
        {
          'id': '1',
          'name': 'Mobile App Development',
          'description': 'Flutter mobile application for task management',
          'status': 'ACTIVE',
          'priority': 'HIGH',
          'createdAt': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
          'updatedAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
          'ownerId': 'demo-user-id',
          'createdBy': {
            'id': 'demo-user-id',
            'name': 'Demo User',
            'email': 'demo@example.com'
          },
          'members': [],
          '_count': {
            'tasks': 5,
            'subProjects': 0
          }
        },
        {
          'id': '2',
          'name': 'Website Redesign',
          'description': 'Complete redesign of company website',
          'status': 'IN_PROGRESS',
          'priority': 'MEDIUM',
          'createdAt': DateTime.now().subtract(const Duration(days: 15)).toIso8601String(),
          'updatedAt': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
          'ownerId': 'demo-user-id',
          'createdBy': {
            'id': 'demo-user-id',
            'name': 'Demo User',
            'email': 'demo@example.com'
          },
          'members': [],
          '_count': {
            'tasks': 3,
            'subProjects': 1
          }
        }
      ];
    }

    final response = await get('/projects');
    // Extract projects from response - response is always Map<String, dynamic>
    if (response.containsKey('projects') && response['projects'] is List) {
      return (response['projects'] as List).map((e) => e as dynamic).toList();
    }
    // If no 'projects' key, return empty list
    return [];
  }

  static Future<Map<String, dynamic>> getProject(String id) async {
    return await get('/projects/$id');
  }

  static Future<Map<String, dynamic>> createProject(Map<String, dynamic> data) async {
    return await post('/projects', data);
  }

  static Future<Map<String, dynamic>> updateProject(String id, Map<String, dynamic> data) async {
    return await put('/projects/$id', data);
  }

  static Future<void> deleteProject(String id) async {
    await delete('/projects/$id');
  }

  // Sub-project endpoints
  static Future<List<dynamic>> getSubProjects(String projectId) async {
    final response = await get('/projects/$projectId/subprojects');
    return response['subProjects'] ?? response;
  }

  static Future<Map<String, dynamic>> getSubProject(String id) async {
    return await get('/projects/subprojects/$id');
  }

  static Future<Map<String, dynamic>> createSubProject(Map<String, dynamic> data) async {
    return await post('/projects/subprojects', data);
  }

  static Future<Map<String, dynamic>> updateSubProject(String id, Map<String, dynamic> data) async {
    return await put('/projects/subprojects/$id', data);
  }

  static Future<void> deleteSubProject(String id) async {
    await delete('/projects/subprojects/$id');
  }

  // Task endpoints
  static Future<Map<String, dynamic>> getTasks({
    String? projectId,
    String? subProjectId,
    String? status,
    String? priority,
    String? taskType,
    String? mainAssigneeId,
    String? search,
    String? sortBy,
    String? sortOrder,
    int page = 1,
    int limit = 10,
  }) async {
    String endpoint = '/tasks?page=$page&limit=$limit';

    if (projectId != null) endpoint += '&projectId=$projectId';
    if (subProjectId != null) endpoint += '&subProjectId=$subProjectId';
    if (status != null) endpoint += '&status=$status';
    if (priority != null) endpoint += '&priority=$priority';
    if (taskType != null) endpoint += '&taskType=$taskType';
    if (mainAssigneeId != null) endpoint += '&mainAssigneeId=$mainAssigneeId';
    if (search != null) endpoint += '&search=${Uri.encodeComponent(search)}';
    if (sortBy != null) endpoint += '&sortBy=$sortBy';
    if (sortOrder != null) endpoint += '&sortOrder=$sortOrder';

    return await get(endpoint);
  }

  static Future<Map<String, dynamic>> getTask(String id) async {
    return await get('/tasks/$id');
  }

  static Future<Map<String, dynamic>> createTask(Map<String, dynamic> data) async {
    return await post('/tasks', data);
  }

  static Future<Map<String, dynamic>> updateTask(String id, Map<String, dynamic> data) async {
    return await put('/tasks/$id', data);
  }

  static Future<void> deleteTask(String id) async {
    await delete('/tasks/$id');
  }

  // Task dependency endpoints
  static Future<Map<String, dynamic>> addTaskDependency(String taskId, Map<String, dynamic> data) async {
    return await post('/tasks/$taskId/dependencies', data);
  }

  static Future<void> removeTaskDependency(String taskId, String dependencyId) async {
    await delete('/tasks/$taskId/dependencies/$dependencyId');
  }

  // Task comment endpoints
  static Future<Map<String, dynamic>> addTaskComment(String taskId, Map<String, dynamic> data) async {
    return await post('/tasks/$taskId/comments', data);
  }

  // Task time tracking endpoints
  static Future<Map<String, dynamic>> addTimeEntry(String taskId, Map<String, dynamic> data) async {
    return await post('/tasks/$taskId/time-entries', data);
  }

  // Legacy methods for backward compatibility
  static Future<Map<String, dynamic>> login(String email, String password) async {
    // This is for demo purposes - your backend uses Google OAuth
    throw Exception('Use Google OAuth or demo login');
  }

  static Future<Map<String, dynamic>> getCurrentUser(String token) async {
    return await getUserProfile();
  }
}
