import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/admin_service.dart';
import '../models/station.dart';

class AdminStationsScreen extends StatefulWidget {
  const AdminStationsScreen({Key? key}) : super(key: key);

  @override
  _AdminStationsScreenState createState() => _AdminStationsScreenState();
}

class _AdminStationsScreenState extends State<AdminStationsScreen> {
  late Future<List<Station>> _stationsFuture;

  @override
  void initState() {
    super.initState();
    final adminService = Provider.of<AdminService>(context, listen: false);
    _stationsFuture = adminService.getAdminStations();
  }

  Future<void> _toggleMaintenance(Station station) async {
    final adminService = Provider.of<AdminService>(context, listen: false);
    final newStatus = !station.maintenance;
    try {
      await adminService.setStationMaintenance(station.id, newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Station "${station.name}" maintenance status set to ${newStatus ? 'ON' : 'OFF'}',
          ),
          backgroundColor: newStatus ? Colors.orange : Colors.green,
        ),
      );
      setState(() {
        _stationsFuture = adminService.getAdminStations();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update maintenance status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Stations')),
      body: FutureBuilder<List<Station>>(
        future: _stationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: \${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No stations found'));
          }

          final stations = snapshot.data!;

          return ListView.builder(
            itemCount: stations.length,
            itemBuilder: (context, index) {
              final station = stations[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: ListTile(
                  title: Text(station.name),
                  // Location display removed as requested
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.ev_station,
                        color:
                            station.isAvailable
                                ? Colors.green
                                : station.maintenance
                                ? Colors.orange
                                : Colors.red,
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => _toggleMaintenance(station),
                        child: Text(
                          station.maintenance
                              ? 'End Maintenance'
                              : 'Maintenance',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
