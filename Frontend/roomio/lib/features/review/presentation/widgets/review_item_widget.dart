import 'package:flutter/material.dart';
import 'package:roomio/features/review/domain/entities/review.dart';
import 'review_ui.dart';

class ReviewItemWidget extends StatelessWidget {
  final ReviewResponse review;
  final UserReviewResponse? author;
  final bool showActions;
  final bool isBusy;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ReviewItemWidget({
    super.key,
    required this.review,
    this.author,
    this.showActions = false,
    this.isBusy = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final date = review.createdAt.toLocal();
    final avatar = author?.avatar?.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                foregroundImage: avatar == null || avatar.isEmpty
                    ? null
                    : NetworkImage(avatar),
                onForegroundImageError: avatar == null || avatar.isEmpty
                    ? null
                    : (_, _) {},
                child: const Icon(Icons.person_outline),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author?.fullName ?? 'Khách thuê',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Semantics(
                      label: '${review.rating} trên 5 sao',
                      child: ReviewStars(rating: review.rating),
                    ),
                  ],
                ),
              ),
              if (showActions)
                PopupMenuButton<String>(
                  enabled: !isBusy,
                  tooltip: 'Quản lý đánh giá',
                  onSelected: (value) =>
                      value == 'edit' ? onEdit?.call() : onDelete?.call(),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      enabled: onEdit != null,
                      child: const Text('Sửa đánh giá'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      enabled: onDelete != null,
                      child: const Text('Xóa đánh giá'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(review.content),
        ],
      ),
    );
  }
}
