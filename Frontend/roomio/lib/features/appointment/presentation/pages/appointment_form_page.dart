import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/features/appointment/domain/entities/appointment.dart';
import 'package:roomio/features/appointment/presentation/bloc/remote/remote_appointment_bloc.dart';
import 'package:roomio/features/appointment/presentation/bloc/remote/remote_appointment_event.dart';
import 'package:roomio/features/appointment/presentation/bloc/remote/remote_appointment_state.dart';
import 'package:roomio/features/appointment/presentation/widgets/appointment_date_time.dart';
import 'package:roomio/features/room/presentation/widgets/room_ui.dart';

class AppointmentFormPage extends StatefulWidget {
  final String roomId;
  final String roomName;
  final AppointmentEntityResponse? initialAppointment;

  const AppointmentFormPage({
    super.key,
    required this.roomId,
    required this.roomName,
    this.initialAppointment,
  });

  @override
  State<AppointmentFormPage> createState() => _AppointmentFormPageState();
}

class _AppointmentFormPageState extends State<AppointmentFormPage> {
  DateTime? _meetAt;
  String? _validationError;
  bool get _isEditing => widget.initialAppointment != null;

  @override
  void initState() {
    super.initState();
    _meetAt = widget.initialAppointment?.meetAt;
  }

  Future<void> _pickDate() async {
    final now = appointmentVietnamTime(DateTime.now());
    final selected = _meetAt == null ? now : appointmentVietnamTime(_meetAt!);
    final first = DateTime(now.year, now.month, now.day);
    final last = DateTime(now.year + 5, 12, 31);
    final initial = DateTime(selected.year, selected.month, selected.day);
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first)
          ? first
          : initial.isAfter(last)
          ? last
          : initial,
      firstDate: first,
      lastDate: last,
      helpText: 'Chọn ngày xem phòng',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _meetAt == null
          ? const TimeOfDay(hour: 9, minute: 0)
          : TimeOfDay(hour: selected.hour, minute: selected.minute),
      helpText: 'Chọn giờ (GMT+7)',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (!mounted || time == null) return;
    setState(() {
      _meetAt = appointmentInstant(date, time.hour, time.minute);
      _validationError = null;
    });
  }

  void _submit() {
    final bloc = context.read<RemoteAppointmentBloc>();
    if (bloc.state.isBusy) return;
    final meetAt = _meetAt;
    if (meetAt == null || !meetAt.isAfter(DateTime.now())) {
      setState(
        () => _validationError = meetAt == null
            ? 'Vui lòng chọn ngày và giờ xem phòng.'
            : 'Vui lòng chọn thời gian trong tương lai.',
      );
      return;
    }
    final request = AppointmentEntityRequest(
      idRoom: widget.roomId,
      meetAt: meetAt,
    );
    if (_isEditing) {
      bloc.add(
        UpdateAppointmentEvent(
          idAppointment: widget.initialAppointment!.idAppointment,
          request: request,
        ),
      );
    } else {
      bloc.add(SendAppointmentEvent(request: request));
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<RemoteAppointmentBloc, RemoteAppointmentState>(
    listener: (context, state) {
      if (state.requestStatus == RemoteAppointmentStatus.sent ||
          state.requestStatus == RemoteAppointmentStatus.success) {
        roomSnackBar(
          context,
          state.requestStatus == RemoteAppointmentStatus.success
              ? state.message!
              : 'Đã gửi lịch hẹn. Vui lòng chờ chủ trọ xác nhận.',
        );
        Navigator.pop(
          context,
          _isEditing
              ? widget.initialAppointment!.copyWith(
                  meetAt: _meetAt,
                  status: 'PENDING',
                )
              : state.appointment,
        );
      } else if (state.requestStatus == RemoteAppointmentStatus.failure) {
        roomSnackBar(context, roomError(state.dio!));
      }
    },
    builder: (context, state) => Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Đổi lịch xem phòng' : 'Đặt lịch xem phòng',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                RoomSection(
                  title: 'Phòng bạn muốn xem',
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.home_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.roomName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                RoomSection(
                  title: 'Thời gian hẹn',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _isEditing
                            ? 'Chọn thời gian mới. Lịch hẹn sẽ được gửi lại để chủ trọ xác nhận.'
                            : 'Chọn thời gian thuận tiện để đến xem phòng và gặp chủ trọ.',
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: state.isBusy ? null : _pickDate,
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            _meetAt == null
                                ? 'Chọn ngày và giờ'
                                : '${appointmentTime(_meetAt!)} · ${appointmentDate(_meetAt!)}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Giờ Việt Nam (GMT+7). Chủ trọ sẽ xác nhận lịch hẹn của bạn.',
                      ),
                      if (_validationError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _validationError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                          semanticsLabel: _validationError,
                        ),
                      ],
                    ],
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
          onPressed: state.isBusy ? null : _submit,
          icon: state.isBusy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.event_available_outlined),
          label: Text(
            state.isBusy
                ? 'Đang gửi lịch hẹn…'
                : _isEditing
                ? 'Lưu lịch hẹn'
                : 'Gửi lịch hẹn',
          ),
        ),
      ),
    ),
  );
}
