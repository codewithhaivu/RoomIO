import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/features/review/domain/entities/review.dart';
import 'package:roomio/features/review/presentation/bloc/review_bloc.dart';
import 'package:roomio/features/review/presentation/bloc/review_event.dart';
import 'package:roomio/features/review/presentation/bloc/review_state.dart';
import 'package:roomio/injection_container.dart';
import 'review_input_dialog.dart';
import 'review_item_widget.dart';
import 'review_ui.dart';

/// Embed directly in the room detail's Column or ListView.
/// [canPostReview] exposes review actions for signed-in tenants.
/// The backend authorizes every write using the account in the access token.
class RoomReviewSection extends StatelessWidget {
  final String roomId;
  final bool canPostReview;

  const RoomReviewSection({
    super.key,
    required this.roomId,
    this.canPostReview = false,
  });

  @override
  Widget build(BuildContext context) => BlocProvider<ReviewBloc>(
    key: ValueKey(roomId),
    create: (_) =>
        sl<ReviewBloc>(param1: roomId)..add(const ReviewsRequested()),
    child: _ReviewSectionContent(canPostReview: canPostReview),
  );
}

class _ReviewSectionContent extends StatefulWidget {
  final bool canPostReview;

  const _ReviewSectionContent({required this.canPostReview});

  @override
  State<_ReviewSectionContent> createState() => _ReviewSectionContentState();
}

class _ReviewSectionContentState extends State<_ReviewSectionContent> {
  bool _dialogOpen = false;

  Future<void> _edit([ReviewResponse? review]) async {
    if (_dialogOpen) return;
    setState(() => _dialogOpen = true);
    final bloc = context.read<ReviewBloc>();
    try {
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: ReviewInputDialog(review: review),
        ),
      );
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
    }
  }

  Future<void> _delete(ReviewResponse review) async {
    if (_dialogOpen) return;
    setState(() => _dialogOpen = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Xóa đánh giá?'),
          content: const Text('Bạn có muốn xóa đánh giá này khỏi phòng?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xóa'),
            ),
          ],
        ),
      );
      if (mounted && confirmed == true) {
        context.read<ReviewBloc>().add(
          ReviewDeleteRequested(reviewId: review.idReview),
        );
      }
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<ReviewBloc, ReviewState>(
    listenWhen: (previous, current) =>
        previous.mutationStatus != current.mutationStatus,
    listener: (context, state) {
      String? message;
      if (state.mutationStatus == ReviewMutationStatus.success) {
        message = switch (state.action) {
          ReviewAction.post => 'Đã gửi đánh giá.',
          ReviewAction.update => 'Đã cập nhật đánh giá.',
          ReviewAction.delete => 'Đã xóa đánh giá.',
          null => null,
        };
      } else if (state.mutationStatus == ReviewMutationStatus.failure &&
          state.action == ReviewAction.delete) {
        message = reviewError(state.mutationError, action: state.action);
      }
      if (message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    },
    builder: (context, state) {
      final bloc = context.read<ReviewBloc>();
      final reviews = state.reviews.data;
      final canWrite = widget.canPostReview;
      final busy =
          state.isMutating ||
          state.status != ReviewStatus.success ||
          _dialogOpen;
      final average = reviews.isEmpty
          ? 0.0
          : reviews.fold<double>(0, (sum, review) => sum + review.rating) /
                reviews.length;
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Đánh giá (${reviews.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tải lại đánh giá',
                    onPressed: state.isLoading || state.isMutating
                        ? null
                        : () => bloc.add(const ReviewsRequested()),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              if (reviews.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ReviewStars(rating: average),
                    Text('${average.toStringAsFixed(1)}/5'),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (state.isLoading || state.isMutating)
                const LinearProgressIndicator(),
              if (state.status == ReviewStatus.failure) ...[
                const SizedBox(height: 12),
                Text(
                  reviewError(state.loadError),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => bloc.add(const ReviewsRequested()),
                    child: const Text('Thử lại'),
                  ),
                ),
              ],
              if (reviews.isEmpty && state.status == ReviewStatus.success)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Chưa có đánh giá nào cho phòng này.'),
                ),
              for (var index = 0; index < reviews.length; index++) ...[
                if (index > 0) const Divider(),
                ReviewItemWidget(
                  key: ValueKey(reviews[index].idReview),
                  review: reviews[index],
                  author: index < state.reviews.userData.length
                      ? state.reviews.userData[index]
                      : null,
                  showActions: canWrite,
                  isBusy: busy,
                  onEdit: busy ? null : () => _edit(reviews[index]),
                  onDelete: busy ? null : () => _delete(reviews[index]),
                ),
              ],
              const SizedBox(height: 12),
              if (canWrite) ...[
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _edit(),
                  icon: const Icon(Icons.rate_review_outlined),
                  label: const Text('Viết đánh giá'),
                ),
                const Text(
                  'Chỉ khách đang thuê hoặc đã thuê phòng này mới được đánh giá.',
                ),
              ] else
                const Text(
                  'Đăng nhập bằng tài khoản khách thuê để viết đánh giá.',
                ),
            ],
          ),
        ),
      );
    },
  );
}
