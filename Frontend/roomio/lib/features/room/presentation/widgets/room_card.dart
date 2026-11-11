import 'package:flutter/material.dart';
import 'package:roomio/features/room/presentation/widgets/room_ui.dart';

class RoomCard extends StatelessWidget {
  final String name;
  final String location;
  final String? imageUrl;
  final double rentalPrice;
  final double area;
  final String status;
  final double? distance;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onChangeStatus;
  final bool busy;
  final bool isSaved;
  final bool saving;
  final VoidCallback? onToggleSaved;

  const RoomCard({
    super.key,
    required this.name,
    required this.location,
    required this.rentalPrice,
    required this.area,
    required this.status,
    required this.onTap,
    this.imageUrl,
    this.distance,
    this.onEdit,
    this.onChangeStatus,
    this.busy = false,
    this.isSaved = false,
    this.saving = false,
    this.onToggleSaved,
  });

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    margin: const EdgeInsets.only(bottom: 16),
    child: InkWell(
      onTap: busy ? null : onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              RoomNetworkImage(url: imageUrl, height: 170),
              if (onToggleSaved != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    // Consume taps while pending instead of opening the room below.
                    onTap: () {},
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          IconButton(
                            tooltip: isSaved ? 'Bỏ lưu phòng' : 'Lưu phòng',
                            isSelected: isSaved,
                            onPressed: saving || busy ? null : onToggleSaved,
                            icon: Icon(
                              Icons.favorite_border,
                              color: Colors.grey.shade700,
                            ),
                            selectedIcon: const Icon(
                              Icons.favorite,
                              color: Colors.red,
                            ),
                          ),
                          if (saving)
                            const Positioned(
                              bottom: 5,
                              left: 14,
                              right: 14,
                              child: SizedBox(
                                height: 2,
                                child: LinearProgressIndicator(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  '${roomMoney(rentalPrice)}/tháng',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(location, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('$area m²'),
                    if (distance != null)
                      Text('Cách ${distance!.toStringAsFixed(2)} km'),
                    RoomStatusBadge(status: status),
                  ],
                ),
                if (onEdit != null || onChangeStatus != null) ...[
                  const Divider(),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (onEdit != null)
                        TextButton.icon(
                          onPressed: busy ? null : onEdit,
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Sửa phòng'),
                        ),
                      if (onChangeStatus != null)
                        TextButton.icon(
                          onPressed: busy ? null : onChangeStatus,
                          icon: const Icon(Icons.sync),
                          label: const Text('Đổi trạng thái'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
