import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/booking_service.dart';
import '../services/station_service.dart';
import '../services/payment_service.dart';
import '../models/booking.dart';
import 'package:intl/intl.dart';
import '../models/station.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'payment_webview_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  BookingsScreenState createState() => BookingsScreenState();
}

class BookingsScreenState extends State<BookingsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Booking> _bookings = [];
  List<Station> _searchResults = [];
  List<Station> _recentStations = [];
  String? _errorMessage;
  String _searchQuery = '';
  bool _isSearching = false;
  Position? _currentPosition;
  late TabController _tabController;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _determinePosition().then((_) {
      _fetchBookings();
      _fetchRecentStations();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Get current user location
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      // Test if location services are enabled.
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services are not enabled
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled.')),
          );
        }
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Permissions are denied
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Permissions are permanently denied
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permissions are permanently denied, we cannot request permissions.',
              ),
            ),
          );
        }
        return;
      }

      // When we reach here, permissions are granted and we can
      // continue accessing the position of the device.
      _currentPosition = await Geolocator.getCurrentPosition();
    } catch (e) {
      print('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to get current location')),
        );
      }
    }
  }

  Future<void> _fetchBookings() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bookingService = Provider.of<BookingService>(
        context,
        listen: false,
      );
      final List<BookingWithPayment> bookingsWithPayment = [];

      final bookings = await bookingService.getUserBookings();

      // Introduce a small delay to ensure the booking service can process
      await Future.delayed(const Duration(milliseconds: 300));

      for (var booking in bookings) {
        try {
          final bookingWithPayment = await bookingService.getBookingWithPayment(
            booking.id,
          );
          bookingsWithPayment.add(bookingWithPayment);
        } catch (e) {
          // If fetching bookingWithPayment fails, fallback to booking only
          bookingsWithPayment.add(BookingWithPayment(booking: booking));
        }
      }

      if (mounted) {
        setState(() {
          _bookings =
              bookingsWithPayment.map((bwp) {
                final booking = bwp.booking;
                final stationName = booking.stationName;
                if (stationName == null || stationName.isEmpty) {
                  return booking.copyWith(stationName: 'Unknown Station');
                }
                return booking;
              }).toList();

          // Sort bookings by status priority and then by date descending
          final statusPriority = {
            'active': 1,
            'completed': 1,
            'pending': 2,
            'cancelled': 3,
          };

          int getStatusPriority(String? status) {
            if (status == null) return 4;
            return statusPriority[status.toLowerCase()] ?? 4;
          }

          _bookings.sort((a, b) {
            final aPriority = getStatusPriority(a.status);
            final bPriority = getStatusPriority(b.status);
            if (aPriority != bPriority) {
              return aPriority.compareTo(bPriority);
            }
            return (b.bookingDate ?? DateTime.now()).compareTo(
              a.bookingDate ?? DateTime.now(),
            );
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load bookings: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showStationDetailsDialog(Station station) {
    int durationMinutes = 60;
    DateTime? selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay? selectedTime = TimeOfDay.now();
    String kilowatt = '';
    double pricePerKwh = 0.0;
    double cost = 0.0;

    if (station.chargingConfigs.isNotEmpty) {
      final config = station.chargingConfigs.first;
      kilowatt = '${config.powerOutput?.toStringAsFixed(1) ?? ''} kW';
      pricePerKwh = config.costPerKwh ?? 0.0;
      // Fix: Calculate the initial cost properly
      cost = (durationMinutes / 60) * pricePerKwh;
    }

    void calculateCost(StateSetter setState) {
      if (selectedDate != null && selectedTime != null) {
        setState(() {
          // Fix: Calculate the updated cost correctly based on the duration and price per kWh
          cost = (durationMinutes / 60) * pricePerKwh;
        });
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(station.name),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.power, color: Colors.blue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Power: $kilowatt',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.currency_rupee,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Price: ₹$pricePerKwh per kWh',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Select Booking Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.calendar_month),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[50],
                              foregroundColor: Colors.blue[700],
                              elevation: 0,
                            ),
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: selectedDate ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (date != null) {
                                setState(() {
                                  selectedDate = date;
                                });
                                calculateCost(setState);
                              }
                            },
                            label: Text(
                              selectedDate == null
                                  ? 'Select Date'
                                  : 'Date: ${DateFormat('MMM dd, yyyy').format(selectedDate!)}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.access_time),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[50],
                              foregroundColor: Colors.blue[700],
                              elevation: 0,
                            ),
                            onPressed: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: selectedTime ?? TimeOfDay.now(),
                              );
                              if (time != null) {
                                setState(() {
                                  selectedTime = time;
                                });
                                calculateCost(setState);
                              }
                            },
                            label: Text(
                              selectedTime == null
                                  ? 'Select Time'
                                  : 'Time: ${selectedTime!.format(context)}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Duration: $durationMinutes minutes',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Slider(
                      value: durationMinutes.toDouble(),
                      min: 15,
                      max: 240,
                      divisions: 15,
                      label: '$durationMinutes',
                      activeColor: Colors.blue,
                      onChanged: (value) {
                        setState(() {
                          durationMinutes = value.toInt();
                        });
                        calculateCost(setState);
                      },
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Estimated Cost:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '₹${cost.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.ev_station),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (selectedDate == null || selectedTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select date and time'),
                        ),
                      );
                      return;
                    }
                    // Create booking
                    DateTime startDateTime = DateTime(
                      selectedDate!.year,
                      selectedDate!.month,
                      selectedDate!.day,
                      selectedTime!.hour,
                      selectedTime!.minute,
                    );

                    final currentContext = context;

                    try {
                      final bookingService = Provider.of<BookingService>(
                        currentContext,
                        listen: false,
                      );
                      final paymentService = Provider.of<PaymentService>(
                        currentContext,
                        listen: false,
                      );
                      // Calculate end_time and total_cost
                      DateTime endDateTime = startDateTime.add(
                        Duration(minutes: durationMinutes),
                      );
                      double totalCost = 0.0;
                      if (station.chargingConfigs.isNotEmpty) {
                        final config = station.chargingConfigs.first;
                        totalCost =
                            (durationMinutes / 60) * (config.costPerKwh ?? 0.0);
                      }

                      final response = await bookingService.createBooking({
                        'station_id': station.id,
                        'start_time': startDateTime.toIso8601String(),
                        'end_time': endDateTime.toIso8601String(),
                        'total_cost': totalCost,
                      });

                      if (!mounted) return;

                      Navigator.of(currentContext).pop();

                      if (response != null && response['payment'] != null) {
                        final approvalLink =
                            response['payment']['approval_link'];
                        if (approvalLink != null) {
                          // Launch the payment link in a webview screen
                          try {
                            final bookingId = response['booking']['id'];
                            final paymentId = response['payment']['id'];
                            final orderId = response['payment']['order_id'];
                            Navigator.of(currentContext).push(
                              MaterialPageRoute(
                                builder:
                                    (context) => PaymentWebViewScreen(
                                      approvalUrl: approvalLink,
                                      bookingId: bookingId,
                                      paymentId: paymentId,
                                      orderId: orderId,
                                      paymentService: paymentService,
                                    ),
                              ),
                            );
                          } catch (e) {
                            // If we can't launch, show dialog
                            if (mounted) {
                              showDialog(
                                context: currentContext,
                                builder: (context) {
                                  return AlertDialog(
                                    title: const Text('Complete Payment'),
                                    content: Text(
                                      'Please complete your payment by visiting the following link:\n$approvalLink',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: const Text('Close'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            }
                          }
                        }
                      }

                      if (mounted) {
                        ScaffoldMessenger.of(currentContext).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Booking successful! Refreshing your bookings...',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }

                      // Refresh bookings list
                      await _fetchBookings();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(currentContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Failed to create booking: ${e.toString()}',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  label: const Text('Book Now'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _fetchRecentStations() async {
    try {
      final stationService = Provider.of<StationService>(
        context,
        listen: false,
      );
      final recentStations = await stationService.getRecentBookedStations();
      if (mounted) {
        setState(() {
          _recentStations = recentStations;
        });
      }
    } catch (e) {
      print('Error fetching recent stations: $e');
      // We'll handle this error silently in the UI
    }
  }

  Future<void> _searchStations(String query) async {
    if (!mounted) return;

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _searchQuery = query; // Update search query state
    });

    try {
      final stationService = Provider.of<StationService>(
        context,
        listen: false,
      );
      final results = await stationService.searchStationsByName(query);
      print('Search results for "$query": $results');

      if (mounted) {
        setState(() {
          _searchResults = results;
        });
      }
    } catch (e) {
      print('Error during station search: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to search stations: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _cancelBooking(int bookingId) async {
    // Show loading indicator
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Cancelling booking...'),
              ],
            ),
          ),
    );

    try {
      final bookingService = Provider.of<BookingService>(
        context,
        listen: false,
      );

      // Add a slight delay to ensure the request is processed
      await Future.delayed(const Duration(milliseconds: 500));

      // Make the cancellation request
      await bookingService.cancelBooking(bookingId);

      // Close the loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Refresh the bookings list after successful cancellation
      if (mounted) {
        // Add a slight delay to ensure the backend has processed the cancellation
        await Future.delayed(const Duration(milliseconds: 500));
        await _fetchBookings();
      }
    } catch (e) {
      // Close the loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling booking: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Focus(
        onFocusChange: (hasFocus) {
          if (hasFocus && _searchQuery.isEmpty) {
            _fetchNearbyStationsForSuggestion();
          }
        },
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search charging stations',
            prefixIcon: const Icon(Icons.search, color: Colors.blue),
            suffixIcon:
                _searchQuery.isNotEmpty
                    ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults = [];
                          _searchQuery = '';
                        });
                      },
                    )
                    : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.grey[200],
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
          ),
          onChanged: (value) {
            if (value.isNotEmpty) {
              _searchStations(value);
            } else {
              setState(() {
                _searchResults = [];
                _searchQuery = '';
              });
            }
          },
        ),
      ),
    );
  }

  Future<void> _fetchNearbyStationsForSuggestion() async {
    if (_currentPosition == null) {
      // If location is not available, display a message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location not available. Using default location.'),
          ),
        );
      }
      return;
    }

    try {
      final stationService = Provider.of<StationService>(
        context,
        listen: false,
      );

      final nearbyStations = await stationService.searchNearbyStations(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      if (mounted) {
        setState(() {
          _searchResults = nearbyStations;
        });
      }
    } catch (e) {
      // Handle error silently or show message if needed
      print('Error fetching nearby stations: $e');
    }
  }

  Future<void> _viewBookingDetails(Booking booking) async {
    try {
      final bookingService = Provider.of<BookingService>(
        context,
        listen: false,
      );
      final bookingWithPayment = await bookingService.getBookingWithPayment(
        booking.id,
      );

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: const [
                Flexible(
                  child: Text(
                    'Booking Details',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    softWrap: true,
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _getStatusColor(booking.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
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
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Status: ${booking.status ?? 'Unknown'}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _getStatusColor(
                                            booking.status,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      'Date',
                      booking.startTime != null
                          ? DateFormat(
                            'MMM dd, yyyy',
                          ).format(booking.startTime!)
                          : 'N/A',
                      Icons.calendar_today,
                    ),
                    _buildDetailRow(
                      'Time',
                      booking.startTime != null
                          ? DateFormat('hh:mm a').format(booking.startTime!)
                          : 'N/A',
                      Icons.access_time,
                    ),
                    _buildDetailRow(
                      'Duration',
                      booking.durationMinutes != null &&
                              booking.durationMinutes! > 0
                          ? '${booking.durationMinutes} minutes'
                          : 'N/A',
                      Icons.timer,
                    ),
                    _buildDetailRow(
                      'Payment Status',
                      (bookingWithPayment.payment?.status != null &&
                              bookingWithPayment.payment!.status!.isNotEmpty)
                          ? bookingWithPayment.payment!.status!
                          : (booking.status != null &&
                              booking.status!.toLowerCase() == 'completed')
                          ? 'Paid'
                          : 'Not paid',
                      Icons.payment,
                    ),
                    if (bookingWithPayment.payment != null)
                      _buildDetailRow(
                        'Amount',
                        '${bookingWithPayment.payment?.amount} ${bookingWithPayment.payment?.currency}',
                        Icons.currency_rupee,
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              // Remove cancel and complete payment buttons for completed bookings
              if (booking.status != 'cancelled' &&
                  booking.status != 'completed')
                TextButton.icon(
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showCancellationConfirmDialog(booking.id);
                  },
                  label: const Text('Cancel Booking'),
                ),
              if (bookingWithPayment.payment?.status != 'COMPLETED' &&
                  booking.status != 'cancelled' &&
                  booking.status != 'completed')
                TextButton.icon(
                  icon: const Icon(Icons.payment, color: Colors.green),
                  style: TextButton.styleFrom(foregroundColor: Colors.green),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _navigateToPayment(booking, bookingWithPayment.payment?.id);
                  },
                  label: const Text('Complete Payment'),
                ),
              TextButton.icon(
                icon: const Icon(Icons.close),
                label: const Text('Close'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load booking details: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCancellationConfirmDialog(int bookingId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Booking'),
          content: const Text('Are you sure you want to cancel this booking?'),
          actions: [
            TextButton(
              child: const Text('No'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                Navigator.of(context).pop();
                _cancelBooking(bookingId);
              },
              child: const Text('Yes, Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToPayment(Booking booking, int? paymentId) async {
    try {
      // Fix: Try to fetch payment link if not available in booking
      if (booking.paymentLink == null || booking.paymentLink!.isEmpty) {
        final bookingService = Provider.of<BookingService>(
          context,
          listen: false,
        );

        try {
          // Try to get updated payment link
          final bookingWithPayment = await bookingService.getBookingWithPayment(
            booking.id,
          );
          if (bookingWithPayment.payment?.approvalLink != null) {
            final Uri url = Uri.parse(
              bookingWithPayment.payment!.approvalLink!,
            );
            final launched = await launchUrl(
              url,
              mode: LaunchMode.externalApplication,
            );
            if (!launched) {
              throw Exception('Could not launch payment URL');
            }
            return;
          }
        } catch (e) {
          print('Error fetching payment link: $e');
          // Continue with fallback
        }
      } else {
        // Use existing payment link if available
        final launched = await launchUrl(
          Uri.parse(booking.paymentLink!),
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          throw Exception('Could not launch payment URL');
        }
        return;
      }
    } catch (e) {
      print('Error launching payment link: $e');
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Payment Error'),
            content: Text(
              'Unable to access payment link for booking #${booking.id}. Please try again later or contact support.\nError: $e',
            ),
            actions: [
              TextButton(
                child: const Text('Close'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
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

  Widget _buildSearchResultItem(Station station) {
    String kilowatt = '';
    String price = '';

    if (station.chargingConfigs.isNotEmpty) {
      final config = station.chargingConfigs.first;
      kilowatt = '${config.powerOutput?.toStringAsFixed(1) ?? ''} kW';
      price = config.costPerKwh != null ? '₹${config.costPerKwh} per kWh' : '';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _showStationDetailsDialog(station);
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.ev_station, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      station.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.electrical_services,
                    size: 18,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Power: $kilowatt',
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.currency_rupee,
                    size: 18,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Price: $price',
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (station.bookings != null && station.bookings!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Bookings:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...station.bookings!.map((booking) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              '- ${DateFormat('MMM dd, hh:mm a').format(booking.startTime)} to ${DateFormat('hh:mm a').format(booking.endTime)}',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentStationItem(Station station) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _showStationDetailsDialog(station);
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue.withOpacity(0.2),
                child: const Icon(Icons.history, color: Colors.blue),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text(
                      'Recently booked',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingItem(Booking booking) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _viewBookingDetails(booking),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _getStatusIcon(booking.status),
              const SizedBox(width: 16),
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
                    Text(
                      booking.startTime != null
                          ? DateFormat(
                            'MMM dd, yyyy • hh:mm a',
                          ).format(booking.startTime!)
                          : 'Date not available',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
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
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => _viewBookingDetails(booking),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab bar for navigation
        TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(icon: Icon(Icons.search), text: 'Find Stations'),
            Tab(icon: Icon(Icons.history), text: 'My Bookings'),
          ],
        ),

        // Tab views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Find Stations
              Column(
                children: [
                  _buildSearchBar(),
                  if (_searchQuery.isEmpty && _recentStations.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.history,
                            size: 18,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Recent Stations',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_searchQuery.isEmpty && _recentStations.isNotEmpty)
                    Expanded(
                      child: ListView.builder(
                        itemCount: _recentStations.length,
                        shrinkWrap: true,
                        itemBuilder: (context, index) {
                          final station = _recentStations[index];
                          return _buildRecentStationItem(station);
                        },
                      ),
                    ),
                  if (_searchQuery.isNotEmpty)
                    Expanded(
                      child:
                          _isSearching
                              ? const Center(child: CircularProgressIndicator())
                              : _searchResults.isEmpty
                              ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No stations found for "$_searchQuery"',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              )
                              : ListView.builder(
                                itemCount: _searchResults.length,
                                itemBuilder: (context, index) {
                                  final station = _searchResults[index];
                                  return _buildSearchResultItem(station);
                                },
                              ),
                    ),
                ],
              ),

              // Tab 2: My Bookings
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 80, color: Colors.red),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          onPressed: _fetchBookings,
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                  : _bookings.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.ev_station,
                          size: 80,
                          color: Colors.blueGrey,
                        ),
                        const SizedBox(height: 16),
                        const Text('No bookings found'),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.search),
                          onPressed: () {
                            _tabController.animateTo(0); // Switch to search tab
                          },
                          label: const Text('Find Stations'),
                        ),
                      ],
                    ),
                  )
                  : RefreshIndicator(
                    onRefresh: _fetchBookings,
                    child: ListView.builder(
                      itemCount: _bookings.length,
                      itemBuilder: (context, index) {
                        final booking = _bookings[index];
                        return _buildBookingItem(booking);
                      },
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
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
    child: Icon(iconData, color: iconColor),
  );
}
