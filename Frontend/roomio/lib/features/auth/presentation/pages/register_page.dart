import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/register/remote_register_bloc.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/register/remote_register_event.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/register/remote_register_state.dart';
import 'package:roomio/config/theme/app_text_style.dart';
import 'package:roomio/features/auth/presentation/widget/auth_layout.dart';
import 'package:roomio/config/route/app_route.dart';

class RegisterPage extends StatefulWidget {
  final String phoneNumber;
  const RegisterPage({super.key, required this.phoneNumber});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String _selectedRole = 'CUSTOMER'; // Default role

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      showLogo: false,
      child: BlocConsumer<RemoteRegisterBloc, RemoteRegisterState>(
        listener: (context, state) {
          if (state is SendOTPSuccessState) {
            Navigator.pushNamed(
              context,
              AppRoutes.registerOtp,
              arguments: {'phoneNumber': widget.phoneNumber, 'role': _selectedRole},
            );
          } else if (state is RemoteRegisterFailure) {
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
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_back_ios, size: 16, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        'Quay lại',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Đăng ký',
                  style: context.titleLarge,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  initialValue: widget.phoneNumber,
                  readOnly: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.phone_iphone),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Vai trò',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'CUSTOMER',
                      child: Text('Khách hàng'),
                    ),
                    DropdownMenuItem(
                      value: 'LANDLORD',
                      child: Text('Chủ trọ'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedRole = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                RichText(
                  text: TextSpan(
                    style: context.bodyMedium,
                    children: [
                      const TextSpan(text: 'Bằng cách tiếp tục, bạn đồng ý với '),
                      TextSpan(
                        text: 'Điều khoản',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(text: ' và '),
                      TextSpan(
                        text: 'Chính sách Quyền riêng tư',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(text: ' của ROOMIO'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: state is RemoteRegisterLoading 
                      ? null 
                      : () {
                          if (_formKey.currentState!.validate()) {
                            context.read<RemoteRegisterBloc>().add(
                              SendOTPRegister(phoneNumber: widget.phoneNumber),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: state is RemoteRegisterLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Tiếp tục', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Bạn đã có tài khoản? ', style: context.bodyMedium),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacementNamed(
                        context,
                        AppRoutes.login,
                        arguments: {'phoneNumber': widget.phoneNumber, 'userName': 'Khách hàng'},
                      ),
                      child: Text(
                        'Đăng nhập',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}