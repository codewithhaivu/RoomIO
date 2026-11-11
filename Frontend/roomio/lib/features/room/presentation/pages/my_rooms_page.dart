import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/config/route/app_route.dart';
import 'package:roomio/features/room/domain/entities/room_entities.dart';
import 'package:roomio/features/room/presentation/bloc/remote/landlord/remote_landlord_room_bloc.dart';
import 'package:roomio/features/room/presentation/bloc/remote/landlord/remote_landlord_room_event.dart';
import 'package:roomio/features/room/presentation/bloc/remote/landlord/remote_landlord_room_state.dart';
import 'package:roomio/features/room/presentation/widgets/room_card.dart';
import 'package:roomio/features/room/presentation/widgets/room_ui.dart';

class MyRoomsPage extends StatefulWidget {
  const MyRoomsPage({super.key});
  @override
  State<MyRoomsPage> createState() => _MyRoomsPageState();
}

class _MyRoomsPageState extends State<MyRoomsPage> {
  List<RoomEntity>? _rooms;
  String? _error;

  @override
  void initState() {
    super.initState();
    context.read<RemoteLandlordRoomBloc>().add(const GetListRoomEvent());
  }

  Future<void> _refresh() async {
    final bloc = context.read<RemoteLandlordRoomBloc>();
    final done = bloc.stream.firstWhere(
      (state) =>
          state is RemoteGetListRoomSuccess ||
          state is RemoteLandlordRoomFailure,
    );
    bloc.add(const GetListRoomEvent());
    await done;
  }

  Future<void> _open(String route, {Object? arguments}) async {
    await Navigator.pushNamed(context, route, arguments: arguments);
    if (mounted) {
      context.read<RemoteLandlordRoomBloc>().add(const GetListRoomEvent());
    }
  }

  Future<void> _changeStatus(RoomEntity room) async {
    final status = await chooseRoomStatus(context, room.status);
    if (status != null && mounted) {
      context.read<RemoteLandlordRoomBloc>().add(
        UpdateStatusRoomEvent(roomId: room.id, status: status),
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<RemoteLandlordRoomBloc, RemoteLandlordRoomState>(
    listener: (context, state) {
      if (state is RemoteGetListRoomSuccess) {
        _rooms = state.rooms;
        _error = null;
      } else if (state is RemoteUpdateStatusRoomSuccess) {
        roomSnackBar(context, state.message);
        context.read<RemoteLandlordRoomBloc>().add(const GetListRoomEvent());
      } else if (state is RemoteLandlordRoomFailure) {
        _error = roomError(state.dio);
        roomSnackBar(context, _error!);
      }
    },
    builder: (context, state) {
      final busy = state is RemoteLandlordRoomLoading;
      final rooms = _rooms;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Danh sách phòng'),
          actions: [
            IconButton(
              onPressed: busy ? null : _refresh,
              tooltip: 'Làm mới',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: busy ? null : () => _open(AppRoutes.roomForm),
          icon: const Icon(Icons.add),
          label: const Text('Đăng tin phòng'),
        ),
        body: Column(
          children: [
            if (busy) const LinearProgressIndicator(),
            Expanded(
              child: rooms == null
                  ? busy
                        ? const Center(child: CircularProgressIndicator())
                        : RoomMessage(
                            message: _error ?? 'Không thể tải danh sách phòng',
                            onAction: _refresh,
                          )
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                        children: [
                          if (_error != null)
                            RoomMessage(
                              message: _error!,
                              onAction: busy ? null : _refresh,
                            ),
                          if (rooms.isEmpty)
                            RoomMessage(
                              icon: Icons.home_work_outlined,
                              message:
                                  'Bạn chưa có phòng nào. Hãy đăng tin đầu tiên.',
                              actionLabel: 'Đăng tin phòng',
                              onAction: () => _open(AppRoutes.roomForm),
                            ),
                          ...rooms.map((room) {
                            final thumbnails = room.images.where(
                              (image) => image.isThumbnail,
                            );
                            final image = thumbnails.isNotEmpty
                                ? thumbnails.first
                                : room.images.isNotEmpty
                                ? room.images.first
                                : null;
                            return RoomCard(
                              name: room.name,
                              location: room.location.name,
                              imageUrl: image?.imageUrl,
                              rentalPrice: room.rentalPrice,
                              area: room.area,
                              status: room.status,
                              busy: busy,
                              onTap: () => _open(
                                AppRoutes.roomDetail,
                                arguments: {'roomId': room.id},
                              ),
                              onEdit: () => _open(
                                AppRoutes.roomForm,
                                arguments: {'room': room},
                              ),
                              onChangeStatus: () => _changeStatus(room),
                            );
                          }),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      );
    },
  );
}
