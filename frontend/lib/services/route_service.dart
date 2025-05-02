import '../models/route.dart';
import 'api_service.dart';

class RouteService {
  final ApiService apiService;

  RouteService({required this.apiService});

  Future<RouteResponse?> optimizeRoute(RouteOptimizationRequest request) async {
    try {
      final response = await apiService.post(
        '/routes/optimize',
        body: request.toJson(),
      );
      return RouteResponse.fromJson(response);
    } catch (e) {
      print('Error optimizing route: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getDirectRoute(
    double startLat,
    double startLon,
    double endLat,
    double endLon,
  ) async {
    try {
      final response = await apiService.get(
        '/routes/direct-route?start_lat=$startLat&start_lon=$startLon&end_lat=$endLat&end_lon=$endLon',
      );
      return response;
    } catch (e) {
      print('Error getting direct route: $e');
      return null;
    }
  }
}
