import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/booking_service.dart';
import '../services/payment_service.dart';
import 'payment_status_screen.dart';

class PaymentWebViewScreen extends StatefulWidget {
  final String approvalUrl;
  final int bookingId;
  final int paymentId;
  final String orderId;

  const PaymentWebViewScreen({
    Key? key,
    required this.approvalUrl,
    required this.bookingId,
    required this.paymentId,
    required this.orderId,
  }) : super(key: key);

  @override
  _PaymentWebViewScreenState createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  late PaymentService _paymentService;

  @override
  void initState() {
    super.initState();
    _paymentService = PaymentService(
      baseUrl: 'http://192.168.200.165:8000',
    ); // Adjust baseUrl as needed
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (String url) {
                setState(() {
                  _isLoading = true;
                });
              },
              onPageFinished: (String url) {
                setState(() {
                  _isLoading = false;
                });

                // No URL checking logic here, as per requirement
              },
              onNavigationRequest: (NavigationRequest request) {
                // Let all navigation happen without checking URLs
                return NavigationDecision.navigate;
              },
            ),
          )
          ..loadRequest(Uri.parse(widget.approvalUrl));
  }

  Future<void> _setAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null) {
      _paymentService.authToken = token;
    }
  }

  Future<void> _updateBookingStatus() async {
    try {
      final bookingService = Provider.of<BookingService>(
        context,
        listen: false,
      );
      await bookingService.getBookingWithPayment(widget.bookingId);
    } catch (e) {
      print('Error updating booking status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () async {
              // Set auth token before capture
              await _setAuthToken();

              // When the user clicks this button, capture the payment
              // This replaces the automatic URL checking
              final orderId = widget.orderId;

              // Capture the payment via PaymentService
              final captureResult = await _paymentService.capturePaypalPayment(
                orderId: orderId,
                paymentId: widget.paymentId,
              );

              if (captureResult['success'] == true) {
                // Update booking status after successful capture
                await _updateBookingStatus();
              } else {
                print('Payment capture failed: ${captureResult['message']}');
              }

              // Navigate back and to payment status screen
              if (!mounted) return;

              Navigator.of(context).pop(true);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (context) => Provider<PaymentService>.value(
                        value: _paymentService,
                        child: PaymentStatusScreen(
                          orderId: orderId,
                          bookingId: widget.bookingId,
                          paymentId: widget.paymentId,
                          isCancelled: false,
                        ),
                      ),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
