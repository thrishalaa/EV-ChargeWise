import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/admin_service.dart';
import '../models/booking.dart';

class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({Key? key}) : super(key: key);

  @override
  _AdminBookingsScreenState createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  late Future<List<Booking>> _bookingsFuture;

  @override
  void initState() {
    super.initState();
    final adminService = Provider.of<AdminService>(context, listen: false);
    _bookingsFuture = adminService.getAdminBookings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Bookings')),
      body: FutureBuilder<List<Booking>>(
        future: _bookingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: \${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No bookings found'));
          }

          final bookings = snapshot.data!;

          return ListView.builder(
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              return ListTile(
                title: Text(booking.stationName ?? 'Unknown Station'),
                subtitle: Text('Status: \${booking.status ?? "Unknown"}'),
                trailing: Text(
                  booking.bookingDate != null
                      ? booking.bookingDate!.toLocal().toString().split(' ')[0]
                      : '',
                ),
                onTap: () {
                  // TODO: Show booking details or actions
                },
              );
            },
          );
        },
      ),
    );
  }
}
