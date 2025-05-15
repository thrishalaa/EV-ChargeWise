import 'package:flutter/material.dart';
import 'api_service.dart';
import '../models/admin.dart';
import '../models/station.dart';

class SuperAdminService {
  final ApiService _apiService;

  SuperAdminService(this._apiService);

  Future<List<Admin>> getAllAdmins() async {
    final response = await _apiService.get('/admin/super-admin/admins-list');
    if (response is List) {
      return response.map((json) => Admin.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load admin list');
    }
  }

  Future<Admin> createAdmin(
    String username,
    String email,
    String password,
    bool isSuperAdmin,
  ) async {
    final body = {
      'username': username,
      'email': email,
      'password': password,
      'is_super_admin': isSuperAdmin,
    };

    final response = await _apiService.post(
      '/admin/super-admin/admin-create',
      body: body,
    );
    if (response is Map<String, dynamic>) {
      return Admin.fromJson(response);
    } else {
      throw Exception('Failed to create admin');
    }
  }

  Future<Admin> updateAdmin(
    int adminId, {
    String? username,
    String? email,
    String? password,
    bool? isActive,
    bool? isSuperAdmin,
  }) async {
    final body = {
      if (username != null) 'username': username,
      if (email != null) 'email': email,
      if (password != null) 'password': password,
      if (isActive != null) 'is_active': isActive,
      if (isSuperAdmin != null) 'is_super_admin': isSuperAdmin,
    };

    final response = await _apiService.put(
      '/admin/super-admin/admins/$adminId',
      body: body,
    );
    if (response is Map<String, dynamic>) {
      return Admin.fromJson(response);
    } else {
      throw Exception('Failed to update admin');
    }
  }

  Future<void> assignStationToAdmin(int adminId, int stationId) async {
    final body = {'admin_id': adminId, 'station_id': stationId};

    await _apiService.post('/admin/super-admin/station/assign', body: body);
  }

  Future<void> bulkAssignStations(List<Map<String, int>> assignments) async {
    final body =
        assignments
            .map(
              (assignment) => {
                'admin_id': assignment['admin_id'],
                'station_id': assignment['station_id'],
              },
            )
            .toList();

    await _apiService.post('/admin/super-admin/stations/assign', body: body);
  }
}
