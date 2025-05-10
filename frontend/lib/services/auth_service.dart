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
        await apiService.setToken(_token!);

        userRole = response['role'] ?? 'user';

        // Persist userRole securely
        await _storage.write(key: 'userRole', value: userRole);
        print("HERE IS THE ROLE");
        print(userRole);
        return true;
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    await apiService.clearToken();

    // Clear persisted userRole
    await _storage.delete(key: 'userRole');
    userRole = null;
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

  Future<bool> register(String username, String email, String password) async {
    try {
      final response = await apiService.post(
        '/auth/register',
        body: {'username': username, 'email': email, 'password': password},
        timeout: authTimeout, // Add timeout to register method
      );
      return true;
    } catch (e) {
      print('Registration error: $e');
      return false;
    }
  }
}
