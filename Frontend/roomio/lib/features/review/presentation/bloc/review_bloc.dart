import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/review/domain/entities/review.dart';
import 'package:roomio/features/review/domain/usecases/delete_review.dart';
import 'package:roomio/features/review/domain/usecases/get_reviews.dart';
import 'package:roomio/features/review/domain/usecases/post_review.dart';
import 'package:roomio/features/review/domain/usecases/update_review.dart';
import 'review_event.dart';
import 'review_state.dart';

/// One instance belongs to one embedded room review section.
class ReviewBloc extends Bloc<ReviewEvent, ReviewState> {
  final GetReviewsUseCase _getReviews;
  final PostReviewUseCase _postReview;
  final UpdateReviewUseCase _updateReview;
  final DeleteReviewUseCase _deleteReview;
  final String roomId;
  int _revision = 0;

  ReviewBloc(
    this._getReviews,
    this._postReview,
    this._updateReview,
    this._deleteReview, {
    required this.roomId,
  }) : super(const ReviewState()) {
    on<ReviewsRequested>(_load);
    on<ReviewPostRequested>(_post);
    on<ReviewUpdateRequested>(_update);
    on<ReviewDeleteRequested>(_delete);
  }

  Future<void> _load(ReviewsRequested event, Emitter<ReviewState> emit) async {
    if (state.isMutating) return;
    final revision = ++_revision;
    emit(state.copyWith(status: ReviewStatus.loading, clearLoadError: true));
    final result = await _getReviews(roomId);
    if (emit.isDone || revision != _revision) return;
    if (result is DataSuccess<ListReviewResponse>) {
      emit(state.copyWith(status: ReviewStatus.success, reviews: result.data!));
    } else {
      emit(
        state.copyWith(status: ReviewStatus.failure, loadError: result.error),
      );
    }
  }

  void _start(
    ReviewAction action,
    Emitter<ReviewState> emit, {
    String? reviewId,
  }) {
    ++_revision;
    emit(
      state.copyWith(
        mutationStatus: ReviewMutationStatus.loading,
        action: action,
        reviewId: reviewId,
        clearReviewId: reviewId == null,
        clearMutationError: true,
      ),
    );
  }

  String? _validate(String? content, double? rating, {bool updating = false}) {
    if (updating && content == null && rating == null) {
      return 'Vui lòng thay đổi nội dung hoặc số sao.';
    }
    if (content != null &&
        (content.trim().isEmpty || content.runes.length > 255)) {
      return 'Nội dung đánh giá phải có từ 1 đến 255 ký tự.';
    }
    if (rating != null && (!rating.isFinite || rating < 1 || rating > 5)) {
      return 'Vui lòng chọn từ 1 đến 5 sao.';
    }
    return null;
  }

  void _invalid(String message, Emitter<ReviewState> emit) {
    emit(
      state.copyWith(
        mutationStatus: ReviewMutationStatus.failure,
        mutationError: DioException(
          requestOptions: RequestOptions(path: '/$roomId'),
          error: message,
        ),
      ),
    );
  }

  void _finish<T>(
    DataState<T> result,
    Emitter<ReviewState> emit,
    ListReviewResponse Function(T) apply,
  ) {
    if (emit.isDone) return;
    if (result is DataSuccess<T>) {
      ++_revision;
      emit(
        state.copyWith(
          reviews: apply(result.data as T),
          mutationStatus: ReviewMutationStatus.success,
        ),
      );
      // Reload author metadata and reconcile the server's active reviews.
      add(const ReviewsRequested());
    } else {
      emit(
        state.copyWith(
          mutationStatus: ReviewMutationStatus.failure,
          mutationError: result.error,
        ),
      );
    }
  }

  Future<void> _post(
    ReviewPostRequested event,
    Emitter<ReviewState> emit,
  ) async {
    if (state.isMutating || state.status != ReviewStatus.success) return;
    _start(ReviewAction.post, emit);
    final content = event.content.trim();
    final validation = _validate(content, event.rating);
    if (validation != null) return _invalid(validation, emit);
    final result = await _postReview(
      PostReviewParams(roomId: roomId, content: content, rating: event.rating),
    );
    _finish(result, emit, (review) {
      final existing = state.reviews.data.indexWhere(
        (item) => item.idTenant == review.idTenant,
      );
      final author = existing >= 0 && existing < state.reviews.userData.length
          ? state.reviews.userData[existing]
          : const UserReviewResponse(fullName: 'Bạn', avatar: null);
      return ListReviewResponse(
        data: List.unmodifiable([review, ...state.reviews.data]),
        userData: List.unmodifiable([author, ...state.reviews.userData]),
      );
    });
  }

  Future<void> _update(
    ReviewUpdateRequested event,
    Emitter<ReviewState> emit,
  ) async {
    if (state.isMutating || state.status != ReviewStatus.success) return;
    _start(ReviewAction.update, emit, reviewId: event.reviewId);
    final content = event.content?.trim();
    final validation = _validate(content, event.rating, updating: true);
    if (validation != null) return _invalid(validation, emit);
    final result = await _updateReview(
      UpdateReviewParams(
        reviewId: event.reviewId,
        content: content,
        rating: event.rating,
      ),
    );
    _finish(
      result,
      emit,
      (review) => ListReviewResponse(
        data: List.unmodifiable(
          state.reviews.data.map(
            (item) => item.idReview == review.idReview ? review : item,
          ),
        ),
        userData: state.reviews.userData,
      ),
    );
  }

  Future<void> _delete(
    ReviewDeleteRequested event,
    Emitter<ReviewState> emit,
  ) async {
    if (state.isMutating || state.status != ReviewStatus.success) return;
    _start(ReviewAction.delete, emit, reviewId: event.reviewId);
    final result = await _deleteReview(event.reviewId);
    _finish(result, emit, (_) {
      final data = <ReviewResponse>[];
      final users = <UserReviewResponse>[];
      // Preserve the API's data[i] <-> user_review[i] association.
      for (var i = 0; i < state.reviews.data.length; i++) {
        if (state.reviews.data[i].idReview == event.reviewId) continue;
        data.add(state.reviews.data[i]);
        users.add(
          i < state.reviews.userData.length
              ? state.reviews.userData[i]
              : const UserReviewResponse(fullName: 'Khách thuê', avatar: null),
        );
      }
      return ListReviewResponse(
        data: List.unmodifiable(data),
        userData: List.unmodifiable(users),
      );
    });
  }

  @override
  Future<void> close() {
    ++_revision;
    return super.close();
  }
}
