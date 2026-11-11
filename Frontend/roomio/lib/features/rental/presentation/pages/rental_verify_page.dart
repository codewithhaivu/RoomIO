import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/config/route/app_route.dart';
import 'package:roomio/features/rental/domain/entities/rental.dart';
import 'package:roomio/features/rental/presentation/bloc/remote/remote_rental_bloc.dart';
import 'package:roomio/features/rental/presentation/bloc/remote/remote_rental_event.dart';
import 'package:roomio/features/rental/presentation/bloc/remote/remote_rental_state.dart';
import 'package:roomio/features/room/presentation/widgets/room_ui.dart';

class RentalVerifyPage extends StatefulWidget {
  const RentalVerifyPage({super.key});
  @override
  State<RentalVerifyPage> createState() => _RentalVerifyPageState();
}

class _RentalVerifyPageState extends State<RentalVerifyPage> {
  final _form = GlobalKey<FormState>();
  final _token = TextEditingController();
  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await Navigator.pushNamed(context, AppRoutes.rentalScan);
    if (mounted && code is String && RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      _token.text = code;
    }
  }

  void _verify() {
    final bloc = context.read<RemoteRentalBloc>();
    if (bloc.state.isBusy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    bloc.add(
      VerifyRentalQRCodeEvent(
        request: RentalVerifyRequest(token: _token.text.trim()),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<RemoteRentalBloc, RemoteRentalState>(
    listener: (context, state) {
      if (state.requestStatus == RemoteRentalStatus.verified) {
        roomSnackBar(context, state.verification!.message);
        if (state.verification!.isValid) Navigator.pop(context, true);
      } else if (state.requestStatus == RemoteRentalStatus.failure) {
        roomSnackBar(context, roomError(state.dio!));
      }
    },
    builder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Xác nhận thuê')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                RoomSection(
                  title: 'Nhập mã từ chủ trọ',
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Chỉ xác nhận khi bạn đã thống nhất thuê phòng với chủ trọ. Mã gồm 6 chữ số và có thời hạn ngắn.',
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _token,
                          enabled: !state.isBusy,
                          maxLength: 6,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Mã thuê phòng',
                            prefixIcon: Icon(Icons.password),
                          ),
                          validator: (value) =>
                              RegExp(
                                r'^[0-9]{6}$',
                              ).hasMatch(value?.trim() ?? '')
                              ? null
                              : 'Vui lòng nhập đủ 6 chữ số.',
                          onFieldSubmitted: (_) => _verify(),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: state.isBusy ? null : _scan,
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Quét mã QR'),
                        ),
                      ],
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
          onPressed: state.isBusy ? null : _verify,
          icon: state.isBusy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(state.isBusy ? 'Đang xác nhận…' : 'Xác nhận thuê phòng'),
        ),
      ),
    ),
  );
}
