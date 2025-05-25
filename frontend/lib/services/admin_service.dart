import 'package:flutter/material.dart';
import 'api_service.dart';
import '../models/booking.dart';
import '../models/admin_dashboard.dart';
import '../models/station.dart';

class AdminService {
  final ApiService _apiService;

  AdminService(this._apiService);

  Future<List<Booking>> getAdminBookings({
    DateTime? startDate,
    DateTime? endDate,
    int? stationId,
  }) async {
    final queryParameters = <String, String>{};
    if (startDate != null) {
      queryParameters['start_date'] = startDate.toIso8601String();
    }
    if (endDate != null) {
      queryParameters['end_date'] = endDate.toIso8601String();
    }
    if (stationId != null) {
      queryParameters['station_id'] = stationId.toString();
    }
    final response = await _apiService.get(
      '/admin/admin/bookings',
      queryParameters: queryParameters,
    );
    if (response is List) {
      return response.map((json) => Booking.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load admin bookings');
    }
  }

  Future<AdminDashboard> getAdminDashboard() async {
    final response = await _apiService.get('/admin/admin/dashboard');
    if (response is Map<String, dynamic>) {
      return AdminDashboard.fromJson(response);
    } else {
      throw Exception('Invalid response format for admin dashboard');
    }
  }

  Future<List<Station>> getAdminStations() async {
    final response = await _apiService.get('/admin/admin/stations');
    if (response is List) {
      return response.map((json) => Station.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load admin stations');
    }
  }

  Future<Map<String, dynamic>> setStationMaintenance(
    int stationId,
    bool isMaintenance,
  ) async {
    try {
      print(
        'AdminService: Setting maintenance for station $stationId to $isMaintenance',
      );

      // Use POST method as defined in your backend
      final response = await _apiService.post(
        '/admin/admin/stations/$stationId/maintenance',
        queryParameters: {'is_maintenance': isMaintenance.toString()},
      );

      print('AdminService: Maintenance update response: $response');

      // Return the response for additional handling if needed
      if (response is Map<String, dynamic>) {
        return response;
      } else {
        return {'message': 'Maintenance status updated successfully'};
      }
    } catch (e) {
      print('AdminService: Error updating maintenance status: $e');
      rethrow; // Re-throw the error so the UI can handle it
    }
  }
}
