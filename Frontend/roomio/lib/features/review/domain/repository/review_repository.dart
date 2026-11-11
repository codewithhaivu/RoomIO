import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/review/domain/entities/review.dart';

abstract class ReviewRepository {
  Future<DataState<ListReviewResponse>> getReviews(String roomId);
  Future<DataState<ReviewResponse>> updateReview(
    String reviewId,
    String? content,
    double? rating,
  );
  Future<DataState<String>> deleteReview(String reviewId);
  Future<DataState<ReviewResponse>> postReview(
    String roomId,
    String content,
    double rating,
  );
}
