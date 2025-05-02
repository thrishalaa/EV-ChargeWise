import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/booking.dart'; // Changed from '../models/payment.dart' to '../models/booking.dart'

class PaymentService {
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
      final response = await http.post(
        Uri.parse('$baseUrl/payments/capture-order/$orderId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {
          'success': false,
          'message': 'Failed to capture payment: ${response.body}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Exception capturing payment: $e'};
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
      final response = await http.get(
        Uri.parse('$baseUrl/payments/$paymentId'),
        headers: {'Authorization': 'Bearer $authToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Payment.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Error getting payment status: $e');
      return null;
    }
  }

  // Handle payment return (from success URL)
  Future<Map<String, dynamic>> handlePaymentReturn({
    required String orderId,
    required int bookingId,
    required int paymentId,
  }) async {
    try {
      // 1. Capture the payment
      final captureResult = await capturePaypalPayment(
        orderId: orderId,
        paymentId: paymentId,
      );

      if (captureResult['success']) {
        // 2. Update booking status
        final bookingUpdateResult = await _updateBookingStatus(
          bookingId: bookingId,
          status: 'completed',
        );

        if (bookingUpdateResult['success']) {
          return {
            'success': true,
            'message': 'Payment completed successfully',
            'paymentStatus': 'COMPLETED',
          };
        } else {
          return {
            'success': false,
            'message': 'Payment captured but booking update failed',
            'paymentStatus': 'COMPLETED',
          };
        }
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
      final response = await http.patch(
        Uri.parse('$baseUrl/bookings/$bookingId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'status': status}),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {
          'success': false,
          'message': 'Failed to update booking status: ${response.body}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Exception updating booking status: $e',
      };
    }
  }
}
