import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';
import 'dart:async'; // Import for TimeoutException

class ApiService {
  late final String baseUrl;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  String? _token;

  // Default timeout duration - increase this value based on your backend's performance
  final Duration defaultTimeout = const Duration(seconds: 1000);

  ApiService() {
    // Use environment variable or default to localhost
    baseUrl =
        Platform.environment['API_BASE_URL'] ?? 'http://192.168.100.9:8000';
  }

  Future<String?> get token async {
    if (_token != null) return _token;

    _token = await _secureStorage.read(key: 'auth_token');
    return _token;
  }

  Future<void> setToken(String token) async {
    _token = token;
    await _secureStorage.write(key: 'auth_token', value: token);
  }

  Future<void> clearToken() async {
    _token = null;
    await _secureStorage.delete(key: 'auth_token');
  }

  // Add headers including auth token
  Future<Map<String, String>> _getHeaders({bool requiresAuth = true}) async {
    final headers = {'Content-Type': 'application/json'};

    if (requiresAuth) {
      final authToken = await token;
      print('ApiService _getHeaders authToken: $authToken');
      if (authToken != null) {
        headers['Authorization'] = 'Bearer $authToken';
      }
    }

    print('ApiService _getHeaders headers: $headers');
    return headers;
  }

  // Generic HTTP methods
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParameters,
    bool requiresAuth = true,
    Duration? timeout,
  }) async {
    try {
      Uri uri = Uri.parse('$baseUrl$endpoint');
      if (queryParameters != null && queryParameters.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParameters);
      }
      final response = await http
          .get(uri, headers: await _getHeaders(requiresAuth: requiresAuth))
          .timeout(timeout ?? defaultTimeout);
      return _processResponse(response);
    } on TimeoutException {
      throw Exception(
        'Request timed out. Server might be slow or unreachable.',
      );
    } catch (e) {
      print('ApiService GET request to $endpoint failed with error: $e');
      throw Exception('Network error: $e');
    }
  }

  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    Map<String, String>? queryParameters,
    bool requiresAuth = true,
    Duration? timeout,
  }) async {
    try {
      Uri uri = Uri.parse('$baseUrl$endpoint');
      if (queryParameters != null && queryParameters.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParameters);
      }
      final response = await http
          .post(
            uri,
            headers: await _getHeaders(requiresAuth: requiresAuth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout ?? defaultTimeout);
      return _processResponse(response);
    } on TimeoutException {
      throw Exception(
        'Request timed out. Server might be slow or unreachable.',
      );
    } catch (e) {
      print('ApiService POST request to $endpoint failed with error: $e');
      throw Exception('Network error: $e');
    }
  }

  Future<dynamic> put(
    String endpoint, {
    dynamic body,
    bool requiresAuth = true,
    Duration? timeout,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl$endpoint'),
            headers: await _getHeaders(requiresAuth: requiresAuth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout ?? defaultTimeout);
      return _processResponse(response);
    } on TimeoutException {
      throw Exception(
        'Request timed out. Server might be slow or unreachable.',
      );
    } catch (e) {
      print('ApiService PUT request to $endpoint failed with error: $e');
      throw Exception('Network error: $e');
    }
  }

  Future<dynamic> delete(
    String endpoint, {
    bool requiresAuth = true,
    Duration? timeout,
  }) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl$endpoint'),
            headers: await _getHeaders(requiresAuth: requiresAuth),
          )
          .timeout(timeout ?? defaultTimeout);
      return _processResponse(response);
    } on TimeoutException {
      throw Exception(
        'Request timed out. Server might be slow or unreachable.',
      );
    } catch (e) {
      print('ApiService DELETE request to $endpoint failed with error: $e');
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
  Future<Map<String, dynamic>> login(
    String username,
    String password, {
    Duration? timeout,
  }) async {
    final headers = {'Content-Type': 'application/x-www-form-urlencoded'};
    final body = 'username=$username&password=$password';

    try {
      final response = await http
          .post(Uri.parse('$baseUrl/token'), headers: headers, body: body)
          .timeout(timeout ?? defaultTimeout);

      final statusCode = response.statusCode;
      final responseBody = jsonDecode(response.body);

      if (statusCode >= 200 && statusCode < 300) {
        await setToken(responseBody['access_token']);
        return responseBody;
      } else {
        final error = responseBody['detail'] ?? 'Login failed';
        throw Exception(error);
      }
    } on TimeoutException {
      throw Exception('Login timed out. Server might be slow or unreachable.');
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  Future<void> logout() async {
    await clearToken();
  }

  // Route optimization API
  Future<dynamic> optimizeRoute({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
    Duration? timeout,
  }) async {
    final body = {
      "start_latitude": startLatitude,
      "start_longitude": startLongitude,
      "end_latitude": endLatitude,
      "end_longitude": endLongitude,
    };

    return await post(
      '/routes/optimize',
      body: body,
      timeout: timeout ?? defaultTimeout,
    );
  }
}
