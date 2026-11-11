import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/config/route/app_route.dart';
import 'package:roomio/features/rental/domain/entities/rental.dart';
import 'package:roomio/features/rental/presentation/bloc/remote/remote_rental_bloc.dart';
import 'package:roomio/features/rental/presentation/bloc/remote/remote_rental_event.dart';
import 'package:roomio/features/rental/presentation/bloc/remote/remote_rental_state.dart';
import 'package:roomio/features/rental/presentation/widgets/rental_cards.dart';
import 'package:roomio/features/room/presentation/widgets/room_ui.dart';

class RentalsPage extends StatefulWidget {
  final bool isLandlord;
  const RentalsPage({super.key, required this.isLandlord});
  @override
  State<RentalsPage> createState() => _RentalsPageState();
}

class _RentalsPageState extends State<RentalsPage> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => context.read<RemoteRentalBloc>().add(
    widget.isLandlord
        ? const GetMyTenantsEvent()
        : const GetCurrentRentRoomEvent(),
  );
  Future<void> _refresh() async {
    final bloc = context.read<RemoteRentalBloc>();
    if (bloc.state.isBusy) return;
    final done = bloc.stream.firstWhere(
      (state) => !state.isBusy,
      orElse: () => bloc.state,
    );
    _load();
    await done;
  }

  Future<void> _verify() async {
    final verified = await Navigator.pushNamed(context, AppRoutes.rentalVerify);
    if (mounted && verified == true) _load();
  }

  Future<void> _end(TenantRentalResponse tenant) async {
    final id = tenant.rentalId;
    if (id == null || id.trim().isEmpty) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kết thúc thuê phòng?'),
        content: Text(
          'Xác nhận kết thúc lượt thuê của ${tenant.fullName} tại “${tenant.roomName}”.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kết thúc thuê'),
          ),
        ],
      ),
    );
    if (!mounted || accepted != true) return;
    final bloc = context.read<RemoteRentalBloc>();
    if (!bloc.state.isBusy) {
      bloc.add(DestroyRentalRelationEvent(rentalRelationId: id));
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<RemoteRentalBloc, RemoteRentalState>(
    listener: (context, state) {
      if (state.requestStatus == RemoteRentalStatus.ended) {
        roomSnackBar(context, state.message!);
      } else if (state.requestStatus == RemoteRentalStatus.failure &&
          (widget.isLandlord ? state.tenants != null : state.rooms != null)) {
        roomSnackBar(context, roomError(state.dio!));
      }
    },
    builder: (context, state) {
      final loaded = widget.isLandlord
          ? state.tenants != null
          : state.rooms != null;
      final count = widget.isLandlord
          ? state.tenants?.length ?? 0
          : state.rooms?.length ?? 0;
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isLandlord ? 'Khách đang thuê' : 'Phòng đang thuê',
          ),
          actions: [
            IconButton(
              onPressed: state.isBusy ? null : _load,
              tooltip: 'Làm mới',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: !loaded
                  ? state.requestStatus == RemoteRentalStatus.failure
                        ? RoomMessage(
                            message: roomError(state.dio!),
                            onAction: _load,
                          )
                        : const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        if (state.isBusy) const LinearProgressIndicator(),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _refresh,
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              itemCount: count == 0 ? 1 : count,
                              itemBuilder: (context, index) {
                                if (count == 0) {
                                  return RoomMessage(
                                    icon: Icons.home_work_outlined,
                                    message: widget.isLandlord
                                        ? 'Chưa có khách đang thuê phòng.'
                                        : 'Bạn chưa có phòng đang thuê.',
                                    actionLabel: widget.isLandlord
                                        ? 'Chọn phòng tạo mã'
                                        : 'Nhập mã thuê phòng',
                                    onAction: widget.isLandlord
                                        ? () => Navigator.pushNamed(
                                            context,
                                            AppRoutes.myRooms,
                                          )
                                        : _verify,
                                  );
                                }
                                if (widget.isLandlord) {
                                  final tenant = state.tenants![index];
                                  return TenantRentalCard(
                                    key: ValueKey(
                                      '${tenant.roomId}-${tenant.tenantId}',
                                    ),
                                    tenant: tenant,
                                    enabled: !state.isBusy,
                                    onOpenRoom: () => Navigator.pushNamed(
                                      context,
                                      AppRoutes.roomDetail,
                                      arguments: tenant.roomId,
                                    ),
                                    onEnd: () => _end(tenant),
                                  );
                                }
                                final room = state.rooms![index];
                                return RentedRoomCard(
                                  key: ValueKey(room.rentalId),
                                  room: room,
                                  onOpenRoom: () => Navigator.pushNamed(
                                    context,
                                    AppRoutes.roomDetail,
                                    arguments: room.roomId,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: FilledButton.icon(
            onPressed: state.isBusy
                ? null
                : widget.isLandlord
                ? () => Navigator.pushNamed(context, AppRoutes.myRooms)
                : _verify,
            icon: Icon(
              widget.isLandlord ? Icons.qr_code_2 : Icons.qr_code_scanner,
            ),
            label: Text(
              widget.isLandlord ? 'Chọn phòng tạo mã' : 'Xác nhận thuê phòng',
            ),
          ),
        ),
      );
    },
  );
}
