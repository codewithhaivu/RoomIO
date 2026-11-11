import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/config/route/app_route.dart';
import 'package:roomio/features/room/presentation/widgets/room_card.dart';
import 'package:roomio/features/saved_room/domain/entities/save_room.dart';
import 'package:roomio/features/saved_room/presentation/cubit/saved_rooms_cubit.dart';
import 'package:roomio/features/saved_room/presentation/cubit/saved_rooms_state.dart';

class SavedRoomCard extends StatelessWidget {
  final RoomResponse room;
  final double? distance;
  final bool initiallySaved;
  final bool enableSaving;

  const SavedRoomCard({
    super.key,
    required this.room,
    this.distance,
    this.initiallySaved = true,
    this.enableSaving = true,
  });

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<SavedRoomsCubit, SavedRoomsState>(
        buildWhen: (previous, current) =>
            previous.savedById[room.id] != current.savedById[room.id] ||
            previous.pendingIds.contains(room.id) !=
                current.pendingIds.contains(room.id),
        builder: (context, state) {
          final saved = state.isSaved(room.id, fallback: initiallySaved);
          return RoomCard(
            key: ValueKey('room-card-${room.id}'),
            name: room.name,
            location: room.locationName,
            imageUrl: room.imageUrl,
            rentalPrice: room.rentalPrice,
            area: room.area,
            status: room.status,
            distance: distance,
            isSaved: saved,
            saving: state.pendingIds.contains(room.id),
            onToggleSaved: enableSaving
                ? () => context.read<SavedRoomsCubit>().toggle(
                    room,
                    isSaved: saved,
                  )
                : null,
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.roomDetail,
              arguments: {'roomId': room.id},
            ),
          );
        },
      );
}
