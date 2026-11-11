import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/review/data/data_sources/remote/review_api_service.dart';
import 'package:roomio/features/review/data/models/review.dart';
import 'package:roomio/features/review/domain/entities/review.dart';
import 'package:roomio/features/review/domain/repository/review_repository.dart';

class ReviewRepositoryImpl implements ReviewRepository {
  final ReviewApiService _reviewApiService;

  ReviewRepositoryImpl(this._reviewApiService);

  @override
  Future<DataState<ListReviewResponse>> getReviews(String roomId) => _request(
    () => _reviewApiService.getReviewInARoom(roomId),
    (model) => model.toEntity(),
    path: '/$roomId',
    method: 'GET',
  );

  @override
  Future<DataState<ReviewResponse>> postReview(
    String roomId,
    String content,
    double rating,
  ) => _request(
    () => _reviewApiService.postReviewInARoom(
      ReviewModelRequest(content: content, rating: rating),
      roomId,
    ),
    (model) => model.toEntity(),
    path: '/$roomId',
    method: 'POST',
  );

  @override
  Future<DataState<ReviewResponse>> updateReview(
    String reviewId,
    String? content,
    double? rating,
  ) => _request(
    () => _reviewApiService.updateReviewInARoom(
      reviewId,
      ReviewModelRequest(content: content, rating: rating),
    ),
    (model) => model.toEntity(),
    path: '/$reviewId',
    method: 'PATCH',
  );

  @override
  Future<DataState<String>> deleteReview(String reviewId) => _request(
    () => _reviewApiService.deleteReviewInARoom(reviewId),
    (model) => model.message,
    path: '/$reviewId',
    method: 'DELETE',
  );

  Future<DataState<T>> _request<M, T>(
    Future<HttpResponse<M>> Function() request,
    T Function(M) toEntity, {
    required String path,
    required String method,
  }) async {
    try {
      final result = await request();
      final code = result.response.statusCode;
      if (code != null && code >= 200 && code < 300) {
        return DataSuccess(toEntity(result.data));
      }
      return DataError(
        DioException(
          requestOptions: result.response.requestOptions,
          response: result.response,
          type: DioExceptionType.badResponse,
          error: result.response.statusMessage,
        ),
      );
    } on DioException catch (error) {
      return DataError(error);
    } catch (error, stackTrace) {
      return DataError(
        DioException(
          requestOptions: RequestOptions(path: path, method: method),
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
