import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/payment_service.dart';
import '../services/booking_service.dart';
import '../models/booking.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class PaymentStatusScreen extends StatefulWidget {
  final String orderId;
  final int bookingId;
  final int paymentId;
  final bool isCancelled;

  const PaymentStatusScreen({
    super.key,
    required this.orderId,
    required this.bookingId,
    required this.paymentId,
    this.isCancelled = false,
  });

  @override
  PaymentStatusScreenState createState() => PaymentStatusScreenState();
}

class PaymentStatusScreenState extends State<PaymentStatusScreen> {
  bool _isLoading = true;
  String _paymentStatus = 'PENDING';
  String _message = '';
  Booking? _booking;
  Timer? _pollTimer;
  int _pollAttempts = 0;
  final int _maxPollAttempts = 5;

  @override
  void initState() {
    super.initState();
    _processPayment();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _processPayment() async {
    if (widget.isCancelled) {
      _handleCancelledPayment();
    } else {
      // Instead of handling the payment return, we'll just check the status
      // since the capture was already handled in PaymentWebViewScreen
      _checkPaymentStatus();
    }
  }

  Future<void> _checkPaymentStatus() async {
    setState(() {
      _isLoading = true;
      _message = 'Checking payment status...';
    });

    int retryCount = 0;
    const int maxRetries = 5;
    const Duration retryDelay = Duration(seconds: 3);

    while (retryCount < maxRetries) {
      try {
        final paymentService = Provider.of<PaymentService>(
          context,
          listen: false,
        );

        // Use new verifyOrderByOrderId method instead of getPaymentStatus
        final verifyResult = await paymentService.verifyOrderByOrderId(
          widget.orderId,
        );
        print(verifyResult);

        if (verifyResult != null && verifyResult['verified'] == true) {
          if (!mounted) return;
          setState(() {
            _paymentStatus = 'COMPLETED';
            _message = 'Payment completed successfully!';
            _isLoading = false;
          });

          // Load booking details
          _fetchBookingDetails();
          return;
        } else if (verifyResult != null) {
          // Payment exists but is not completed
          if (!mounted) return;
          setState(() {
            _paymentStatus =
                (verifyResult['order_status'] ?? 'PENDING')
                    .toString()
                    .toUpperCase();
            _message = 'Payment is ${verifyResult['order_status']}';
            _isLoading = false;
          });

          // Start polling for status updates
          _startPollingPaymentStatus();
          return;
        } else {
          // Payment not found or error occurred
          retryCount++;
          if (retryCount >= maxRetries) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _message =
                  'Unable to retrieve payment status. Please check later.';
              _paymentStatus = 'UNKNOWN';
            });
            return;
          }
          await Future.delayed(retryDelay);
        }
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _message = 'Error checking payment status: $e';
            _paymentStatus = 'ERROR';
          });
          return;
        }
        await Future.delayed(retryDelay);
      }
    }
  }

  Future<void> _handleCancelledPayment() async {
    setState(() {
      _isLoading = true;
      _message = 'Processing cancellation...';
    });

    try {
      final paymentService = Provider.of<PaymentService>(
        context,
        listen: false,
      );

      // Handle the payment cancellation
      final result = await paymentService.handlePaymentCancellation(
        widget.bookingId,
      );

      setState(() {
        _isLoading = false;
        _paymentStatus = result['paymentStatus'];
        _message = result['message'];
      });

      // Load booking details (still in pending state)
      _fetchBookingDetails();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _message = 'Error handling cancellation: $e';
        _paymentStatus = 'ERROR';
      });
    }
  }

  void _startPollingPaymentStatus() {
    // Poll every 3 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      _pollAttempts++;

      if (_pollAttempts > _maxPollAttempts) {
        timer.cancel();
        setState(() {
          _message =
              'Payment processing is taking longer than expected. Please check your booking status later.';
        });
        return;
      }

      try {
        final paymentService = Provider.of<PaymentService>(
          context,
          listen: false,
        );
        final verifyResult = await paymentService.verifyOrderByOrderId(
          widget.orderId,
        );

        if (verifyResult != null) {
          final status =
              (verifyResult['order_status'] ?? 'UNKNOWN')
                  .toString()
                  .toUpperCase();
          setState(() {
            _paymentStatus = status;
          });

          // If payment is completed, stop polling
          if (status == 'COMPLETED') {
            timer.cancel();
            setState(() {
              _message = 'Payment completed successfully!';
            });
            _fetchBookingDetails();
          }
        }
      } catch (e) {
        print('Error polling payment status: $e');
      }
    });
  }

  Future<void> _fetchBookingDetails() async {
    try {
      final bookingService = Provider.of<BookingService>(
        context,
        listen: false,
      );

      // Use getBookingWithPayment instead of getBooking
      final booking = await bookingService.getBookingWithPayment(
        widget.bookingId,
      );

      if (mounted) {
        setState(() {
          _booking = booking.booking;
        });
      }
    } catch (e) {
      print('Error fetching booking details: $e');
    }
  }

  Future<void> _retryPayment() async {
    // Get the booking details first
    if (_booking == null) {
      await _fetchBookingDetails();
    }

    if (_booking == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot retry payment: booking details not available'),
        ),
      );
      return;
    }

    // Navigate back to bookings and show the payment option
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/bookings',
      (route) => false, // Clear all routes
    );
  }

  Widget _buildPaymentStatusIcon() {
    IconData icon;
    Color color;

    switch (_paymentStatus) {
      case 'COMPLETED':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'CANCELLED':
        icon = Icons.cancel;
        color = Colors.red;
        break;
      case 'PENDING':
        icon = Icons.access_time;
        color = Colors.orange;
        break;
      case 'ERROR':
        icon = Icons.error;
        color = Colors.red;
        break;
      default:
        icon = Icons.help;
        color = Colors.grey;
    }

    return Column(
      children: [
        Icon(icon, size: 80, color: color),
        const SizedBox(height: 16),
        Text(
          _paymentStatus,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildBookingDetails() {
    if (_booking == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Booking Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildDetailRow(
              'Station',
              _booking!.stationName ?? 'Unknown Station',
            ),
            _buildDetailRow(
              'Date',
              _booking!.bookingDate != null
                  ? DateFormat('MMM dd, yyyy').format(_booking!.bookingDate!)
                  : 'N/A',
            ),
            _buildDetailRow(
              'Time',
              _booking!.startTime != null
                  ? DateFormat('hh:mm a').format(_booking!.startTime!)
                  : 'N/A',
            ),
            _buildDetailRow(
              'Duration',
              '${_booking!.durationMinutes ?? 0} minutes',
            ),
            _buildDetailRow('Status', _booking!.status ?? 'Unknown'),
            if (_booking!.totalCost != null)
              _buildDetailRow(
                'Amount',
                '₹${_booking!.totalCost!.toStringAsFixed(2)}',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Status')),
      body:
          _isLoading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    Text(
                      _message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              )
              : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      _buildPaymentStatusIcon(),
                      const SizedBox(height: 24),
                      Text(
                        _message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 32),
                      _buildBookingDetails(),
                      const SizedBox(height: 32),
                      if (_paymentStatus == 'CANCELLED' ||
                          _paymentStatus == 'ERROR')
                        ElevatedButton.icon(
                          icon: const Icon(Icons.replay),
                          label: const Text('Retry Payment'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                          ),
                          onPressed: _retryPayment,
                        ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        icon: const Icon(Icons.home),
                        label: const Text('Back to Home'),
                        onPressed: () {
                          Navigator.of(
                            context,
                          ).pushNamedAndRemoveUntil('/home', (route) => false);
                        },
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
