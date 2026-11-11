import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/config/route/app_route.dart';
import 'package:roomio/config/theme/app_text_style.dart';
import 'package:roomio/core/storage/secure_storage_service.dart';
import 'package:roomio/features/profile/presentation/bloc/remote/remote_profile_bloc.dart';
import 'package:roomio/features/profile/presentation/bloc/remote/remote_profile_event.dart';
import 'package:roomio/features/profile/presentation/bloc/remote/remote_profile_state.dart';
import 'package:roomio/features/profile/presentation/widget/avatar_picker_widget.dart';
import 'package:roomio/injection_container.dart';

class CreateProfilePage extends StatefulWidget {
  final String? role;

  const CreateProfilePage({super.key, this.role});

  @override
  State<CreateProfilePage> createState() => _CreateProfilePageState();
}

class _CreateProfilePageState extends State<CreateProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  File? _selectedImage;
  String _selectedGender = 'Nam';
  String _currentRole = 'CUSTOMER';
  bool _isSubmitting = false;
  String _loadingMessage = '';

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    if (widget.role != null && widget.role!.isNotEmpty) {
      setState(() {
        _currentRole = widget.role!;
      });
    } else {
      final storedRole = await sl<SecureStorageService>().getRole();
      if (storedRole != null && storedRole.isNotEmpty) {
        setState(() {
          _currentRole = storedRole;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onCompletePressed() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ảnh đại diện để hoàn thiện hồ sơ!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _loadingMessage = 'Đang tải ảnh đại diện lên máy chủ...';
    });

    // BƯỚC 1: Upload avatar lên server trước
    context.read<RemoteProfileBloc>().add(
          UploadAvatarEvent(avatarUrl: _selectedImage!.path),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLandlord = _currentRole == 'LANDLORD';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Hoàn tất hồ sơ'),
        centerTitle: true,
        automaticallyImplyLeading: false, // Bắt buộc hoàn tất hồ sơ cho lần đầu
        elevation: 0,
      ),
      body: BlocConsumer<RemoteProfileBloc, RemoteProfileState>(
        listener: (context, state) {
          if (state is RemoteUploadAvatarSuccess) {
            // BƯỚC 2: Nhận kết quả upload avatar thành công (imageUrl, publicId)
            // Tiếp tục gọi API lưu thông tin profile
            setState(() {
              _loadingMessage = 'Đang lưu thông tin cá nhân...';
            });

            final imageUrl = state.image.imageUrl ?? '';

            context.read<RemoteProfileBloc>().add(
                  CreateProfileEvent(
                    name: _nameController.text.trim(),
                    gender: _selectedGender,
                    description: _descriptionController.text.trim(),
                    avatarUrl: imageUrl,
                  ),
                );
          } else if (state is RemoteProfileSuccessState) {
            // Hoàn tất lưu thông tin profile vào database
            setState(() {
              _isSubmitting = false;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tạo hồ sơ thành công! Chào mừng bạn đến với Roomio.'),
                backgroundColor: Colors.green,
              ),
            );

            // Điều hướng vào màn hình chính sau khi tạo profile thành công
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.home,
              (route) => false,
            );
          } else if (state is RemoteProfileFailure) {
            setState(() {
              _isSubmitting = false;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.dio.message ?? 'Đã xảy ra lỗi, vui lòng thử lại!'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is RemoteProfileLoading || _isSubmitting;

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Tiêu đề & Giới thiệu
                      Text(
                        'Chào mừng bạn!',
                        style: context.titleLarge?.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Vui lòng thiết lập hồ sơ cá nhân để hoàn tất đăng ký tài khoản.',
                        style: context.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),

                      // Badge phân loại Role
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isLandlord ? Icons.home_work_outlined : Icons.person_outline,
                                size: 16,
                                color: theme.primaryColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isLandlord ? 'Vai trò: Chủ trọ' : 'Vai trò: Khách thuê',
                                style: TextStyle(
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // 1. CHỌN ẢNH ĐẠI DIỆN (AVATAR)
                      AvatarPickerWidget(
                        imageFile: _selectedImage,
                        onImageSelected: (file) {
                          setState(() {
                            _selectedImage = file;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Chạm vào ảnh để thay đổi',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),

                      // 2. NHẬP HỌ VÀ TÊN
                      const Text(
                        'Họ và tên *',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        enabled: !isLoading,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: 'Nhập họ và tên đầy đủ',
                          prefixIcon: const Icon(Icons.person_outline),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey[200]!),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập họ và tên';
                          }
                          if (value.trim().length < 2) {
                            return 'Họ tên phải có ít nhất 2 ký tự';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // 3. GIỚI TÍNH
                      const Text(
                        'Giới tính *',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedGender,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.transgender_outlined),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey[200]!),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Nam', child: Text('Nam')),
                          DropdownMenuItem(value: 'Nữ', child: Text('Nữ')),
                          DropdownMenuItem(value: 'Khác', child: Text('Khác')),
                        ],
                        onChanged: isLoading
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedGender = value;
                                  });
                                }
                              },
                      ),
                      const SizedBox(height: 20),

                      // 4. GIỚI THIỆU BẢN THÂN (MÔ TẢ)
                      const Text(
                        'Mô tả bản thân',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        enabled: !isLoading,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: isLandlord
                              ? 'Ví dụ: Tôi là chủ chuỗi nhà trọ Roomio tại Quận 1...'
                              : 'Ví dụ: Tôi là sinh viên năm 3, tìm phòng yên tĩnh...',
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 40),
                            child: Icon(Icons.edit_note_outlined),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey[200]!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),

                      // 5. NÚT HOÀN THÀNH
                      ElevatedButton(
                        onPressed: isLoading ? null : _onCompletePressed,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isLoading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _loadingMessage.isNotEmpty
                                        ? _loadingMessage
                                        : 'Đang xử lý...',
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ],
                              )
                            : const Text(
                                'Hoàn thành',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Loading overlay khi đang thực hiện các bước upload & tạo profile
              if (isLoading)
                Container(
                  color: Colors.black.withValues(alpha: 0.25),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: theme.primaryColor,
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _loadingMessage.isNotEmpty
                                ? _loadingMessage
                                : 'Đang xử lý thông tin...',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Vui lòng chờ trong giây lát',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
