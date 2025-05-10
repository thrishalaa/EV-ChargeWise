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
  // Add PaymentService as a parameter
  final PaymentService paymentService;

  const PaymentWebViewScreen({
    Key? key,
    required this.approvalUrl,
    required this.bookingId,
    required this.paymentId,
    required this.orderId,
    required this.paymentService,
  }) : super(key: key);

  @override
  _PaymentWebViewScreenState createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isProcessingPayment = false;
  // Store PaymentService locally
  late final PaymentService _paymentService;

  @override
  void initState() {
    super.initState();
    // Initialize PaymentService from widget or from the nearest Provider
    _initializePaymentService();

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

  void _initializePaymentService() {
    if (widget.paymentService != null) {
      // Use the provided PaymentService if available
      _paymentService = widget.paymentService!;
    } else {
      try {
        // Attempt to get PaymentService from the nearest Provider
        _paymentService = Provider.of<PaymentService>(context, listen: false);
      } catch (e) {
        // Fall back to creating a new instance if necessary
        // Note: This is not ideal but prevents crashes
        print(
          'Warning: Creating new PaymentService instance - ${e.toString()}',
        );
        _paymentService = PaymentService(baseUrl: 'http://192.168.100.9:8000');
      }
    }
  }

  Future<void> _setAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null) {
      _paymentService.setAuthToken(token);
    }
  }

  Future<void> _capturePayment() async {
    if (_isProcessingPayment) return; // Prevent multiple calls

    setState(() {
      _isProcessingPayment = true;
    });

    try {
      // Set auth token before capture
      await _setAuthToken();

      // Show capturing dialog
      if (!mounted) return;
      _showProcessingDialog();

      print('Starting payment capture for order: ${widget.orderId}');

      // Capture the payment via PaymentService
      final captureResult = await _paymentService.capturePaypalPayment(
        orderId: widget.orderId,
        paymentId: widget.paymentId,
      );

      // Remove the dialog
      if (!mounted) return;
      Navigator.of(context).pop();

      if (captureResult['success'] == true) {
        print('Payment captured successfully!');

        // Navigate back and to payment status screen
        if (!mounted) return;
        Navigator.of(context).pop(true);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (context) =>
                // Pass the PaymentService to the next screen to maintain context
                ChangeNotifierProvider.value(
                  value: _paymentService,
                  child: PaymentStatusScreen(
                    orderId: widget.orderId,
                    bookingId: widget.bookingId,
                    paymentId: widget.paymentId,
                    isCancelled: false,
                  ),
                ),
          ),
        );
      } else {
        print('Payment capture failed: ${captureResult['message']}');
        if (!mounted) return;
        _showErrorDialog(
          captureResult['message'] ?? 'Failed to capture payment',
        );

        setState(() {
          _isProcessingPayment = false;
        });
      }
    } catch (e) {
      print('Error processing payment: $e');

      // Remove the dialog if it's showing
      if (!mounted) return;
      Navigator.of(context).pop();

      _showErrorDialog('Error processing payment: $e');

      setState(() {
        _isProcessingPayment = false;
      });
    }
  }

  void _showProcessingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text('Processing payment...'),
                SizedBox(height: 10),
                Text(
                  'Please do not close this window.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Payment Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        actions: [
          IconButton(
            icon:
                _isProcessingPayment
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.0,
                      ),
                    )
                    : const Icon(Icons.check),
            onPressed: _isProcessingPayment ? null : _capturePayment,
            tooltip: 'Complete Payment',
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
