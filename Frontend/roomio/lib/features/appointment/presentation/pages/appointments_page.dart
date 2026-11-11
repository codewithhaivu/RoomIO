import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/config/route/app_route.dart';
import 'package:roomio/features/appointment/domain/entities/appointment.dart';
import 'package:roomio/features/appointment/presentation/bloc/remote/remote_appointment_bloc.dart';
import 'package:roomio/features/appointment/presentation/bloc/remote/remote_appointment_event.dart';
import 'package:roomio/features/appointment/presentation/bloc/remote/remote_appointment_state.dart';
import 'package:roomio/features/appointment/presentation/widgets/appointment_group_list.dart';
import 'package:roomio/features/appointment/presentation/widgets/appointment_list_header.dart';
import 'package:roomio/features/room/presentation/widgets/room_ui.dart';

class AppointmentsPage extends StatefulWidget {
  final bool isLandlord;
  final String? roomId;
  final String? appointmentId;
  const AppointmentsPage({
    super.key,
    required this.isLandlord,
    this.roomId,
    this.appointmentId,
  });

  @override
  State<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<AppointmentsPage> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => context.read<RemoteAppointmentBloc>().add(
    const GetAllAppointmentsEvent(),
  );

  Future<void> _refresh() async {
    final bloc = context.read<RemoteAppointmentBloc>();
    if (bloc.state.isBusy) return;
    final loaded = bloc.stream.firstWhere(
      (state) => !state.isBusy,
      orElse: () => bloc.state,
    );
    _load();
    await loaded;
  }

  Future<void> _edit(AppointmentEntityResponse appointment) async {
    final updated = await Navigator.pushNamed(
      context,
      AppRoutes.appointmentForm,
      arguments: appointment,
    );
    if (mounted && updated is AppointmentEntityResponse) {
      context.read<RemoteAppointmentBloc>().add(
        AppointmentChangedEvent(appointment: updated),
      );
    }
  }

  void _openRoom(AppointmentEntityResponse appointment) {
    Navigator.pushNamed(
      context,
      AppRoutes.roomDetail,
      arguments: appointment.idRoom,
    );
  }

  Widget _focusedAppointment(
    Iterable<AppointmentEntityResponse> appointments,
    bool enabled,
  ) {
    final appointment = appointments
        .where((item) => item.idAppointment == widget.appointmentId)
        .firstOrNull;
    if (appointment == null) {
      return RoomMessage(
        message: 'Lịch hẹn không còn khả dụng.',
        onAction: _load,
      );
    }
    return AppointmentGroupList(
      appointments: [appointment],
      isPending: appointment.status == 'PENDING',
      isLandlord: widget.isLandlord,
      enabled: enabled,
      onRefresh: _refresh,
      onOpenRoom: _openRoom,
      onEdit: _edit,
      onAction: _action,
    );
  }

  Future<void> _action(
    AppointmentEntityResponse appointment,
    String action,
  ) async {
    if (appointment.status != 'PENDING') return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(switch (action) {
          'CONFIRMED' => 'Xác nhận lịch hẹn?',
          'REJECTED' => 'Từ chối lịch hẹn?',
          _ => 'Hủy lịch hẹn?',
        }),
        content: Text(switch (action) {
          'CONFIRMED' =>
            'Bạn sẽ gặp khách thuê tại phòng “${appointment.nameRoom}” theo thời gian đã hẹn.',
          'REJECTED' =>
            'Khách thuê sẽ được thông báo rằng lịch hẹn này bị từ chối.',
          _ => 'Bạn muốn hủy lịch xem phòng “${appointment.nameRoom}”?',
        }),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (!mounted || accepted != true) return;
    final bloc = context.read<RemoteAppointmentBloc>();
    if (bloc.state.isBusy) return;
    if (widget.isLandlord) {
      bloc.add(
        ConfirmAppointmentEvent(
          idAppointment: appointment.idAppointment,
          status: action,
        ),
      );
    } else {
      bloc.add(
        DestroyAppointmentEvent(idAppointment: appointment.idAppointment),
      );
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: BlocConsumer<RemoteAppointmentBloc, RemoteAppointmentState>(
      listener: (context, state) {
        if (state.requestStatus == RemoteAppointmentStatus.success) {
          roomSnackBar(context, state.message!);
        } else if (state.requestStatus == RemoteAppointmentStatus.failure &&
            state.appointments != null) {
          roomSnackBar(context, roomError(state.dio!));
        }
      },
      builder: (context, state) {
        final appointments = state.appointments;
        final visible = appointments?.where(
          (item) => widget.roomId == null || item.idRoom == widget.roomId,
        );
        final pending =
            visible?.where((item) => item.status == 'PENDING').toList() ?? [];
        final handled =
            visible
                ?.where(
                  (item) =>
                      item.status == 'CONFIRMED' || item.status == 'REJECTED',
                )
                .toList() ??
            [];
        pending.sort((a, b) => a.meetAt.compareTo(b.meetAt));
        handled.sort((a, b) => b.meetAt.compareTo(a.meetAt));
        return Scaffold(
          appBar: AppBar(
            title: const Text('Lịch hẹn'),
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
                child: appointments == null
                    ? state.requestStatus == RemoteAppointmentStatus.failure
                          ? RoomMessage(
                              message: roomError(state.dio!),
                              onAction: _load,
                            )
                          : const Center(child: CircularProgressIndicator())
                    : widget.appointmentId != null
                    ? _focusedAppointment(visible!, !state.isBusy)
                    : Column(
                        children: [
                          if (state.isBusy) const LinearProgressIndicator(),
                          AppointmentListHeader(
                            isLandlord: widget.isLandlord,
                            isRoomScoped: widget.roomId != null,
                          ),
                          const TabBar(
                            tabs: [
                              Tab(text: 'Chờ xử lý'),
                              Tab(text: 'Đã xử lý'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                for (final isPending in [true, false])
                                  AppointmentGroupList(
                                    key: ValueKey(isPending),
                                    appointments: isPending ? pending : handled,
                                    isPending: isPending,
                                    isLandlord: widget.isLandlord,
                                    enabled: !state.isBusy,
                                    onRefresh: _refresh,
                                    onOpenRoom: _openRoom,
                                    onEdit: _edit,
                                    onAction: _action,
                                    onSearch:
                                        isPending &&
                                            !widget.isLandlord &&
                                            widget.roomId == null
                                        ? () => Navigator.pushNamed(
                                            context,
                                            AppRoutes.searchRooms,
                                          )
                                        : null,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
