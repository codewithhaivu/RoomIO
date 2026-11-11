import 'package:flutter/material.dart';
import 'package:roomio/features/appointment/domain/entities/appointment.dart';
import 'package:roomio/features/appointment/presentation/widgets/appointment_date_time.dart';
import 'package:roomio/features/appointment/presentation/widgets/appointment_status_badge.dart';

class AppointmentCard extends StatelessWidget {
  final AppointmentEntityResponse appointment;
  final bool isLandlord;
  final bool enabled;
  final VoidCallback onOpenRoom;
  final VoidCallback onEdit;
  final ValueChanged<String> onAction;

  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.isLandlord,
    required this.enabled,
    required this.onOpenRoom,
    required this.onEdit,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.event_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    appointment.nameRoom,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${appointmentTime(appointment.meetAt)} · ${appointmentDate(appointment.meetAt)}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text('Giờ Việt Nam (GMT+7)', style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Text('Khách thuê: ${appointment.nameTenant}'),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppointmentStatusBadge(status: appointment.status),
            ),
            if (appointment.status == 'PENDING') ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: enabled ? onOpenRoom : null,
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('Xem phòng'),
                  ),
                  if (isLandlord) ...[
                    FilledButton.icon(
                      onPressed: enabled ? () => onAction('CONFIRMED') : null,
                      icon: const Icon(Icons.check),
                      label: const Text('Đồng ý'),
                    ),
                    OutlinedButton.icon(
                      onPressed: enabled ? () => onAction('REJECTED') : null,
                      icon: const Icon(Icons.close),
                      label: const Text('Từ chối'),
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      onPressed: enabled ? onEdit : null,
                      icon: const Icon(Icons.edit_calendar_outlined),
                      label: const Text('Đổi lịch'),
                    ),
                    TextButton(
                      onPressed: enabled ? () => onAction('CANCELLED') : null,
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                      child: const Text('Hủy lịch'),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
