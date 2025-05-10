class ChargingConfig {
  final String chargingType;
  final String connectorType;
  final double powerOutput;
  final double costPerKwh;

  ChargingConfig({
    required this.chargingType,
    required this.connectorType,
    required this.powerOutput,
    required this.costPerKwh,
  });

  factory ChargingConfig.fromJson(Map<String, dynamic> json) {
    return ChargingConfig(
      chargingType: json['charging_type'],
      connectorType: json['connector_type'],
      powerOutput: json['power_output'].toDouble(),
      costPerKwh: json['cost_per_kwh'].toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'charging_type': chargingType,
      'connector_type': connectorType,
      'power_output': powerOutput,
      'cost_per_kwh': costPerKwh,
    };
  }
}

class BookingInfo {
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;

  BookingInfo({
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
  });

  factory BookingInfo.fromJson(Map<String, dynamic> json) {
    return BookingInfo(
      startTime: DateTime.parse(json['start_time']),
      endTime: DateTime.parse(json['end_time']),
      durationMinutes: json['duration_minutes'],
    );
  }
}

class Station {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final bool isAvailable;
  final bool maintenance;
  final List<ChargingConfig> chargingConfigs;
  final double? distance;
  final List<BookingInfo>? bookings;

  Station({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.isAvailable,
    required this.maintenance,
    required this.chargingConfigs,
    this.distance,
    this.bookings,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    var configsJson = json['charging_configs'] as List;
    List<ChargingConfig> configs =
        configsJson
            .map((configJson) => ChargingConfig.fromJson(configJson))
            .toList();

    List<BookingInfo>? bookings;
    if (json['bookings'] != null) {
      var bookingsJson = json['bookings'] as List;
      bookings = bookingsJson.map((b) => BookingInfo.fromJson(b)).toList();
    }

    return Station(
      id: json['id'],
      name: json['name'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      isAvailable: json['is_available'],
      maintenance: json['maintenance'] ?? false,
      chargingConfigs: configs,
      distance: json['distance']?.toDouble(),
      bookings: bookings,
    );
  }
}
