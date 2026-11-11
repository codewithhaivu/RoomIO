import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AvatarPickerWidget extends StatelessWidget {
  final File? imageFile;
  final String? imageUrl;
  final bool enabled;
  final ValueChanged<File> onImageSelected;
  final double radius;

  const AvatarPickerWidget({
    super.key,
    required this.imageFile,
    required this.onImageSelected,
    this.imageUrl,
    this.enabled = true,
    this.radius = 60,
  });

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    Navigator.pop(context); // Close bottom sheet
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null && context.mounted) {
        onImageSelected(File(pickedFile.path));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể chọn ảnh: $e')));
      }
    }
  }

  void _showImageSourceDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Chọn ảnh đại diện',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  title: const Text(
                    'Chụp ảnh mới',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Sử dụng máy ảnh để chụp chân dung'),
                  onTap: () => _pickImage(context, ImageSource.camera),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.photo_library,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  title: const Text(
                    'Chọn từ thư viện',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Chọn ảnh có sẵn từ bộ sưu tập'),
                  onTap: () => _pickImage(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final url = imageUrl?.trim();
    final hasRemoteImage = url != null && url.isNotEmpty;
    final ImageProvider? avatarImage = imageFile != null
        ? FileImage(imageFile!)
        : hasRemoteImage
        ? NetworkImage(url)
        : null;

    return Center(
      child: Stack(
        children: [
          GestureDetector(
            onTap: enabled ? () => _showImageSourceDialog(context) : null,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.3),
                  width: 2.5,
                ),
              ),
              child: CircleAvatar(
                radius: radius,
                backgroundColor: Colors.grey[200],
                foregroundImage: avatarImage,
                onForegroundImageError: avatarImage == null ? null : (_, _) {},
                child: avatarImage == null || imageFile == null
                    ? Icon(
                        Icons.person,
                        size: radius * 1.1,
                        color: Colors.grey[400],
                      )
                    : null,
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: GestureDetector(
              onTap: enabled ? () => _showImageSourceDialog(context) : null,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
