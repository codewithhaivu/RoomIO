import 'package:flutter/material.dart';

class AppointmentStatusBadge extends StatelessWidget {
  final String status;
  const AppointmentStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = switch (status) {
      'CONFIRMED' => isDark ? Colors.green.shade300 : Colors.green.shade800,
      'REJECTED' => isDark ? Colors.red.shade300 : Colors.red.shade800,
      _ => Theme.of(context).colorScheme.primary,
    };
    final label = switch (status) {
      'CONFIRMED' => 'Đã xác nhận',
      'REJECTED' => 'Đã từ chối',
      _ => 'Chờ phản hồi',
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
        ),
      ),
    );
  }
}
