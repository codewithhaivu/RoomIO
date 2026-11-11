import 'package:flutter/material.dart';

class AppointmentListHeader extends StatelessWidget {
  final bool isLandlord;
  final bool isRoomScoped;

  const AppointmentListHeader({
    super.key,
    required this.isLandlord,
    required this.isRoomScoped,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isRoomScoped
              ? 'Lịch hẹn của phòng'
              : isLandlord
              ? 'Lịch xem phòng cùng khách thuê'
              : 'Lịch xem phòng của bạn',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          isLandlord
              ? 'Phản hồi lịch chờ và xem lại các lịch đã xử lý.'
              : 'Quản lý lịch chờ và theo dõi phản hồi từ chủ trọ.',
        ),
      ],
    ),
  );
}
