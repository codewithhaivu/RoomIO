import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/forgot_password/remote_forgot_password_bloc.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/forgot_password/remote_forgot_password_event.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/forgot_password/remote_forgot_password_state.dart';
import 'package:roomio/config/route/app_route.dart';
import 'package:roomio/config/theme/app_text_style.dart';
import 'package:roomio/features/auth/presentation/widget/auth_layout.dart';
import 'package:roomio/features/auth/presentation/widget/otp_input_widget.dart';

class ForgotPasswordOtpPage extends StatefulWidget {
  final String phoneNumber;
  
  const ForgotPasswordOtpPage({super.key, required this.phoneNumber});

  @override
  State<ForgotPasswordOtpPage> createState() => _ForgotPasswordOtpPageState();
}

class _ForgotPasswordOtpPageState extends State<ForgotPasswordOtpPage> {
  String _otp = '';
  Timer? _timer;
  int _seconds = 60;

  @override
  void initState() {
    super.initState();
    _startTimer();
    // Send OTP automatically when page opens
    context.read<RemoteForgotPasswordBloc>().add(
      SendOTPForgotPassword(phoneNumber: widget.phoneNumber),
    );
  }

  void _startTimer() {
    _seconds = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds > 0) {
        setState(() {
          _seconds--;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onVerify() {
    if (_otp.length == 4) {
      context.read<RemoteForgotPasswordBloc>().add(
        VerifyOTPForgotPassword(phoneNumber: widget.phoneNumber, otp: _otp),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đủ mã OTP')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      showLogo: false,
      child: BlocConsumer<RemoteForgotPasswordBloc, RemoteForgotPasswordState>(
        listener: (context, state) {
          if (state is verifyOTPForgotPasswordSuccessState) {
            // Navigate to Reset Password
            Navigator.pushReplacementNamed(
              context,
              AppRoutes.resetPassword,
              arguments: {'phoneNumber': widget.phoneNumber},
            );
          } else if (state is RemoteForgotPasswordFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.dioException?.message ?? 'Xác thực OTP thất bại')),
            );
          } else if (state is sendOTPForgotPasswordSuccessState) {
             ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đã gửi lại mã OTP!')),
            );
          }
        },
        builder: (context, state) {
          return Column(
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
                'Xác nhận số điện thoại',
                style: context.titleLarge,
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: context.bodyMedium,
                  children: [
                    const TextSpan(text: 'Mã xác thực đã được gửi đến Zalo / SMS của số điện thoại '),
                    TextSpan(
                      text: widget.phoneNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              OtpInputWidget(
                length: 4,
                onCompleted: (value) {
                  setState(() {
                    _otp = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              Text(
                _seconds > 0 ? 'Mã OTP sẽ hết hạn sau $_seconds giây' : 'Mã OTP đã hết hạn',
                style: context.bodyMedium,
              ),
              if (_seconds == 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {
                      _startTimer();
                      context.read<RemoteForgotPasswordBloc>().add(
                        SendOTPForgotPassword(phoneNumber: widget.phoneNumber),
                      );
                    },
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    child: Text(
                      'Gửi lại mã',
                      style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: state is RemoteForgotPasswordLoading ? null : _onVerify,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: state is RemoteForgotPasswordLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Xác nhận', style: TextStyle(fontSize: 16)),
              ),
            ],
          );
        },
      ),
    );
  }
}
