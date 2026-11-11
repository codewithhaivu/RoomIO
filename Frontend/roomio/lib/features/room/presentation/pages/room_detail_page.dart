import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/core/storage/secure_storage_service.dart';
import 'package:roomio/features/review/presentation/widgets/room_review_section.dart';
import 'package:roomio/injection_container.dart';
import 'package:roomio/features/chat/presentation/widgets/contact_landlord_button.dart';
import 'package:roomio/config/route/app_route.dart';
import 'package:roomio/features/room/domain/entities/room_detail_entities.dart';
import 'package:roomio/features/room/domain/entities/room_entities.dart';
import 'package:roomio/features/room/presentation/bloc/remote/detail/remote_room_detail_bloc.dart';
import 'package:roomio/features/room/presentation/bloc/remote/detail/remote_room_detail_event.dart';
import 'package:roomio/features/room/presentation/bloc/remote/detail/remote_room_detail_state.dart';
import 'package:roomio/features/room/presentation/bloc/remote/landlord/remote_landlord_room_bloc.dart';
import 'package:roomio/features/room/presentation/bloc/remote/landlord/remote_landlord_room_event.dart';
import 'package:roomio/features/room/presentation/bloc/remote/landlord/remote_landlord_room_state.dart';
import 'package:roomio/features/room/presentation/widgets/room_ui.dart';

