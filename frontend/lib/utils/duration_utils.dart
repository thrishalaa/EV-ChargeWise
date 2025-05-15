DateTime? parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

int calculateDurationMinutes(DateTime? startTime, DateTime? endTime) {
  if (startTime == null || endTime == null) return 0;
  return endTime.difference(startTime).inMinutes;
}
