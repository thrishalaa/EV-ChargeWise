import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/admin.dart';
import '../models/station.dart';
import '../services/super_admin_service.dart';
import '../services/admin_service.dart';

class StationAssignmentScreen extends StatefulWidget {
  const StationAssignmentScreen({Key? key}) : super(key: key);

  @override
  _StationAssignmentScreenState createState() =>
      _StationAssignmentScreenState();
}

class _StationAssignmentScreenState extends State<StationAssignmentScreen> {
  late Future<List<Admin>> _adminsFuture;
  late Future<List<Station>> _stationsFuture;
  bool _isLoading = false;
  int? _selectedAdminId;
  List<int> _selectedStationIds = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final superAdminService = Provider.of<SuperAdminService>(
      context,
      listen: false,
    );
    final adminService = Provider.of<AdminService>(context, listen: false);

    setState(() {
      _adminsFuture = superAdminService.getAllAdmins();
      _stationsFuture = adminService.getAdminStations();
      _selectedAdminId = null;
      _selectedStationIds = [];
    });
  }

  Future<void> _refreshData() async {
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildBody(),
        ),
        if (_selectedAdminId != null && _selectedStationIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: _assignStations,
              icon: const Icon(Icons.check),
              label: const Text('Assign Stations'),
            ),
          ),
      ],
    );
  }

  Widget _buildBody() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSelectAdminSection(),
                const SizedBox(height: 16),
                _selectedAdminId != null
                    ? Expanded(child: _buildSelectStationsSection())
                    : Expanded(
                      child: Center(
                        child: Text(
                          'Please select an admin first',
                          style: TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSelectAdminSection() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Admin',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _isLoading ? null : _refreshData,
                  tooltip: 'Refresh Data',
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Admin>>(
              future: _adminsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 48,
                    child: Center(
                      child: SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                } else if (snapshot.hasError) {
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No admins found'));
                }

                final admins = snapshot.data!;
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ButtonTheme(
                    alignedDropdown: true,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedAdminId,
                        isExpanded: true,
                        hint: const Text('Select an admin'),
                        icon: const Icon(Icons.arrow_drop_down),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        borderRadius: BorderRadius.circular(8),
                        itemHeight: null, // Allow dynamic height for items
                        onChanged: (int? value) {
                          setState(() {
                            _selectedAdminId = value;
                            _selectedStationIds = [];
                          });
                        },
                        items:
                            admins.map((Admin admin) {
                              return DropdownMenuItem<int>(
                                value: admin.id,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minHeight: 40,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4.0,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        admin.isSuperAdmin
                                            ? Icons.admin_panel_settings
                                            : Icons.person,
                                        color:
                                            admin.isSuperAdmin
                                                ? Colors.amber
                                                : Theme.of(
                                                  context,
                                                ).primaryColor,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              admin.username,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              admin.email,
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectStationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 2,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Available Stations',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: _selectAllStations,
                      icon: const Icon(Icons.select_all, size: 18),
                      label: const Text('All'),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: _clearSelection,
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('Clear'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<List<Station>>(
            future: _stationsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No stations found'));
              }

              final stations = snapshot.data!;
              return LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate item width based on screen size
                  final double width = constraints.maxWidth;
                  final int crossAxisCount = width > 600 ? 3 : 2;

                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      // Adjust aspect ratio for better fit
                      childAspectRatio: width > 600 ? 1.8 : 1.6,
                    ),
                    itemCount: stations.length,
                    itemBuilder: (context, index) {
                      final station = stations[index];
                      final isSelected = _selectedStationIds.contains(
                        station.id,
                      );

                      return Card(
                        color:
                            isSelected
                                ? Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.1)
                                : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color:
                                isSelected
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey.withOpacity(0.3),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedStationIds.remove(station.id);
                              } else {
                                _selectedStationIds.add(station.id);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.ev_station,
                                      size: 18,
                                      color:
                                          station.isAvailable
                                              ? Colors.green
                                              : station.maintenance
                                              ? Colors.orange
                                              : Colors.red,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        station.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: Checkbox(
                                        value: isSelected,
                                        visualDensity: VisualDensity.compact,
                                        onChanged: (bool? value) {
                                          setState(() {
                                            if (value == true) {
                                              _selectedStationIds.add(
                                                station.id,
                                              );
                                            } else {
                                              _selectedStationIds.remove(
                                                station.id,
                                              );
                                            }
                                          });
                                        },
                                        activeColor:
                                            Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Expanded(
                                  child: Text(
                                    '${station.latitude}, ${station.longitude}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        station.isAvailable
                                            ? Colors.green
                                            : station.maintenance
                                            ? Colors.orange
                                            : Colors.red,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    station.isAvailable
                                        ? 'Available'
                                        : station.maintenance
                                        ? 'Maintenance'
                                        : 'Unavailable',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        if (_selectedStationIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              '${_selectedStationIds.length} stations selected',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
      ],
    );
  }

  void _selectAllStations() async {
    final stations = await _stationsFuture;
    setState(() {
      _selectedStationIds = stations.map((station) => station.id).toList();
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedStationIds = [];
    });
  }

  Future<void> _assignStations() async {
    if (_selectedAdminId == null || _selectedStationIds.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final superAdminService = Provider.of<SuperAdminService>(
        context,
        listen: false,
      );

      final assignments =
          _selectedStationIds
              .map(
                (stationId) => {
                  'admin_id': _selectedAdminId!,
                  'station_id': stationId,
                },
              )
              .toList();

      await superAdminService.bulkAssignStations(assignments);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_selectedStationIds.length} stations assigned successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );

      _refreshData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error assigning stations: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
