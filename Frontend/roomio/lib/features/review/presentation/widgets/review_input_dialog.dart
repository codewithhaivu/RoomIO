import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/features/review/domain/entities/review.dart';
import 'package:roomio/features/review/presentation/bloc/review_bloc.dart';
import 'package:roomio/features/review/presentation/bloc/review_event.dart';
import 'package:roomio/features/review/presentation/bloc/review_state.dart';
import 'review_ui.dart';

/// Show with BlocProvider.value so the dialog shares its room's ReviewBloc.
class ReviewInputDialog extends StatefulWidget {
  final ReviewResponse? review;

  const ReviewInputDialog({super.key, this.review});

  @override
  State<ReviewInputDialog> createState() => _ReviewInputDialogState();
}

class _ReviewInputDialogState extends State<ReviewInputDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _content;
  late double _rating;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _content = TextEditingController(text: widget.review?.content ?? '');
    _rating = widget.review?.rating ?? 0;
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  void _submit() {
    final bloc = context.read<ReviewBloc>();
    if (bloc.state.isMutating || bloc.state.status != ReviewStatus.success) {
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitted = true);
    final review = widget.review;
    bloc.add(
      review == null
          ? ReviewPostRequested(content: _content.text, rating: _rating)
          : ReviewUpdateRequested(
              reviewId: review.idReview,
              content: _content.text,
              rating: _rating,
            ),
    );
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<ReviewBloc, ReviewState>(
    listenWhen: (previous, current) =>
        _submitted && previous.mutationStatus != current.mutationStatus,
    listener: (context, state) {
      if (state.mutationStatus == ReviewMutationStatus.success) {
        Navigator.pop(context, true);
      }
    },
    builder: (context, state) {
      final busy = state.isMutating;
      final failed =
          _submitted && state.mutationStatus == ReviewMutationStatus.failure;
      return PopScope(
        canPop: !busy,
        child: AlertDialog(
          title: Text(
            widget.review == null ? 'Đánh giá phòng' : 'Sửa đánh giá',
          ),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FormField<double>(
                    initialValue: _rating,
                    validator: (_) =>
                        _rating.isFinite && _rating >= 1 && _rating <= 5
                        ? null
                        : 'Vui lòng chọn từ 1 đến 5 sao.',
                    builder: (field) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IgnorePointer(
                          ignoring: busy,
                          child: ReviewStars(
                            rating: _rating,
                            onChanged: (rating) {
                              setState(() => _rating = rating);
                              field.didChange(rating);
                            },
                          ),
                        ),
                        if (field.hasError)
                          Text(
                            field.errorText!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _content,
                    enabled: !busy,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 255,
                    decoration: const InputDecoration(
                      labelText: 'Nhận xét',
                      hintText: 'Chia sẻ trải nghiệm thuê phòng...',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'Vui lòng nhập nhận xét.';
                      if (text.runes.length > 255) {
                        return 'Nhận xét tối đa 255 ký tự.';
                      }
                      return null;
                    },
                  ),
                  if (failed) ...[
                    const SizedBox(height: 8),
                    Text(
                      reviewError(state.mutationError, action: state.action),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (busy) const LinearProgressIndicator(),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: busy || state.status != ReviewStatus.success
                  ? null
                  : _submit,
              child: Text(
                busy
                    ? 'Đang lưu...'
                    : widget.review == null
                    ? 'Gửi đánh giá'
                    : 'Lưu thay đổi',
              ),
            ),
          ],
        ),
      );
    },
  );
}
