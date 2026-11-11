import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/usecase/usecase.dart';
import 'package:roomio/features/review/domain/repository/review_repository.dart';

class DeleteReviewUseCase extends UseCase<DataState<String>, String> {
  final ReviewRepository _reviewRepository;

  DeleteReviewUseCase(this._reviewRepository);

  @override
  Future<DataState<String>> call(String params) =>
      _reviewRepository.deleteReview(params);
}
