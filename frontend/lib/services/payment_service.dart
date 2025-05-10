import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/booking.dart';

class PaymentService with ChangeNotifier {
  final String baseUrl;
  String? authToken;

  PaymentService({required this.baseUrl, this.authToken});

  // Initialize with stored auth token
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    authToken = prefs.getString('auth_token');
  }

  // Set auth token (call this after login)
  void setAuthToken(String token) {
    authToken = token;
    notifyListeners();
  }

  // Create a payment order with PayPal
  Future<Map<String, dynamic>> createPaypalOrder({
    required int bookingId,
    required double amount,
    required String currency,
    required String successUrl,
    required String cancelUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/payments/create-paypal-order'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'booking_id': bookingId,
          'amount': amount,
          'currency': currency,
          'success_url': successUrl,
          'cancel_url': cancelUrl,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {
          'success': false,
          'message': 'Failed to create PayPal order: ${response.body}',
        };
      }
    } catch (e) {
      print('Exception creating PayPal order: $e');
      return {
        'success': false,
        'message': 'Exception creating PayPal order: $e',
      };
    }
  }

  // Capture a PayPal payment after user approves it
  Future<Map<String, dynamic>> capturePaypalPayment({
    required String orderId,
    required int paymentId,
  }) async {
    try {
      print(
        'Attempting to capture payment for order: $orderId and paymentId: $paymentId',
      );
      print('API URL: $baseUrl/payments/capture-order/$orderId');
      print('Auth token available: ${authToken != null}');

      final response = await http
          .post(
            Uri.parse('$baseUrl/payments/capture-order/$orderId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
          )
          .timeout(
            const Duration(seconds: 30), // Increased timeout
            onTimeout: () {
              print('Request timed out after 30 seconds');
              throw Exception(
                'Connection timed out. Please check your internet connection.',
              );
            },
          );

      print('Capture response status code: ${response.statusCode}');
      if (response.body.isNotEmpty) {
        print('Capture response body: ${response.body}');
      } else {
        print('Capture response body is empty');
      }

      if (response.statusCode == 200) {
        // Payment successfully captured
        // Booking status update is handled by backend capture_order API
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {
          'success': false,
          'message': 'Failed to capture payment: ${response.body}',
        };
      }
    } catch (e) {
      print('Exception during payment capture: $e');
      return {'success': false, 'message': 'Exception capturing payment: $e'};
    }
  }

  // Get booking ID associated with an order ID
  Future<int> _getBookingIdFromOrderId(String orderId) async {
    try {
      print('Getting booking ID for orderId: $orderId');
      final response = await http
          .get(
            Uri.parse('$baseUrl/payments/order/$orderId'),
            headers: {'Authorization': 'Bearer $authToken'},
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception(
                'Request timed out when getting booking ID from orderId',
              );
            },
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Payment data received for orderId: $data');
        return data['booking_id'] ?? 0;
      }
      print('Failed to get booking ID from orderId');
      return 0;
    } catch (e) {
      print('Error getting booking ID from orderId: $e');
      return 0;
    }
  }

  // Get booking ID associated with a payment
  Future<int> _getBookingIdFromPayment(int paymentId) async {
    try {
      print('Getting booking ID for payment: $paymentId');
      final response = await http
          .get(
            Uri.parse('$baseUrl/payments/$paymentId'),
            headers: {'Authorization': 'Bearer $authToken'},
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception('Request timed out when getting booking ID');
            },
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Payment data received: $data');
        return data['booking_id'] ?? 0;
      }
      print('Failed to get booking ID from payment');
      return 0;
    } catch (e) {
      print('Error getting booking ID from payment: $e');
      return 0;
    }
  }

  // Helper function to launch payment URL
  Future<bool> launchPaymentUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      print('Error launching URL: $e');
      return false;
    }
  }

  // Get payment status
  Future<Payment?> getPaymentStatus(int paymentId) async {
    try {
      print('Getting payment status for paymentId: $paymentId');
      print('API URL: $baseUrl/payments/$paymentId');

      final response = await http
          .get(
            Uri.parse('$baseUrl/payments/$paymentId'),
            headers: {'Authorization': 'Bearer $authToken'},
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              print('Payment status request timed out after 15 seconds');
              throw Exception(
                'Connection timed out when getting payment status',
              );
            },
          );

      print('Payment status response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Payment data received: $data');
        return Payment.fromJson(data);
      }
      print('Failed to get payment status');
      return null;
    } catch (e) {
      print('Error getting payment status: $e');
      return null;
    }
  }

  // Verify order by orderId using new backend API
  Future<Map<String, dynamic>?> verifyOrderByOrderId(String orderId) async {
    try {
      print('Verifying order for orderId: $orderId');
      final response = await http
          .post(
            Uri.parse(
              '$baseUrl/payments/verify-order/$orderId',
            ), // Fix: Updated endpoint path
            headers: {'Authorization': 'Bearer $authToken'},
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception('Request timed out when verifying order');
            },
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Order verification data received: $data');
        return data;
      } else if (response.statusCode == 404) {
        print('Order not found: ${response.body}');
        return {
          'verified': false,
          'order_status': 'NOT_FOUND',
          'message': 'Order not found',
        };
      } else {
        print(
          'Failed to verify order: ${response.statusCode} - ${response.body}',
        );
        return {
          'verified': false,
          'order_status': 'ERROR',
          'message': 'Failed to verify order',
        };
      }
    } catch (e) {
      print('Error verifying order: $e');
      return {
        'verified': false,
        'order_status': 'ERROR',
        'message': 'Error: $e',
      };
    }
  }

  // Handle payment return (from success URL)
  // NOTE: This is kept for backward compatibility but should not be used
  // Capture should be done directly through capturePaypalPayment
  Future<Map<String, dynamic>> handlePaymentReturn({
    required String orderId,
    required int bookingId,
    required int paymentId,
  }) async {
    try {
      print(
        'WARNING: handlePaymentReturn called - this method should be avoided',
      );

      // Check payment status first
      final payment = await getPaymentStatus(paymentId);

      if (payment != null && payment.status == 'completed') {
        // Payment is already completed, no need to capture again
        return {
          'success': true,
          'message': 'Payment already completed',
          'paymentStatus': 'COMPLETED',
        };
      }

      // 1. Capture the payment
      final captureResult = await capturePaypalPayment(
        orderId: orderId,
        paymentId: paymentId,
      );

      if (captureResult['success']) {
        return {
          'success': true,
          'message': 'Payment completed successfully',
          'paymentStatus': 'COMPLETED',
        };
      } else {
        return {
          'success': false,
          'message': 'Payment capture failed: ${captureResult['message']}',
          'paymentStatus': 'PENDING',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error processing payment return: $e',
        'paymentStatus': 'ERROR',
      };
    }
  }

  // Handle payment cancellation (from cancel URL)
  Future<Map<String, dynamic>> handlePaymentCancellation(int bookingId) async {
    try {
      final result = await _updateBookingStatus(
        bookingId: bookingId,
        status: 'pending', // Keep as pending since it can be retried
      );

      return {
        'success': result['success'],
        'message':
            result['success']
                ? 'Payment was cancelled'
                : 'Error updating booking after cancellation',
        'paymentStatus': 'CANCELLED',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error handling payment cancellation: $e',
        'paymentStatus': 'ERROR',
      };
    }
  }

  // Helper to update booking status
  Future<Map<String, dynamic>> _updateBookingStatus({
    required int bookingId,
    required String status,
  }) async {
    try {
      print('Updating booking $bookingId status to: $status');
      final response = await http
          .patch(
            Uri.parse('$baseUrl/bookings/$bookingId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({'status': status}),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception('Request timed out when updating booking status');
            },
          );

      print('Update booking status response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {
          'success': false,
          'message': 'Failed to update booking status: ${response.body}',
        };
      }
    } catch (e) {
      print('Exception updating booking status: $e');
      return {
        'success': false,
        'message': 'Exception updating booking status: $e',
      };
    }
  }
}
