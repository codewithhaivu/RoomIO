import 'dart:async';
import 'package:dio/dio.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/review/data/data_sources/remote/review_api_service.dart';
import 'package:roomio/features/review/data/repository/review_repository_impl.dart';
import 'package:roomio/features/review/domain/entities/review.dart';
import 'package:roomio/features/review/domain/repository/review_repository.dart';
import 'package:roomio/features/review/domain/usecases/delete_review.dart';
import 'package:roomio/features/review/domain/usecases/get_reviews.dart';
import 'package:roomio/features/review/domain/usecases/post_review.dart';
import 'package:roomio/features/review/domain/usecases/update_review.dart';
import 'package:roomio/features/review/presentation/bloc/review_bloc.dart';

Map<String, dynamic> reviewJson({
  String id = 'review-1',
  Object rating = '4.5',
}) => {
  'id_review': id,
  'id_tenant': 'tenant-1',
  'content': 'Phòng sạch',
  'rating': rating,
  'created_at': '2026-10-27T08:00:00Z',
};

final review = ReviewResponse(
  idReview: 'review-1',
  idTenant: 'tenant-1',
  content: 'Phòng sạch',
  rating: 4.5,
  createdAt: DateTime.utc(2026, 10, 27, 8),
);
const author = UserReviewResponse(fullName: 'Nguyễn An', avatar: null);
final reviewList = ListReviewResponse(data: [review], userData: const [author]);

DioException forbidden() => DioException(
  requestOptions: RequestOptions(path: '/review-1'),
  response: Response(
    requestOptions: RequestOptions(path: '/review-1'),
    statusCode: 403,
    data: {
      'detail':
          'Chỉ khách thuê đang thuê hoặc đã từng thuê phòng mới được đánh giá',
    },
  ),
  type: DioExceptionType.badResponse,
);

class ReviewTestApi {
  final dio = Dio();
  final requests = <RequestOptions>[];
  late final ReviewRepositoryImpl repository;
  Object? data;
  int statusCode = 200;
  DioException? error;

  ReviewTestApi() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          if (error != null) {
            handler.reject(error!);
          } else {
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: statusCode,
                data: data,
              ),
            );
          }
        },
      ),
    );
    repository = ReviewRepositoryImpl(ReviewApiService(dio));
  }
}

class FakeReviewRepository implements ReviewRepository {
  ListReviewResponse reviews = reviewList;
  DioException? mutationError;
  DioException? loadError;
  Completer<DataState<ReviewResponse>>? pendingPost;
  final loads = <Completer<DataState<ListReviewResponse>>>[];
  bool deferLoads = false;
  int posts = 0;
  int updates = 0;
  int deletes = 0;
  int gets = 0;

  ReviewBloc bloc(String roomId) => ReviewBloc(
    GetReviewsUseCase(this),
    PostReviewUseCase(this),
    UpdateReviewUseCase(this),
    DeleteReviewUseCase(this),
    roomId: roomId,
  );

  @override
  Future<DataState<ListReviewResponse>> getReviews(String roomId) async {
    gets++;
    if (deferLoads) {
      final completer = Completer<DataState<ListReviewResponse>>();
      loads.add(completer);
      return completer.future;
    }
    return loadError == null ? DataSuccess(reviews) : DataError(loadError!);
  }

  @override
  Future<DataState<ReviewResponse>> postReview(
    String roomId,
    String content,
    double rating,
  ) async {
    posts++;
    if (pendingPost != null) return pendingPost!.future;
    if (mutationError != null) return DataError(mutationError!);
    final created = ReviewResponse(
      idReview: 'new-review',
      idTenant: 'tenant-1',
      content: content,
      rating: rating,
      createdAt: review.createdAt,
    );
    reviews = ListReviewResponse(
      data: [created, ...reviews.data],
      userData: [author, ...reviews.userData],
    );
    return DataSuccess(created);
  }

  @override
  Future<DataState<ReviewResponse>> updateReview(
    String reviewId,
    String? content,
    double? rating,
  ) async {
    updates++;
    if (mutationError != null) return DataError(mutationError!);
    final updated = ReviewResponse(
      idReview: reviewId,
      idTenant: review.idTenant,
      content: content ?? review.content,
      rating: rating ?? review.rating,
      createdAt: review.createdAt,
    );
    reviews = ListReviewResponse(data: [updated], userData: const [author]);
    return DataSuccess(updated);
  }

  @override
  Future<DataState<String>> deleteReview(String reviewId) async {
    deletes++;
    if (mutationError != null) return DataError(mutationError!);
    reviews = const ListReviewResponse(data: [], userData: []);
    return const DataSuccess('Đã xóa');
  }
}
