

import 'package:flutter/material.dart';


import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/login/remote_login_bloc.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/login/remote_login_event.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/login/remote_login_state.dart';
import 'package:roomio/config/route/app_route.dart';
import 'package:roomio/config/theme/app_text_style.dart';
import 'package:roomio/features/auth/presentation/widget/auth_layout.dart';

class CheckPhonePage extends StatefulWidget {
  const CheckPhonePage({super.key});

  @override
  State<CheckPhonePage> createState() => _CheckPhonePageState();
}

class _CheckPhonePageState extends State<CheckPhonePage> {
  final TextEditingController _phoneController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    if (_formKey.currentState!.validate()) {
      context.read<RemoteLoginBloc>().add(
        CheckPhoneNumberEvent(phoneNumber: _phoneController.text.trim()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      showLogo: true,
      child: BlocConsumer<RemoteLoginBloc, RemoteLoginState>(
        listener: (context, state) {
          if (state is CheckPhoneNumberSuccessState) {
            final phone = _phoneController.text.trim();
            if (state.isExist) {
              Navigator.pushNamed(
                context,
                AppRoutes.login,
                arguments: {'phoneNumber': phone, 'userName': 'Khách hàng'},
              );
            } else {
              Navigator.pushNamed(
                context,
                AppRoutes.register,
                arguments: {'phoneNumber': phone},
              );
            }
          } else if (state is RemoteLoginFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.dioException?.message ?? 'Đã xảy ra lỗi')),
            );
          }
        },
        builder: (context, state) {
          return Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Roomio xin chào!',
                  style: context.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Chúng tôi sẽ liên hệ với bạn qua điện thoại hoặc tin nhắn để hỗ trợ tìm phòng phù hợp trong thời gian sớm nhất.',
                  style: context.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    prefixIcon: Icon(Icons.phone_iphone),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập số điện thoại';
                    }
                    if (!RegExp(r'(^(?:[+0]9)?[0-9]{10,12}$)').hasMatch(value)) {
                      return 'Số điện thoại không hợp lệ';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: state is RemoteLoginLoading ? null : _onSubmit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: state is RemoteLoginLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Tiếp tục', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('hoặc', style: context.bodyMedium),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () {
                    // Xử lý xem ẩn danh
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Tiếp tục xem dạng ẩn danh', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}