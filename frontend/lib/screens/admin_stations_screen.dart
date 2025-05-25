import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/admin_service.dart';
import '../models/station.dart';

class AdminStationsScreen extends StatefulWidget {
  final VoidCallback? onMaintenanceChanged;

  const AdminStationsScreen({Key? key, this.onMaintenanceChanged})
    : super(key: key);

  @override
  _AdminStationsScreenState createState() => _AdminStationsScreenState();
}

class _AdminStationsScreenState extends State<AdminStationsScreen> {
  List<Station> _stations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    try {
      final adminService = Provider.of<AdminService>(context, listen: false);
      final stations = await adminService.getAdminStations();
      setState(() {
        _stations = stations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load stations: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleMaintenance(int stationIndex, bool newStatus) async {
    final station = _stations[stationIndex];
    final adminService = Provider.of<AdminService>(context, listen: false);

    print(
      'Toggling maintenance for station ${station.id} from ${station.maintenance} to $newStatus',
    );

    try {
      // Call the API to update maintenance status
      await adminService.setStationMaintenance(station.id, newStatus);

      // Update the local station object immediately after successful API call
      setState(() {
        _stations[stationIndex] = Station(
          id: station.id,
          name: station.name,
          latitude: station.latitude,
          longitude: station.longitude,
          isAvailable: station.isAvailable,
          maintenance: newStatus, // This is the key change
          chargingConfigs: station.chargingConfigs,
          distance: station.distance,
          bookings: station.bookings,
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Station "${station.name}" maintenance status set to ${newStatus ? 'ON' : 'OFF'}',
            ),
            backgroundColor: newStatus ? Colors.orange : Colors.green,
          ),
        );

        // Call the callback to refresh dashboard
        if (widget.onMaintenanceChanged != null) {
          widget.onMaintenanceChanged!();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update maintenance status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Stations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _loadStations();
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _stations.isEmpty
              ? const Center(child: Text('No stations found'))
              : ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: _stations.length,
                itemBuilder: (context, index) {
                  final station = _stations[index];

                  // Debug print
                  print(
                    'Station ${station.id} maintenance status: ${station.maintenance}',
                  );

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 4,
                    ),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Station name and status icon
                          Row(
                            children: [
                              Icon(
                                Icons.ev_station,
                                color:
                                    station.maintenance
                                        ? Colors.orange
                                        : station.isAvailable
                                        ? Colors.green
                                        : Colors.red,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  station.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Status and maintenance toggle row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Status text
                              Expanded(
                                child: Text(
                                  'Status: ${station.maintenance
                                      ? 'Under Maintenance'
                                      : station.isAvailable
                                      ? 'Available'
                                      : 'Unavailable'}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),

                              // Maintenance toggle
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Maintenance',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Transform.scale(
                                    scale: 0.8,
                                    child: Switch(
                                      value: station.maintenance,
                                      onChanged: (bool value) {
                                        _toggleMaintenance(index, value);
                                      },
                                      activeColor: Colors.orange,
                                      inactiveThumbColor: Colors.green,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
