import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/admin_service.dart';
import '../models/admin_dashboard.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<AdminDashboard> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    final adminService = Provider.of<AdminService>(context, listen: false);
    _dashboardFuture = adminService.getAdminDashboard();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EV ChargeWise'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(30.0),
          child: Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Admin Dashboard',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<AdminDashboard>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: \${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('No data available'));
          }

          final dashboard = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                _buildStatCard('Total Stations', dashboard.totalStations),
                _buildStatCard('Active Stations', dashboard.activeStations),
                _buildStatCard(
                  'Stations in Maintenance',
                  dashboard.maintenanceStations,
                ),
                _buildStatCard('Total Bookings', dashboard.totalBookings),
                _buildStatCard('Pending Bookings', dashboard.pendingBookings),
                _buildStatCard(
                  'Completed Bookings',
                  dashboard.completedBookings,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, int value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(title),
        trailing: Text(
          value.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
    );
  }
}
