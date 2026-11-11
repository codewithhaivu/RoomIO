import 'package:flutter/material.dart';
import 'package:roomio/features/rental/domain/entities/rental.dart';
import 'package:roomio/features/room/presentation/widgets/room_ui.dart';

String rentalDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

class RentalStatusBadge extends StatelessWidget {
  final String status;
  const RentalStatusBadge({super.key, required this.status});
  @override
  Widget build(BuildContext context) {
    final active = status.toLowerCase() == 'active';
    return Chip(
      avatar: Icon(
        active ? Icons.check_circle_outline : Icons.history,
        size: 18,
      ),
      label: Text(active ? 'Đang thuê' : 'Đã kết thúc'),
    );
  }
}

class TenantRentalCard extends StatelessWidget {
  final TenantRentalResponse tenant;
  final bool enabled;
  final VoidCallback onOpenRoom;
  final VoidCallback onEnd;
  const TenantRentalCard({
    super.key,
    required this.tenant,
    required this.enabled,
    required this.onOpenRoom,
    required this.onEnd,
  });
  @override
  Widget build(BuildContext context) {
    final avatar = tenant.avatarUrl?.trim();
    return RoomSection(
      title: tenant.roomName,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                foregroundImage: avatar == null || avatar.isEmpty
                    ? null
                    : NetworkImage(avatar),
                onForegroundImageError: avatar == null || avatar.isEmpty
                    ? null
                    : (_, _) {},
                child: const Icon(Icons.person_outline),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenant.fullName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(tenant.phoneNumber),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Ngày bắt đầu: ${rentalDate(tenant.startDate)}'),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: RentalStatusBadge(status: tenant.status),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: enabled ? onOpenRoom : null,
                icon: const Icon(Icons.home_outlined),
                label: const Text('Xem phòng'),
              ),
              if (tenant.rentalId?.trim().isNotEmpty == true &&
                  tenant.status.toLowerCase() == 'active')
                TextButton(
                  onPressed: enabled ? onEnd : null,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('Kết thúc thuê'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class RentedRoomCard extends StatelessWidget {
  final RentalRoomResponse room;
  final VoidCallback onOpenRoom;
  const RentedRoomCard({
    super.key,
    required this.room,
    required this.onOpenRoom,
  });
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RoomNetworkImage(url: room.roomThumbnail, height: 170),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                room.roomName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(room.address),
              const SizedBox(height: 8),
              Text(
                '${roomMoney(room.price)}/tháng',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text('Ngày bắt đầu: ${rentalDate(room.startDate)}'),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: RentalStatusBadge(status: room.status),
              ),
              OutlinedButton.icon(
                onPressed: onOpenRoom,
                icon: const Icon(Icons.home_outlined),
                label: const Text('Xem phòng'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
