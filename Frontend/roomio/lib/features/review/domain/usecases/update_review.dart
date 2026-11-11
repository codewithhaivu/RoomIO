import 'package:equatable/equatable.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/review/domain/entities/review.dart';
import 'package:roomio/features/review/domain/repository/review_repository.dart';

class UpdateReviewUseCase
    extends UseCase<DataState<ReviewResponse>, UpdateReviewParams> {
  final ReviewRepository _reviewRepository;

  UpdateReviewUseCase(this._reviewRepository);

  @override
  Future<DataState<ReviewResponse>> call(UpdateReviewParams params) =>
      _reviewRepository.updateReview(
        params.reviewId,
        params.content,
        params.rating,
      );
}

class UpdateReviewParams extends Equatable {
  final String reviewId;
  final String? content;
  final double? rating;

  const UpdateReviewParams({required this.reviewId, this.content, this.rating});

  @override
  List<Object?> get props => [reviewId, content, rating];
}
