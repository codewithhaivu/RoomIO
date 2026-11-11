

import 'package:flutter/material.dart';


import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/login/remote_login_bloc.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/login/remote_login_event.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/login/remote_login_state.dart';
import 'package:roomio/config/theme/app_text_style.dart';
import 'package:roomio/features/auth/presentation/widget/auth_layout.dart';
import 'package:roomio/config/route/app_route.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/storage/secure_storage_service.dart';
import 'package:roomio/features/profile/domain/usecase/landlord/get_profile.dart';
import 'package:roomio/features/profile/domain/usecase/tenant/get_profile.dart';
import 'package:roomio/injection_container.dart';

class LoginPage extends StatefulWidget {
  final String phoneNumber;
  final String userName;

  const LoginPage({super.key, required this.phoneNumber, required this.userName});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _obscureText = true;
  bool _isCheckingProfile = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _onLogin() {
    if (_formKey.currentState!.validate()) {
      context.read<RemoteLoginBloc>().add(
        Login(
          phoneNumber: widget.phoneNumber,
          password: _passwordController.text,
        ),
      );
    }
  }

  Future<void> _handlePostLoginNavigation(BuildContext context, String defaultRole) async {
    setState(() {
      _isCheckingProfile = true;
    });

    try {
      // 1. Đọc role từ FlutterSecureStorage thông qua SecureStorageService
      final secureStorage = sl<SecureStorageService>();
      final role = await secureStorage.getRole() ?? defaultRole;

      // 2. Kiểm tra xem người dùng đã tạo profile trước đó chưa
      final profileResult = role == 'LANDLORD'
          ? await sl<GetProfileLandLordUseCase>()(null)
          : await sl<GetProfileTenantUseCase>()(null);

      if (!context.mounted) return;

      if (profileResult is DataSuccess &&
          profileResult.data?.name != null &&
          profileResult.data!.name!.trim().isNotEmpty) {
        // Đã có profile -> Vào màn hình chính
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.home,
          (route) => false,
        );
      } else {
        // Người dùng đăng nhập lần đầu tiên -> Điều hướng thẳng đến màn hình Tạo Profile
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.createProfile,
          (route) => false,
          arguments: {'role': role},
        );
      }
    } catch (_) {
      final role = await sl<SecureStorageService>().getRole() ?? defaultRole;
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.createProfile,
        (route) => false,
        arguments: {'role': role},
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingProfile = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      showLogo: false,
      child: BlocConsumer<RemoteLoginBloc, RemoteLoginState>(
        listener: (context, state) {
          if (state is RemoteLoginSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đăng nhập thành công!')),
            );
            _handlePostLoginNavigation(context, state.loginResponseEntity?.role ?? 'CUSTOMER');
          } else if (state is RemoteLoginFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text((state.dioException?.response?.data as Map?)?['detail'] ?? state.dioException?.message ?? 'Đăng nhập thất bại vui lòng thử lại sau')),
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
                        'Đổi tài khoản',
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
                  'Xin chào, ${widget.userName}',
                  style: context.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Nhập mật khẩu',
                  style: context.bodyMedium,
                ),
                const SizedBox(height: 24),
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
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.forgotPasswordOtp,
                        arguments: {'phoneNumber': widget.phoneNumber},
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Quên mật khẩu?',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: (state is RemoteLoginLoading || _isCheckingProfile) ? null : _onLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: (state is RemoteLoginLoading || _isCheckingProfile)
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Đăng nhập', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}