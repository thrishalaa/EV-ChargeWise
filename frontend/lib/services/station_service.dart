import '../models/station.dart';
import 'api_service.dart';

class StationService {
  final ApiService apiService;

  StationService({required this.apiService});

  Future<List<Station>> searchStationsByName(String query) async {
    try {
      // Updated endpoint to use the existing search endpoint
      final response = await apiService.post(
        '/stations/search',
        body: {
          'latitude':
              0.0, // Default values, replace with actual location if available
          'longitude': 0.0,
          'max_range': 30.0,
        },
      );

      final List<dynamic> stationsJson = response;
      return stationsJson.map((json) => Station.fromJson(json)).toList();
    } catch (e) {
      print('Error searching stations by name: $e');
      throw Exception('Failed to search stations by name: $e');
    }
  }

  Future<List<Station>> getStationsOnRoute({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
    required int currentChargePercent,
  }) async {
    try {
      final response = await apiService.post(
        '/stations/route',
        body: {
          'start_latitude': startLatitude,
          'start_longitude': startLongitude,
          'end_latitude': endLatitude,
          'end_longitude': endLongitude,
          'current_charge_percent': currentChargePercent,
        },
      );

      final List<dynamic> stationsJson = response;
      return stationsJson.map((json) => Station.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching stations on route: $e');
      throw Exception('Failed to fetch stations on route: $e');
    }
  }

  Future<List<Station>> searchNearbyStations(
    double latitude,
    double longitude, {
    double maxRange = 30.0,
  }) async {
    try {
      final response = await apiService.post(
        '/stations/search',
        body: {
          'latitude': latitude,
          'longitude': longitude,
          'radius': maxRange,
        },
      );

      final List<dynamic> stationsJson = response;
      return stationsJson.map((json) => Station.fromJson(json)).toList();
    } catch (e) {
      print('Error searching nearby stations: $e');
      throw Exception('Failed to search nearby stations: $e');
    }
  }

  Future<List<Station>> getRecentBookedStations() async {
    try {
      final response = await apiService.get('/stations/recent');

      try {
        final List<dynamic> stationsJson = response;
        return stationsJson.map((json) => Station.fromJson(json)).toList();
      } catch (e) {
        return [];
      }
    } catch (e) {
      print('Error fetching recent stations: $e');
      return [];
    }
  }

  Future<List<Station>> getNearbyStations(
    double latitude,
    double longitude,
  ) async {
    try {
      final response = await apiService.get(
        '/stations/nearby?lat=$latitude&lng=$longitude',
      );

      final List<dynamic> stationsJson = response;
      return stationsJson.map((json) => Station.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching nearby stations: $e');
      return [];
    }
  }

  Future<Station?> getStationById(int id) async {
    try {
      final response = await apiService.get('/stations/$id');
      if (response != null) {
        return Station.fromJson(response);
      }
      return null;
    } catch (e) {
      print('Error fetching station by id: $e');
      return null;
    }
  }
}
