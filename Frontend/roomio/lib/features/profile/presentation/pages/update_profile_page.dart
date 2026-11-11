import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/features/profile/domain/entities/profile.dart';
import 'package:roomio/features/profile/presentation/bloc/remote/remote_profile_bloc.dart';
import 'package:roomio/features/profile/presentation/bloc/remote/remote_profile_event.dart';
import 'package:roomio/features/profile/presentation/bloc/remote/remote_profile_state.dart';
import 'package:roomio/features/profile/presentation/widget/avatar_picker_widget.dart';

class UpdateProfilePage extends StatefulWidget {
  const UpdateProfilePage({super.key});

  @override
  State<UpdateProfilePage> createState() => _UpdateProfilePageState();
}

class _UpdateProfilePageState extends State<UpdateProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  File? _selectedImage; // Ảnh mới chọn từ máy (nếu có)
  String _selectedGender = 'Nam';
  bool _isSubmitting = false;
  String _loadingMessage = '';

  // Dữ liệu hồ sơ hiện tại được truyền vào từ trang trước
  ProfileEntity? _profile;
  String? _avatarUrl;
  String? _uploadedImagePath;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Chỉ pre-fill một lần duy nhất khi widget lần đầu được mount
    if (_profile == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      ProfileEntity? profile;
      if (args is Map<String, dynamic>) {
        profile = args['profile'] as ProfileEntity?;
      } else if (args is ProfileEntity) {
        // Fallback nếu truyền thẳng ProfileEntity
        profile = args;
      }
      if (profile != null) {
        _profile = profile;
        _prefillForm(_profile!);
      }
    }
  }

  /// Pre-fill các controller và state từ dữ liệu hồ sơ hiện tại
  void _prefillForm(ProfileEntity profile) {
    _nameController.text = profile.name ?? '';
    _descriptionController.text = profile.description ?? '';
    _avatarUrl = profile.avartarUrl;

    // Map giá trị gender từ server → giá trị hiển thị trong Dropdown
    final genderMap = {
      'Nam': 'Nam',
      'Nữ': 'Nữ',
      'Khác': 'Khác',
      // Thêm mapping nếu server trả về giá trị khác (vd: 'MALE', 'FEMALE')
    };
    _selectedGender = genderMap[profile.gender] ?? 'Nam';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onSavePressed() {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _loadingMessage =
          _selectedImage != null && _selectedImage!.path != _uploadedImagePath
          ? 'Đang tải ảnh đại diện lên máy chủ...'
          : 'Đang lưu thông tin cá nhân...';
    });

    if (_selectedImage != null && _selectedImage!.path != _uploadedImagePath) {
      // Người dùng chọn ảnh mới → upload trước rồi mới update profile
      context.read<RemoteProfileBloc>().add(
        UploadAvatarEvent(avatarUrl: _selectedImage!.path),
      );
    } else {
      // Giữ nguyên avatar cũ → update thẳng
      context.read<RemoteProfileBloc>().add(
        UpdateProfileEvent(
          name: _nameController.text.trim(),
          gender: _selectedGender,
          description: _descriptionController.text.trim(),
          avatarUrl: _avatarUrl,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Chỉnh sửa hồ sơ'),
        centerTitle: true,
        elevation: 0,
      ),
      body: BlocConsumer<RemoteProfileBloc, RemoteProfileState>(
        listener: (context, state) {
          if (state is RemoteUploadAvatarSuccess) {
            // Upload avatar thành công → tiếp tục update profile
            setState(() {
              _loadingMessage = 'Đang lưu thông tin cá nhân...';
              _avatarUrl = state.image.imageUrl ?? _avatarUrl;
              _uploadedImagePath = _selectedImage?.path;
            });

            context.read<RemoteProfileBloc>().add(
              UpdateProfileEvent(
                name: _nameController.text.trim(),
                gender: _selectedGender,
                description: _descriptionController.text.trim(),
                avatarUrl: _avatarUrl,
              ),
            );
          } else if (state is RemoteProfileSuccessState) {
            setState(() => _isSubmitting = false);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cập nhật hồ sơ thành công!'),
                backgroundColor: Colors.green,
              ),
            );

            // Pop về HomePage → HomePage sẽ tự gọi _loadProfileData()
            Navigator.pop(context);
          } else if (state is RemoteProfileFailure) {
            setState(() => _isSubmitting = false);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.dio.message ?? 'Đã xảy ra lỗi, vui lòng thử lại!',
                ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ------- AVATAR -------
                      AvatarPickerWidget(
                        imageFile: _selectedImage,
                        imageUrl: _avatarUrl,
                        enabled: !isLoading,
                        onImageSelected: (file) {
                          setState(() => _selectedImage = file);
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Chạm vào ảnh để thay đổi',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),

                      // ------- HỌ VÀ TÊN -------
                      const Text(
                        'Họ và tên *',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
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

                      // ------- GIỚI TÍNH -------
                      const Text(
                        'Giới tính *',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
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
                                  setState(() => _selectedGender = value);
                                }
                              },
                      ),
                      const SizedBox(height: 20),

                      // ------- MÔ TẢ -------
                      const Text(
                        'Mô tả bản thân',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        enabled: !isLoading,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Giới thiệu ngắn về bản thân...',
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

                      // ------- NÚT LƯU -------
                      ElevatedButton(
                        onPressed: isLoading ? null : _onSavePressed,
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
                                'Lưu thay đổi',
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

              // Loading overlay
              if (isLoading)
                Container(
                  color: Colors.black.withValues(alpha: 0.25),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 24,
                      ),
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