class RoomDetailPage extends StatefulWidget {
  final String roomId;
  final bool isLandlord;
  const RoomDetailPage({
    super.key,
    required this.roomId,
    this.isLandlord = false,
  });
  @override
  State<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> {
  bool _updating = false;
  late final Future<bool> _canPostReview;

  @override
  void initState() {
    super.initState();
    _canPostReview = _loadReviewPermission();
    _load();
  }

  Future<bool> _loadReviewPermission() async {
    try {
      final storage = sl<SecureStorageService>();
      final values = await Future.wait([
        storage.getAccessToken(),
        storage.getRole(),
      ]);
      final token = values[0];
      final role = values[1];
      return token != null &&
          token.isNotEmpty &&
          (role == 'CUSTOMER' || role == 'TENANT');
    } catch (_) {
      // Public reviews remain available when the local session cannot be read.
      return false;
    }
  }

  void _load() => context.read<RemoteRoomDetailBloc>().add(
    GetDetailRoomEvent(roomId: widget.roomId),
  );

  Future<void> _edit(RoomEntity room) async {
    final updated = await Navigator.pushNamed(
      context,
      AppRoutes.roomForm,
      arguments: {'room': room},
    );
    if (mounted && updated == true) _load();
  }

  Future<void> _changeStatus(RoomEntity room) async {
    final status = await chooseRoomStatus(context, room.status);
    if (mounted && status != null) {
      setState(() => _updating = true);
      context.read<RemoteLandlordRoomBloc>().add(
        UpdateStatusRoomEvent(roomId: room.id, status: status),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết phòng'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.appointments,
              arguments: {'roomId': widget.roomId},
            ),
            tooltip: 'Lịch hẹn xem phòng',
            icon: const Icon(Icons.event_note_outlined),
          ),
          IconButton(
            onPressed: _updating ? null : _load,
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      bottomNavigationBar: widget.isLandlord
          ? null
          : BlocBuilder<RemoteRoomDetailBloc, RemoteRoomDetailState>(
              builder: (context, state) => state is! RemoteRoomDetailSuccess
                  ? const SizedBox.shrink()
                  : SafeArea(
                      minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.appointmentForm,
                          arguments: {
                            'roomId': state.roomDetail.room.id,
                            'roomName': state.roomDetail.room.name,
                          },
                        ),
                        icon: const Icon(Icons.event_available_outlined),
                        label: const Text('Đặt lịch xem phòng'),
                      ),
                    ),
            ),
      body: BlocBuilder<RemoteRoomDetailBloc, RemoteRoomDetailState>(
        builder: (context, state) {
          if (state is RemoteRoomDetailFailure) {
            return RoomMessage(message: roomError(state.dio), onAction: _load);
          }
          if (state is! RemoteRoomDetailSuccess) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_updating) const LinearProgressIndicator(),
                _RoomDetailContent(
                  detail: state.roomDetail,
                  showContact: !widget.isLandlord,
                ),
                FutureBuilder<bool>(
                  future: _canPostReview,
                  builder: (context, snapshot) => RoomReviewSection(
                    roomId: state.roomDetail.room.id,
                    canPostReview: snapshot.data == true,
                  ),
                ),
                if (widget.isLandlord)
                  RoomSection(
                    title: 'Quản lý phòng',
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: _updating
                              ? null
                              : () => _edit(state.roomDetail.room),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Sửa phòng'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _updating
                              ? null
                              : () => _changeStatus(state.roomDetail.room),
                          icon: const Icon(Icons.sync),
                          label: const Text('Đổi trạng thái'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _updating
                              ? null
                              : () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.rentalQRCode,
                                  arguments: {
                                    'roomId': state.roomDetail.room.id,
                                    'roomName': state.roomDetail.room.name,
                                  },
                                ),
                          icon: const Icon(Icons.qr_code_2),
                          label: const Text('Tạo mã thuê phòng'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
    if (!widget.isLandlord) return page;
    return BlocListener<RemoteLandlordRoomBloc, RemoteLandlordRoomState>(
      listener: (context, state) {
        if (state is RemoteUpdateStatusRoomSuccess) {
          setState(() => _updating = false);
          roomSnackBar(context, state.message);
          _load();
        } else if (state is RemoteLandlordRoomFailure) {
          setState(() => _updating = false);
          roomSnackBar(context, roomError(state.dio));
        }
      },
      child: page,
    );
  }
}

class _RoomDetailContent extends StatelessWidget {
  final RoomDetailEntity detail;
  final bool showContact;
  const _RoomDetailContent({required this.detail, required this.showContact});

  @override
  Widget build(BuildContext context) {
    final room = detail.room;
    final landlord = detail.landlord;
    final avatar = landlord.avatar?.trim();
    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
    Widget chips(Iterable<String> names) => names.isEmpty
        ? const Text('Chưa có thông tin')
        : Wrap(
            spacing: 8,
            runSpacing: 8,
            children: names.map((name) => Chip(label: Text(name))).toList(),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RoomGallery(
          images: room.images.map((image) => image.imageUrl).toList(),
        ),
        const SizedBox(height: 20),
        Text(room.name, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          '${roomMoney(room.rentalPrice)}/tháng',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            RoomStatusBadge(status: room.status),
            Text(roomTypes[room.roomType] ?? room.roomType),
            Text('${room.area} m²'),
          ],
        ),
        const SizedBox(height: 16),
        RoomSection(
          title: 'Địa điểm',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Text(room.location.name)],
          ),
        ),
        RoomSection(
          title: 'Chi phí',
          child: Column(
            children: [
              line('Giá thuê / tháng', roomMoney(room.rentalPrice)),
              line('Tiền điện / kWh', roomMoney(room.electricityFee)),
              line('Tiền nước / tháng', roomMoney(room.waterFee)),
              line('Dịch vụ / tháng', roomMoney(room.serviceFee)),
              line('Gửi xe / tháng', roomMoney(room.parkingFee)),
            ],
          ),
        ),
        RoomSection(
          title: 'Nội thất',
          child: chips(room.interiors.map((item) => item.name)),
        ),
        RoomSection(
          title: 'Tiện ích',
          child: chips(room.amenities.map((item) => item.name)),
        ),
        RoomSection(
          title: 'Thông tin chủ trọ',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 30,
                foregroundImage: avatar == null || avatar.isEmpty
                    ? null
                    : NetworkImage(avatar),
                onForegroundImageError: avatar == null || avatar.isEmpty
                    ? null
                    : (_, _) {},
                child: const Icon(Icons.person_outline),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      landlord.fullName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(landlord.gender),
                    const SizedBox(height: 8),
                    Text(landlord.isVerify ? 'Đã xác minh' : 'Chưa xác minh'),
                    if (showContact) ...[
                      const SizedBox(height: 12),
                      if (landlord.accountId?.isNotEmpty == true)
                        ContactLandlordButton(
                          landlordAccountId: landlord.accountId!,
                          landlordName: landlord.fullName,
                          landlordAvatarUrl: landlord.avatar,
                        )
                      else
                        const Text('Chưa có thông tin liên hệ của chủ trọ.'),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoomGallery extends StatefulWidget {
  final List<String> images;
  const _RoomGallery({required this.images});
  @override
  State<_RoomGallery> createState() => _RoomGalleryState();
}

class _RoomGalleryState extends State<_RoomGallery> {
  int _index = 0;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 240,
          child: widget.images.isEmpty
              ? const RoomNetworkImage(url: null)
              : PageView.builder(
                  itemCount: widget.images.length,
                  onPageChanged: (index) => setState(() => _index = index),
                  itemBuilder: (_, index) =>
                      RoomNetworkImage(url: widget.images[index]),
                ),
        ),
      ),
      if (widget.images.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '${_index + 1} / ${widget.images.length} ảnh · Vuốt để xem',
          ),
        ),
    ],
  );
}
