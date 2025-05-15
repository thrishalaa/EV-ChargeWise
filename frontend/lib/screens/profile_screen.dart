import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/user.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;
  User? _user;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // This would be replaced with actual API call in a real app
      // For now, we're simulating a user profile
      await Future.delayed(Duration(seconds: 1));
      setState(() {
        _user = User(
          id: 1,
          username: 'testuser',
          email: 'test@example.com',
          fullName: 'Test User',
          role: 'user',
        );
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load profile: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadUserProfile,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_user == null) {
      return const Scaffold(
        body: Center(child: Text('No profile information available')),
      );
    }

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Text(
                      _user!.fullName != null && _user!.fullName!.isNotEmpty
                          ? _user!.fullName!.substring(0, 1).toUpperCase()
                          : _user!.username.substring(0, 1).toUpperCase(),
                      style: const TextStyle(fontSize: 40, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _user!.fullName ?? _user!.username,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _user!.email,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  final authService = Provider.of<AuthService>(
                    context,
                    listen: false,
                  );
                  await authService.logout();
                  Navigator.of(context).pushReplacementNamed('/login');
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.red,
                ),
                child: const Text('Log Out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
