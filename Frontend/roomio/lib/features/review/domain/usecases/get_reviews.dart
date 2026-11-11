import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/review/domain/entities/review.dart';
import 'package:roomio/features/review/domain/repository/review_repository.dart';

class GetReviewsUseCase extends UseCase<DataState<ListReviewResponse>, String> {
  final ReviewRepository _reviewRepository;

  GetReviewsUseCase(this._reviewRepository);

  @override
  Future<DataState<ListReviewResponse>> call(String params) =>
      _reviewRepository.getReviews(params);
}
