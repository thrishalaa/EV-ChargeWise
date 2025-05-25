import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/admin_service.dart';
import '../models/booking.dart';
import '../models/station.dart';

class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({Key? key}) : super(key: key);

  @override
  _AdminBookingsScreenState createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  late Future<List<Booking>> _bookingsFuture;
  List<Station> _stations = [];
  Station? _selectedStation;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadStations();
    _fetchBookings();
  }

  void _loadStations() async {
    final adminService = Provider.of<AdminService>(context, listen: false);
    final stations = await adminService.getAdminStations();
    setState(() {
      _stations = stations;
    });
  }

  void _fetchBookings() {
    final adminService = Provider.of<AdminService>(context, listen: false);
    setState(() {
      _bookingsFuture = adminService.getAdminBookings(
        startDate: _startDate,
        endDate: _endDate,
        stationId: _selectedStation?.id,
      );
    });
  }

  void _onStationChanged(Station? station) {
    setState(() {
      _selectedStation = station;
    });
    _fetchBookings();
  }

  // Reset station selection
  void _clearStationFilter() {
    setState(() {
      _selectedStation = null;
    });
    _fetchBookings();
  }

  Widget _getStatusIcon(String? status) {
    IconData iconData;
    Color iconColor;

    switch (status?.toLowerCase()) {
      case 'active':
        iconData = Icons.ev_station;
        iconColor = Colors.green;
        break;
      case 'pending':
        iconData = Icons.schedule;
        iconColor = Colors.orange;
        break;
      case 'completed':
        iconData = Icons.check_circle;
        iconColor = Colors.blue;
        break;
      case 'cancelled':
        iconData = Icons.cancel;
        iconColor = Colors.red;
        break;
      default:
        iconData = Icons.help_outline;
        iconColor = Colors.grey;
    }

    return CircleAvatar(
      backgroundColor: iconColor.withOpacity(0.2),
      radius: 16, // Consistent size
      child: Icon(iconData, color: iconColor, size: 16),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showBookingDetails(Booking booking) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(20),
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _getStatusIcon(booking.status),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Booking Details',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildDetailRow(
                      'Station',
                      booking.stationName ?? 'Unknown',
                      Icons.ev_station,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Status',
                      booking.status ?? 'Unknown',
                      Icons.info_outline,
                      valueColor: _getStatusColor(booking.status),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Start Time',
                      booking.startTime != null
                          ? DateFormat(
                            'MMM dd, yyyy - h:mm a',
                          ).format(booking.startTime!.toLocal())
                          : 'N/A',
                      Icons.access_time,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'End Time',
                      booking.endTime != null
                          ? DateFormat(
                            'MMM dd, yyyy - h:mm a',
                          ).format(booking.endTime!.toLocal())
                          : 'N/A',
                      Icons.access_alarm,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Duration',
                      '${booking.durationMinutes ?? 'N/A'} minutes',
                      Icons.timer,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: valueColor,
                ),
                softWrap: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, top: 8, bottom: 8),
            child: Text(
              'Filter Bookings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: InputDecorator(
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    isDense: true,
                  ),
                  isEmpty: _selectedStation == null,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Station>(
                      isExpanded: true,
                      hint: const Text('Select Station'),
                      value: _selectedStation,
                      isDense: true,
                      items:
                          _stations.map((station) {
                            return DropdownMenuItem<Station>(
                              value: station,
                              child: Text(
                                station.name ?? 'Unknown Station',
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                      onChanged: _onStationChanged,
                    ),
                  ),
                ),
              ),
              if (_selectedStation != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: _clearStationFilter,
                  tooltip: 'Clear station filter',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Bookings'), elevation: 0),
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: FutureBuilder<List<Booking>>(
              future: _bookingsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading bookings',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            '${snapshot.error}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: Colors.grey[400],
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No bookings found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your filters',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final bookings = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final booking = bookings[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 16,
                      ),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _showBookingDetails(booking),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _getStatusIcon(booking.status),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      booking.stationName ?? 'Unknown Station',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    const SizedBox(height: 4),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        return constraints.maxWidth < 180
                                            ? Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                _buildTimeRow(booking),
                                                const SizedBox(height: 4),
                                                _buildStatusBadge(booking),
                                              ],
                                            )
                                            : Row(
                                              children: [
                                                Expanded(
                                                  child: _buildTimeRow(booking),
                                                ),
                                                const SizedBox(width: 8),
                                                _buildStatusBadge(booking),
                                              ],
                                            );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: () => _showBookingDetails(booking),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                iconSize: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRow(Booking booking) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            booking.startTime != null
                ? DateFormat(
                  'MMM dd, yyyy - h:mm a',
                ).format(booking.startTime!.toLocal())
                : 'Date not available',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(Booking booking) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getStatusColor(booking.status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        booking.status ?? 'Unknown',
        style: TextStyle(
          color: _getStatusColor(booking.status),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
