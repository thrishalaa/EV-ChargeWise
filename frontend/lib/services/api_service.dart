import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:io';

class ApiService {
  late final String baseUrl;
  String? _token;

  ApiService() {
    // Use environment variable or default to localhost
    baseUrl =
        Platform.environment['API_BASE_URL'] ?? 'http://192.168.200.165:8000';
  }

  Future<String?> get token async {
    if (_token != null) return _token;

    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    return _token;
  }

  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // Add headers including auth token
  Future<Map<String, String>> _getHeaders({bool requiresAuth = true}) async {
    final headers = {'Content-Type': 'application/json'};

    if (requiresAuth) {
      final authToken = await token;
      if (authToken != null) {
        headers['Authorization'] = 'Bearer $authToken';
      }
    }

    return headers;
  }

  // Generic HTTP methods
  Future<dynamic> get(String endpoint, {bool requiresAuth = true}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(requiresAuth: requiresAuth),
      );
      return _processResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    bool requiresAuth = true,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(requiresAuth: requiresAuth),
        body: body != null ? jsonEncode(body) : null,
      );
      return _processResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<dynamic> put(
    String endpoint, {
    dynamic body,
    bool requiresAuth = true,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(requiresAuth: requiresAuth),
        body: body != null ? jsonEncode(body) : null,
      );
      return _processResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<dynamic> delete(String endpoint, {bool requiresAuth = true}) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(requiresAuth: requiresAuth),
      );
      return _processResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Process HTTP response
  dynamic _processResponse(http.Response response) {
    final statusCode = response.statusCode;
    dynamic responseBody;

    try {
      responseBody =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;
    } catch (e) {
      throw Exception('Failed to parse response JSON: $e');
    }

    if (statusCode >= 200 && statusCode < 300) {
      return responseBody;
    } else if (statusCode == 401) {
      throw Exception('Unauthorized: Session expired or invalid credentials');
    } else {
      final error =
          responseBody != null && responseBody['detail'] != null
              ? responseBody['detail']
              : responseBody != null && responseBody['message'] != null
              ? responseBody['message']
              : 'Unknown error occurred';
      throw Exception(
        'Request failed with status: $statusCode, message: $error',
      );
    }
  }

  // Auth specific methods
  Future<Map<String, dynamic>> login(String username, String password) async {
    final headers = {'Content-Type': 'application/x-www-form-urlencoded'};

    final body = 'username=$username&password=$password';

    final response = await http.post(
      Uri.parse('$baseUrl/auth/token'),
      headers: headers,
      body: body,
    );

    final statusCode = response.statusCode;
    final responseBody = jsonDecode(response.body);

    if (statusCode >= 200 && statusCode < 300) {
      await setToken(responseBody['access_token']);
      return responseBody;
    } else {
      final error = responseBody['detail'] ?? 'Login failed';
      throw Exception(error);
    }
  }

  Future<void> logout() async {
    await clearToken();
  }

  // New method to call route optimization API
  Future<dynamic> optimizeRoute({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) async {
    final body = {
      "start_latitude": startLatitude,
      "start_longitude": startLongitude,
      "end_latitude": endLatitude,
      "end_longitude": endLongitude,
    };

    // Adjusted endpoint to include /routes prefix as per backend main.py
    return await post('/routes/optimize', body: body);
  }
}
