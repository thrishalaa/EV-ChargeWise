import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/admin_service.dart';
import '../models/station.dart';

class AdminStationMaintenanceScreen extends StatefulWidget {
  const AdminStationMaintenanceScreen({Key? key}) : super(key: key);

  @override
  _AdminStationMaintenanceScreenState createState() =>
      _AdminStationMaintenanceScreenState();
}

class _AdminStationMaintenanceScreenState
    extends State<AdminStationMaintenanceScreen> {
  late Future<List<Station>> _stationsFuture;
  Map<int, bool> _maintenanceStatus = {};

  @override
  void initState() {
    super.initState();
    final adminService = Provider.of<AdminService>(context, listen: false);
    _stationsFuture = adminService.getAdminStations();
    _stationsFuture.then((stations) {
      setState(() {
        for (var station in stations) {
          // Assuming the maintenance status is stored in a field named 'maintenance' or similar
          _maintenanceStatus[station.id] = station.maintenance;
        }
      });
    });
  }

  Future<void> _toggleMaintenance(int stationId, bool currentStatus) async {
    final adminService = Provider.of<AdminService>(context, listen: false);
    try {
      await adminService.setStationMaintenance(stationId, !currentStatus);
      setState(() {
        _maintenanceStatus[stationId] = !currentStatus;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Maintenance status updated')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update maintenance status: \$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Station Maintenance')),
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
              final isMaintenance = _maintenanceStatus[station.id] ?? false;
              return ListTile(
                title: Text(station.name),
                trailing: Switch(
                  value: isMaintenance,
                  onChanged: (value) {
                    _toggleMaintenance(station.id, isMaintenance);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
