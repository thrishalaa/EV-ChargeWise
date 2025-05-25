import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/admin_service.dart';
import '../models/admin_dashboard.dart';
import 'admin_stations_screen.dart';
import 'admin_bookings_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<AdminDashboard> _dashboardFuture;
  int _selectedIndex = 0;
  late String _userRole;

  @override
  void initState() {
    super.initState();
    final adminService = Provider.of<AdminService>(context, listen: false);
    _dashboardFuture = adminService.getAdminDashboard();

    final authService = Provider.of<AuthService>(context, listen: false);
    _userRole = authService.userRole ?? 'user';

    // Debug print
    print('Initialized AdminDashboardScreen and fetching dashboard data');
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Refresh dashboard when switching to dashboard tab
    if (index == 0) {
      _refreshDashboard();
    }
  }

  void _refreshDashboard() {
    setState(() {
      final adminService = Provider.of<AdminService>(context, listen: false);
      _dashboardFuture = adminService.getAdminDashboard();
      print('Dashboard refreshed');
    });
  }

  List<Map<String, dynamic>> _getNavigationOptions() {
    return [
      {'icon': Icons.dashboard, 'label': 'Dashboard'},
      {'icon': Icons.ev_station, 'label': 'Stations'},
      {'icon': Icons.book_online, 'label': 'Bookings'},
    ];
  }

  @override
  Widget build(BuildContext context) {
    Widget dashboardContent() {
      return FutureBuilder<AdminDashboard>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            print('Dashboard loading: waiting for data');
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            print('Dashboard error: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshDashboard,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData) {
            print('Dashboard error: No data available');
            return const Center(child: Text('No data available'));
          }

          print('Dashboard data loaded successfully');
          final dashboard = snapshot.data!;

          return RefreshIndicator(
            onRefresh: () async {
              _refreshDashboard();
              // Wait for the future to complete
              await _dashboardFuture;
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _buildStatCard('Total Stations', dashboard.total_stations),
                  _buildStatCard('Active Stations', dashboard.active_stations),
                  _buildStatCard(
                    'Stations in Maintenance',
                    dashboard.maintenance_stations,
                  ),
                  _buildStatCard('Total Bookings', dashboard.total_bookings),
                  _buildStatCard(
                    'Upcoming Bookings',
                    dashboard.upcoming_bookings,
                  ),
                  _buildStatCardString(
                    'Total Revenue',
                    dashboard.total_revenue != null
                        ? '\$${dashboard.total_revenue!.toStringAsFixed(2)}'
                        : 'N/A',
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      );
    }

    List<Widget> _widgetOptions = <Widget>[
      dashboardContent(),
      AdminStationsScreen(onMaintenanceChanged: _refreshDashboard),
      const AdminBookingsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'EV ChargeWise',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authService = Provider.of<AuthService>(
                context,
                listen: false,
              );
              await authService.logout();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: _widgetOptions),
      bottomNavigationBar: BottomNavigationBar(
        items:
            _getNavigationOptions()
                .map(
                  (option) => BottomNavigationBarItem(
                    icon: Icon(option['icon']),
                    label: option['label'],
                  ),
                )
                .toList(),
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
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

  Widget _buildStatCardString(String title, String value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
    );
  }
}
