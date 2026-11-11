import 'dart:io';
import 'package:flutter/material.dart';
import 'package:roomio/features/room/domain/entities/room_sub_entities.dart';
import 'package:roomio/features/room/presentation/widgets/room_ui.dart';

class RoomPhotoPicker extends StatelessWidget {
  final List<RoomImageEntity> images;
  final List<File> files;
  final int thumbnailIndex;
  final VoidCallback onPick;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onThumbnailChanged;
  const RoomPhotoPicker({
    super.key,
    required this.images,
    required this.files,
    required this.thumbnailIndex,
    required this.onPick,
    required this.onRemove,
    required this.onThumbnailChanged,
  });

  @override
  Widget build(BuildContext context) => RoomSection(
    title: 'Ảnh phòng',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Chọn ít nhất một ảnh. Chạm biểu tượng ngôi sao để chọn ảnh bìa.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(
            images.length + files.length,
            (index) => SizedBox(
              width: 132,
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 100,
                      width: 132,
                      child: index < images.length
                          ? RoomNetworkImage(url: images[index].imageUrl)
                          : Image.file(
                              files[index - images.length],
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.broken_image_outlined),
                            ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => onThumbnailChanged(index),
                        tooltip: 'Chọn ảnh bìa',
                        icon: Icon(
                          index == thumbnailIndex
                              ? Icons.star
                              : Icons.star_border,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      IconButton(
                        onPressed: () => onRemove(index),
                        tooltip: 'Xóa ảnh',
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  if (index == thumbnailIndex) const Text('Ảnh bìa'),
                ],
              ),
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('Chọn ảnh từ thiết bị'),
        ),
      ],
    ),
  );
}
