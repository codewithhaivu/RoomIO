import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:roomio/features/rental/presentation/bloc/remote/remote_rental_bloc.dart';
import 'package:roomio/features/rental/presentation/bloc/remote/remote_rental_event.dart';
import 'package:roomio/features/rental/presentation/bloc/remote/remote_rental_state.dart';
import 'package:roomio/features/room/presentation/widgets/room_ui.dart';

class RentalQRCodePage extends StatefulWidget {
  final String roomId;
  final String roomName;
  const RentalQRCodePage({
    super.key,
    required this.roomId,
    required this.roomName,
  });
  @override
  State<RentalQRCodePage> createState() => _RentalQRCodePageState();
}

class _RentalQRCodePageState extends State<RentalQRCodePage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _create();
  }

  void _create() => context.read<RemoteRentalBloc>().add(
    CreateRentalQRCodeEvent(roomId: widget.roomId),
  );
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<RemoteRentalBloc>().add(const RentalQRCodeTickEvent());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mã thuê phòng')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: BlocBuilder<RemoteRentalBloc, RemoteRentalState>(
            builder: (context, state) {
              if (state.isBusy ||
                  state.requestStatus == RemoteRentalStatus.initial) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.requestStatus == RemoteRentalStatus.failure) {
                return RoomMessage(
                  message: roomError(state.dio!),
                  onAction: _create,
                );
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  RoomSection(
                    title: widget.roomName,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Khách thuê quét QR hoặc nhập mã bên dưới để xác nhận thuê phòng. Mã chỉ dùng được một lần.',
                        ),
                        const SizedBox(height: 20),
                        if (state.hasActiveCode) ...[
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              color: Colors.white,
                              child: QrImageView(
                                data: state.qrCode!.qrToken,
                                size: 200,
                                backgroundColor: Colors.white,
                                semanticsLabel: 'Mã QR xác nhận thuê phòng',
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SelectableText(
                            state.qrCode!.qrToken,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(letterSpacing: 4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Mã hết hạn sau ${state.remainingSeconds} giây',
                            textAlign: TextAlign.center,
                          ),
                        ] else
                          const RoomMessage(
                            icon: Icons.timer_off_outlined,
                            message:
                                'Mã đã hết hạn. Hãy tạo mã mới khi khách thuê sẵn sàng.',
                          ),
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          onPressed: _create,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tạo mã mới'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
