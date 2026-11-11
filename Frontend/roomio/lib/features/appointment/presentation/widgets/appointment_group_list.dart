import 'package:flutter/material.dart';
import 'package:roomio/features/appointment/domain/entities/appointment.dart';
import 'package:roomio/features/appointment/presentation/widgets/appointment_card.dart';
import 'package:roomio/features/room/presentation/widgets/room_ui.dart';

class AppointmentGroupList extends StatelessWidget {
  final List<AppointmentEntityResponse> appointments;
  final bool isPending;
  final bool isLandlord;
  final bool enabled;
  final Future<void> Function() onRefresh;
  final ValueChanged<AppointmentEntityResponse> onOpenRoom;
  final ValueChanged<AppointmentEntityResponse> onEdit;
  final void Function(AppointmentEntityResponse, String) onAction;
  final VoidCallback? onSearch;

  const AppointmentGroupList({
    super.key,
    required this.appointments,
    required this.isPending,
    required this.isLandlord,
    required this.enabled,
    required this.onRefresh,
    required this.onOpenRoom,
    required this.onEdit,
    required this.onAction,
    this.onSearch,
  });

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: appointments.isEmpty
          ? ListView(
              key: ValueKey('empty-$isPending'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                RoomMessage(
                  icon: Icons.event_note_outlined,
                  message: isPending
                      ? 'Không có lịch hẹn chờ xử lý.'
                      : 'Chưa có lịch hẹn đã xử lý.',
                  actionLabel: onSearch == null
                      ? null
                      : 'Tìm phòng để đặt lịch',
                  onAction: onSearch,
                ),
              ],
            )
          : ListView.builder(
              key: PageStorageKey('appointments-$isPending'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: appointments.length,
              itemBuilder: (context, index) {
                final appointment = appointments[index];
                return AppointmentCard(
                  key: ValueKey(appointment.idAppointment),
                  appointment: appointment,
                  isLandlord: isLandlord,
                  enabled: enabled,
                  onOpenRoom: () => onOpenRoom(appointment),
                  onEdit: () => onEdit(appointment),
                  onAction: (action) => onAction(appointment, action),
                );
              },
            ),
    ),
  );
}
