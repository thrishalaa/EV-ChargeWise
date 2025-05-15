class AdminDashboard {
  final int total_stations;
  final int total_bookings;
  final int active_stations;
  final int maintenance_stations;
  final int upcoming_bookings;
  final double? total_revenue;

  AdminDashboard({
    required this.total_stations,
    required this.total_bookings,
    required this.active_stations,
    required this.maintenance_stations,
    required this.upcoming_bookings,
    this.total_revenue,
  });

  factory AdminDashboard.fromJson(Map<String, dynamic> json) {
    return AdminDashboard(
      total_stations: json['total_stations'] ?? 0,
      total_bookings: json['total_bookings'] ?? 0,
      active_stations: json['active_stations'] ?? 0,
      maintenance_stations: json['maintenance_stations'] ?? 0,
      upcoming_bookings: json['upcoming_bookings'] ?? 0,
      total_revenue:
          json['total_revenue'] != null
              ? (json['total_revenue'] as num).toDouble()
              : null,
    );
  }
}
