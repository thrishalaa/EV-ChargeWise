import 'api_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final ApiService apiService;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Define a custom timeout duration for auth operations
  final Duration authTimeout = const Duration(seconds: 1500);

  String? _token;
  String? userRole;

  AuthService({required this.apiService});

  String? get token => _token;

  Future<bool> login(String username, String password) async {
    try {
      print('Attempting login with username: $username');

      final response = await apiService.login(
        username,
        password,
        timeout: authTimeout, // Pass the custom timeout
      );

      if (response != null && response['access_token'] != null) {
        _token = response['access_token'];
        print("Setting token in ApiService: $_token");
        await apiService.setToken(_token!);

        userRole = response['role'] ?? 'user';
        print("Setting userRole: $userRole");

        // Persist userRole securely
        await _storage.write(key: 'userRole', value: userRole);
        print("Persisted userRole in storage");
        return true;
      }
      print("Login response did not contain access_token");
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    print("Logging out: clearing token and userRole");
    _token = null;
    await apiService.clearToken();

    // Clear persisted userRole
    await _storage.delete(key: 'userRole');
    userRole = null;
    print("Logout complete: token and userRole cleared");
  }

  Future<bool> isLoggedIn() async {
    final token = await apiService.token;
    if (token != null && token.isNotEmpty) {
      _token = token;

      // Load userRole from secure storage if not already loaded
      if (userRole == null) {
        userRole = await _storage.read(key: 'userRole') ?? 'user';
      }
      return true;
    }
    return false;
  }

  Future<bool> loadAuthInfo() async {
    final token = await apiService.token;
    print("loadAuthInfo: token = $token");
    final role = await _storage.read(key: 'userRole');
    print("loadAuthInfo: role = $role");
    if (token != null && token.isNotEmpty && role != null) {
      _token = token;
      userRole = role;
      return true;
    }
    return false;
  }

  Future<bool> register(
    String username,
    String email,
    String phone_number,
    String password,
  ) async {
    try {
      final response = await apiService.post(
        '/users/register',
        body: {
          'username': username,
          'email': email,
          'phone_number': phone_number,
          'password': password,
        },
        timeout: authTimeout, // Add timeout to register method
      );
      return true;
    } catch (e) {
      print('Registration error: $e');
      return false;
    }
  }
}
