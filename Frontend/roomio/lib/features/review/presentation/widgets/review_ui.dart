import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:roomio/features/review/presentation/bloc/review_state.dart';

String reviewError(DioException? error, {ReviewAction? action}) {
  final data = error?.response?.data;
  if (data is Map) {
    final detail = data['detail'] ?? data['message'] ?? data['Message'];
    if (detail is String && detail.trim().isNotEmpty) return detail;
    if (detail is List) {
      return 'Thông tin đánh giá chưa hợp lệ. Vui lòng kiểm tra lại.';
    }
  }
  if (error?.response?.statusCode == 401) {
    return 'Vui lòng đăng nhập để đánh giá phòng.';
  }
  if (error?.response?.statusCode == 403) {
    return action == ReviewAction.post
        ? 'Chỉ khách đang thuê hoặc đã thuê phòng này mới được đánh giá.'
        : 'Bạn chỉ có thể sửa hoặc xóa đánh giá của mình.';
  }
  if (error?.response?.statusCode == 404) {
    return 'Phòng hoặc đánh giá không còn tồn tại.';
  }
  if (error?.response?.statusCode == 409) {
    return 'Đánh giá đã thay đổi. Vui lòng tải lại danh sách.';
  }
  if (error?.response?.statusCode == 422) {
    return 'Thông tin đánh giá chưa hợp lệ. Vui lòng kiểm tra lại.';
  }
  if (error?.error is String && error?.response == null) {
    return error!.error as String;
  }
  return switch (error?.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.sendTimeout => 'Kết nối quá lâu. Vui lòng thử lại.',
    DioExceptionType.connectionError =>
      'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng.',
    _ => 'Không thể hoàn tất yêu cầu. Vui lòng thử lại.',
  };
}

class ReviewStars extends StatelessWidget {
  final double rating;
  final ValueChanged<double>? onChanged;

  const ReviewStars({super.key, required this.rating, this.onChanged});

  @override
  Widget build(BuildContext context) => Wrap(
    children: List.generate(5, (index) {
      final icon = Icon(
        rating >= index + 1
            ? Icons.star
            : rating > index
            ? Icons.star_half
            : Icons.star_border,
        size: onChanged == null ? 18 : 28,
        color: Theme.of(context).colorScheme.primary,
      );
      return onChanged == null
          ? icon
          : IconButton(
              tooltip: '${index + 1} sao',
              onPressed: () => onChanged!((index + 1).toDouble()),
              icon: icon,
            );
    }),
  );
}
