// The API interprets naive timestamps as Vietnam time, regardless of device timezone.
DateTime appointmentVietnamTime(DateTime instant) =>
    instant.toUtc().add(const Duration(hours: 7));

DateTime appointmentInstant(DateTime date, int hour, int minute) =>
    DateTime.utc(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    ).subtract(const Duration(hours: 7));

String appointmentDate(DateTime instant) {
  final date = appointmentVietnamTime(instant);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}

String appointmentTime(DateTime instant) {
  final date = appointmentVietnamTime(instant);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.hour)}:${two(date.minute)}';
}
