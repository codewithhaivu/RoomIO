import 'package:equatable/equatable.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/review/domain/entities/review.dart';
import 'package:roomio/features/review/domain/repository/review_repository.dart';

class PostReviewUseCase
    extends UseCase<DataState<ReviewResponse>, PostReviewParams> {
  final ReviewRepository _reviewRepository;

  PostReviewUseCase(this._reviewRepository);

  @override
  Future<DataState<ReviewResponse>> call(PostReviewParams params) =>
      _reviewRepository.postReview(
        params.roomId,
        params.content,
        params.rating,
      );
}

class PostReviewParams extends Equatable {
  final String roomId;
  final String content;
  final double rating;

  const PostReviewParams({
    required this.roomId,
    required this.content,
    required this.rating,
  });

  @override
  List<Object?> get props => [roomId, content, rating];
}
