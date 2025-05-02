import 'api_service.dart';

class AuthService {
  final ApiService apiService;

  AuthService({required this.apiService});

  Future<bool> login(String username, String password) async {
    try {
      final response = await apiService.login(username, password);
      print("Login successful: \$response");
      return true;
    } catch (e) {
      print('Login error: \$e');
      return false;
    }
  }

  Future<void> logout() async {
    await apiService.clearToken();
  }

  Future<bool> isLoggedIn() async {
    final token = await apiService.token;
    return token != null && token.isNotEmpty;
  }

  Future<bool> register(String username, String email, String password) async {
    try {
      final response = await apiService.post(
        '/auth/register',
        body: {'username': username, 'email': email, 'password': password},
      );
      // If no exception, consider registration successful
      return true;
    } catch (e) {
      print('Registration error: $e');
      return false;
    }
  }
}
