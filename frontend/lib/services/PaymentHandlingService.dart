import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/booking.dart'; // Removed import '../models/payment.dart'

class PaymentHandlingService {
  // Base API URL - replace with your actual API endpoint
  final String apiBaseUrl = 'http://192.168.200.165:8000';

  // Store auth token - you might get this from a user service
  final String? authToken;

  PaymentHandlingService({this.authToken});

  // Handle payment return from PayPal
  Future<Map<String, dynamic>> handlePaymentReturn({
    required String orderId,
    required int bookingId,
    required int paymentId,
  }) async {
    try {
      // 1. Call your backend to capture the payment
      final captureResponse = await capturePayment(orderId, paymentId);

      // 2. Update booking status if payment capture was successful
      if (captureResponse['success'] == true) {
        await updateBookingStatus(bookingId, 'completed');
        return {
          'success': true,
          'message': 'Payment completed successfully!',
          'paymentStatus': 'COMPLETED',
          'bookingStatus': 'completed',
        };
      } else {
        // Payment capture failed but payment might still be pending
        return {
          'success': false,
          'message': 'Payment capture failed: ${captureResponse['message']}',
          'paymentStatus': 'PENDING',
          'bookingStatus': 'pending',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error processing payment: $e',
        'paymentStatus': 'ERROR',
        'bookingStatus': 'pending',
      };
    }
  }

  // Call API to capture PayPal payment
  Future<Map<String, dynamic>> capturePayment(
    String orderId,
    int paymentId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/payments/$paymentId/capture'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'order_id': orderId}),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': responseData};
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to capture payment',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Exception occurred: $e'};
    }
  }

  // Update booking status in the database
  Future<bool> updateBookingStatus(int bookingId, String status) async {
    try {
      final response = await http.patch(
        Uri.parse('$apiBaseUrl/bookings/$bookingId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'status': status}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating booking status: $e');
      return false;
    }
  }

  // Handle payment cancellation
  Future<Map<String, dynamic>> handlePaymentCancellation(int bookingId) async {
    try {
      // Just update the booking status - no need to interact with PayPal
      // as no payment was captured
      await updateBookingStatus(bookingId, 'pending');

      return {
        'success': true,
        'message': 'Payment was cancelled',
        'paymentStatus': 'CANCELLED',
        'bookingStatus': 'pending',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error handling cancellation: $e',
        'paymentStatus': 'ERROR',
        'bookingStatus': 'pending',
      };
    }
  }

  // Check payment status (useful for periodic polling)
  Future<Map<String, dynamic>> checkPaymentStatus(int paymentId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/payments/$paymentId'),
        headers: {'Authorization': 'Bearer $authToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'paymentStatus': data['status'],
          'paymentDetails': data,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to retrieve payment status',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error checking payment status: $e'};
    }
  }
}
