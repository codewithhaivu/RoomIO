import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/register/remote_register_bloc.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/register/remote_register_event.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/register/remote_register_state.dart';
import 'package:roomio/config/theme/app_text_style.dart';
import 'package:roomio/features/auth/presentation/widget/auth_layout.dart';
import 'package:roomio/config/route/app_route.dart';

class RegisterPasswordPage extends StatefulWidget {
  final String phoneNumber;
  final String role;
  
  const RegisterPasswordPage({super.key, required this.phoneNumber, required this.role});

  @override
  State<RegisterPasswordPage> createState() => _RegisterPasswordPageState();
}

class _RegisterPasswordPageState extends State<RegisterPasswordPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  bool _obscureText = true;
  bool _obscureConfirmText = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onRegister() {
    if (_formKey.currentState!.validate()) {
      context.read<RemoteRegisterBloc>().add(
        Register(
          phoneNumber: widget.phoneNumber,
          password: _passwordController.text,
          role: widget.role,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      showLogo: false,
      child: BlocConsumer<RemoteRegisterBloc, RemoteRegisterState>(
        listener: (context, state) {
          if (state is RemoteRegisterSuccessState) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đăng ký tài khoản thành công!')),
            );
            // Về trang Login
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.login,
              (route) => route.settings.name == AppRoutes.checkPhone,
              arguments: {'phoneNumber': widget.phoneNumber, 'userName': 'Khách hàng'},
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
                Text(
                  'Đặt mật khẩu',
                  style: context.titleLarge,
                ),
                const SizedBox(height: 24),
                Text(
                  'Mật khẩu',
                  style: context.bodyMedium?.copyWith(color: Colors.black87),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscureText,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập mật khẩu';
                    }
                    if (value.length < 6) {
                      return 'Mật khẩu phải có ít nhất 6 ký tự';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Xác nhận mật khẩu',
                  style: context.bodyMedium?.copyWith(color: Colors.black87),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmText,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmText ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmText = !_obscureConfirmText;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng xác nhận mật khẩu';
                    }
                    if (value != _passwordController.text) {
                      return 'Mật khẩu không khớp';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: state is RemoteRegisterLoading ? null : _onRegister,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: state is RemoteRegisterLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Hoàn tất', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
