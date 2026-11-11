import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/config/route/app_route.dart';
import 'package:roomio/features/room/presentation/widgets/room_ui.dart';
import 'package:roomio/features/saved_room/presentation/cubit/saved_rooms_cubit.dart';
import 'package:roomio/features/saved_room/presentation/cubit/saved_rooms_state.dart';
import 'package:roomio/features/saved_room/presentation/widgets/saved_room_card.dart';

class SavedRoomsPage extends StatefulWidget {
  const SavedRoomsPage({super.key});

  @override
  State<SavedRoomsPage> createState() => _SavedRoomsPageState();
}

class _SavedRoomsPageState extends State<SavedRoomsPage> {
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() => context.read<SavedRoomsCubit>().refresh();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Phòng đã lưu'),
      actions: [
        IconButton(
          tooltip: 'Tìm phòng',
          icon: const Icon(Icons.search),
          onPressed: () => Navigator.pushNamed(context, AppRoutes.searchRooms),
        ),
      ],
    ),
    body: SafeArea(
      child: BlocBuilder<SavedRoomsCubit, SavedRoomsState>(
        builder: (context, state) => Column(
          children: [
            if (state.isLoading) const LinearProgressIndicator(),
            if (state.loadError != null && state.rooms.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: Text(roomError(state.loadError!))),
                    TextButton(
                      onPressed: state.isLoading ? null : _refresh,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: state.rooms.isEmpty ? 1 : state.rooms.length,
                  itemBuilder: (context, index) {
                    if (state.rooms.isEmpty) {
                      if (state.isLoading) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 80),
                          child: Center(
                            child: Text('Đang tải phòng đã lưu...'),
                          ),
                        );
                      }
                      if (state.status == SavedRoomsStatus.failure) {
                        return RoomMessage(
                          message: roomError(state.loadError!),
                          onAction: _refresh,
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: RoomMessage(
                          icon: Icons.favorite_border,
                          message: 'Bạn chưa lưu phòng nào.',
                          actionLabel: 'Tìm phòng',
                          onAction: () => Navigator.pushNamed(
                            context,
                            AppRoutes.searchRooms,
                          ),
                        ),
                      );
                    }
                    final room = state.rooms[index];
                    return SavedRoomCard(key: ValueKey(room.id), room: room);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
