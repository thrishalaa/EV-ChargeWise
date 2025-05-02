import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import '../screens/payment_status_screen.dart';

class DeepLinkHandler {
  static final DeepLinkHandler _instance = DeepLinkHandler._internal();
  factory DeepLinkHandler() => _instance;
  DeepLinkHandler._internal();

  static const MethodChannel _channel = MethodChannel(
    'app.channel.shared.data',
  );

  void initUniLinks(BuildContext context) {
    // Handle app started by a link
    _handleInitialLink(context);

    // Handle app resumed by a link
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final String? link = call.arguments as String?;
        if (link != null) {
          _handleLink(Uri.parse(link), context);
        }
      }
    });
  }

  Future<void> _handleInitialLink(BuildContext context) async {
    try {
      final String? initialLink = await _channel.invokeMethod('getInitialLink');
      if (initialLink != null) {
        _handleLink(Uri.parse(initialLink), context);
      }
    } on PlatformException {
      print('Failed to get initial link.');
    }
  }

  void _handleLink(Uri uri, BuildContext context) {
    print('Deep link received: $uri');

    if (uri.path == '/payment/return') {
      _handlePaymentReturn(uri, context);
    } else if (uri.path == '/payment/cancel') {
      _handlePaymentCancel(uri, context);
    }
  }

  void _handlePaymentReturn(Uri uri, BuildContext context) {
    final orderId = uri.queryParameters['order_id'];
    final bookingIdStr = uri.queryParameters['booking_id'];
    final paymentIdStr = uri.queryParameters['payment_id'];

    if (orderId != null && bookingIdStr != null && paymentIdStr != null) {
      try {
        final bookingId = int.parse(bookingIdStr);
        final paymentId = int.parse(paymentIdStr);

        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (context) => PaymentStatusScreen(
                  orderId: orderId,
                  bookingId: bookingId,
                  paymentId: paymentId,
                  isCancelled: false,
                ),
          ),
        );
      } catch (e) {
        print('Error parsing payment return parameters: $e');
        _showErrorSnackBar(context, 'Invalid payment return parameters');
      }
    } else {
      _showErrorSnackBar(context, 'Missing payment return parameters');
    }
  }

  void _handlePaymentCancel(Uri uri, BuildContext context) {
    final bookingIdStr = uri.queryParameters['booking_id'];
    final paymentIdStr = uri.queryParameters['payment_id'];

    if (bookingIdStr != null && paymentIdStr != null) {
      try {
        final bookingId = int.parse(bookingIdStr);
        final paymentId = int.parse(paymentIdStr);

        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (context) => PaymentStatusScreen(
                  orderId: '',
                  bookingId: bookingId,
                  paymentId: paymentId,
                  isCancelled: true,
                ),
          ),
        );
      } catch (e) {
        print('Error parsing payment cancel parameters: $e');
        _showErrorSnackBar(context, 'Invalid payment cancel parameters');
      }
    } else {
      _showErrorSnackBar(context, 'Missing payment cancel parameters');
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
