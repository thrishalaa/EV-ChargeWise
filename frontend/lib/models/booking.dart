class Booking {
  final int id;
  final int userId;
  final int stationId;
  final String? stationName;
  final DateTime? startTime;
  final DateTime? endTime;
  final DateTime? bookingDate;
  final int? durationMinutes;
  final String? status;
  final double? totalCost;
  final String? paymentLink;

  Booking({
    required this.id,
    required this.userId,
    required this.stationId,
    this.stationName,
    this.startTime,
    this.endTime,
    this.bookingDate,
    this.durationMinutes,
    this.status,
    this.totalCost,
    this.paymentLink,
  });

  Booking copyWith({
    int? id,
    int? userId,
    int? stationId,
    String? stationName,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? bookingDate,
    int? durationMinutes,
    String? status,
    double? totalCost,
    String? paymentLink,
  }) {
    return Booking(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      stationId: stationId ?? this.stationId,
      stationName: stationName ?? this.stationName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      bookingDate: bookingDate ?? this.bookingDate,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      status: status ?? this.status,
      totalCost: totalCost ?? this.totalCost,
      paymentLink: paymentLink ?? this.paymentLink,
    );
  }

  factory Booking.fromJson(Map<String, dynamic> json) {
    String? status = json['status'];
    if (status == 'paid') {
      status = 'completed';
    }
    return Booking(
      id: json['id'],
      userId: json['user_id'],
      stationId: json['station_id'],
      stationName: json['station_name'],
      startTime:
          json['start_time'] != null
              ? DateTime.parse(json['start_time'])
              : null,
      endTime:
          json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
      bookingDate:
          json['booking_date'] != null
              ? DateTime.parse(json['booking_date'])
              : null,
      durationMinutes: json['duration_minutes'],
      status: status,
      totalCost:
          json['total_cost'] != null
              ? (json['total_cost'] as num).toDouble()
              : null,
      paymentLink: json['payment_link'],
    );
  }
}

class BookingWithPayment {
  final Booking booking;
  final Payment? payment;

  BookingWithPayment({required this.booking, this.payment});

  factory BookingWithPayment.fromJson(Map<String, dynamic> json) {
    return BookingWithPayment(
      booking: Booking.fromJson(json['booking']),
      payment:
          json['payment'] != null
              ? Payment.fromJson({
                'id': json['payment']['payment_id'],
                'booking_id': json['booking']['id'],
                'amount': json['payment']['amount'],
                'currency': json['payment']['currency'],
                'status': json['payment']['status'],
                'timestamp': json['payment']['created_at'],
                'approval_link': json['payment']['approval_link'],
              })
              : null,
    );
  }
}

class Payment {
  final int id;
  final int bookingId;
  final double amount;
  final String? currency;
  final String? status;
  final DateTime? timestamp;
  final String? approvalLink;

  Payment({
    required this.id,
    required this.bookingId,
    required this.amount,
    this.currency,
    this.status,
    this.timestamp,
    this.approvalLink,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'],
      bookingId: json['booking_id'],
      amount: json['amount']?.toDouble() ?? 0.0,
      currency: json['currency'],
      status: json['status'],
      timestamp:
          json['timestamp'] != null ? DateTime.parse(json['timestamp']) : null,
      approvalLink: json['approval_link'],
    );
  }
}
