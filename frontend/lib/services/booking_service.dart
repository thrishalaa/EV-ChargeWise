import '../models/booking.dart';
import 'api_service.dart';

class BookingService {
  final ApiService apiService;

  BookingService({required this.apiService});

  Future<Map<String, dynamic>?> createBooking(
    Map<String, dynamic> bookingData,
  ) async {
    try {
      final response = await apiService.post(
        '/bookings/create-booking',
        body: bookingData,
      );
      return response;
    } catch (e) {
      print('Error creating booking: $e');
      throw Exception('Failed to create booking: $e');
    }
  }

  Future<List<Booking>> getUserBookings() async {
    try {
      final response = await apiService.get('/bookings/my-bookings');
      final List<dynamic> bookingsJson = response;
      return bookingsJson.map((json) => Booking.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching user bookings: $e');
      throw Exception('Failed to fetch bookings: $e');
    }
  }

  Future<BookingWithPayment> getBookingWithPayment(int bookingId) async {
    try {
      final response = await apiService.get('/bookings/booking/$bookingId');
      return BookingWithPayment.fromJson(response);
    } catch (e) {
      print('Error fetching booking with payment: $e');
      throw Exception('Failed to fetch booking details: $e');
    }
  }

  Future<Booking> cancelBooking(int bookingId) async {
    try {
      final response = await apiService.post(
        '/bookings/booking/$bookingId/cancel',
      );
      return Booking.fromJson(response);
    } catch (e) {
      print('Error canceling booking: $e');
      throw Exception('Failed to cancel booking: $e');
    }
  }

  // Added getBooking method to fetch a single booking by ID
  Future<Booking> getBooking(int bookingId) async {
    try {
      final response = await apiService.get('/bookings/booking/$bookingId');
      return Booking.fromJson(response['booking']);
    } catch (e) {
      print('Error fetching booking: $e');
      throw Exception('Failed to fetch booking: $e');
    }
  }
}
