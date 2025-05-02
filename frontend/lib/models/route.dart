import 'station.dart';

class RouteOptimizationRequest {
  final double startLatitude;
  final double startLongitude;
  final double endLatitude;
  final double endLongitude;

  RouteOptimizationRequest({
    required this.startLatitude,
    required this.startLongitude,
    required this.endLatitude,
    required this.endLongitude,
  });

  Map<String, dynamic> toJson() {
    return {
      'start_latitude': startLatitude,
      'start_longitude': startLongitude,
      'end_latitude': endLatitude,
      'end_longitude': endLongitude,
    };
  }
}

class RouteSegment {
  final String from;
  final String to;
  final double distance;
  final double duration;
  final String? geometry;

  RouteSegment({
    required this.from,
    required this.to,
    required this.distance,
    required this.duration,
    this.geometry,
  });

  factory RouteSegment.fromJson(Map<String, dynamic> json) {
    return RouteSegment(
      from: json['from'],
      to: json['to'],
      distance: json['distance'].toDouble(),
      duration: json['duration'].toDouble(),
      geometry: json['geometry'],
    );
  }
}

class RouteResponse {
  final List<Station> chargingStations;
  final double totalDistance;
  final double totalDuration;
  final int numberOfStops;
  final double estimatedChargingTime;
  final double totalTripTime;
  final List<RouteSegment> routeSegments;

  RouteResponse({
    required this.chargingStations,
    required this.totalDistance,
    required this.totalDuration,
    required this.numberOfStops,
    required this.estimatedChargingTime,
    required this.totalTripTime,
    required this.routeSegments,
  });

  factory RouteResponse.fromJson(Map<String, dynamic> json) {
    var stationsJson = json['charging_stations'] as List;
    List<Station> stations =
        stationsJson
            .map((stationJson) => Station.fromJson(stationJson))
            .toList();

    var segmentsJson = json['route_segments'] as List;
    List<RouteSegment> segments =
        segmentsJson
            .map((segmentJson) => RouteSegment.fromJson(segmentJson))
            .toList();

    return RouteResponse(
      chargingStations: stations,
      totalDistance: json['total_distance'].toDouble(),
      totalDuration: json['total_duration'].toDouble(),
      numberOfStops: json['number_of_stops'],
      estimatedChargingTime: json['estimated_charging_time'].toDouble(),
      totalTripTime: json['total_trip_time'].toDouble(),
      routeSegments: segments,
    );
  }
}