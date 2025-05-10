class AdminDashboard {
  final int totalStations;
  final int totalBookings;
  final int activeStations;
  final int maintenanceStations;
  final int pendingBookings;
  final int completedBookings;

  AdminDashboard({
    required this.totalStations,
    required this.totalBookings,
    required this.activeStations,
    required this.maintenanceStations,
    required this.pendingBookings,
    required this.completedBookings,
  });

  factory AdminDashboard.fromJson(Map<String, dynamic> json) {
    return AdminDashboard(
      totalStations: json['total_stations'] ?? 0,
      totalBookings: json['total_bookings'] ?? 0,
      activeStations: json['active_stations'] ?? 0,
      maintenanceStations: json['maintenance_stations'] ?? 0,
      pendingBookings: json['pending_bookings'] ?? 0,
      completedBookings: json['completed_bookings'] ?? 0,
    );
  }
}
