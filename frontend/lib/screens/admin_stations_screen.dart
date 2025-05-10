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
              return ListTile(
                title: Text(station.name),
                subtitle: Text('Location: \${station.location ?? "Unknown"}'),
                trailing: Icon(Icons.ev_station),
                onTap: () {
                  // TODO: Navigate to station maintenance screen or details
                },
              );
            },
          );
        },
      ),
    );
  }
}
