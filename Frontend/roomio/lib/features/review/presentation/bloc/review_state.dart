import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:roomio/features/review/domain/entities/review.dart';

enum ReviewStatus { initial, loading, success, failure }

enum ReviewMutationStatus { initial, loading, success, failure }

enum ReviewAction { post, update, delete }

class ReviewState extends Equatable {
  final ReviewStatus status;
  final ListReviewResponse reviews;
  final DioException? loadError;
  final ReviewMutationStatus mutationStatus;
  final ReviewAction? action;
  final String? reviewId;
  final DioException? mutationError;

  const ReviewState({
    this.status = ReviewStatus.initial,
    this.reviews = const ListReviewResponse(data: [], userData: []),
    this.loadError,
    this.mutationStatus = ReviewMutationStatus.initial,
    this.action,
    this.reviewId,
    this.mutationError,
  });

  bool get isLoading => status == ReviewStatus.loading;
  bool get isMutating => mutationStatus == ReviewMutationStatus.loading;

  ReviewState copyWith({
    ReviewStatus? status,
    ListReviewResponse? reviews,
    DioException? loadError,
    bool clearLoadError = false,
    ReviewMutationStatus? mutationStatus,
    ReviewAction? action,
    String? reviewId,
    bool clearReviewId = false,
    DioException? mutationError,
    bool clearMutationError = false,
  }) => ReviewState(
    status: status ?? this.status,
    reviews: reviews ?? this.reviews,
    loadError: clearLoadError ? null : loadError ?? this.loadError,
    mutationStatus: mutationStatus ?? this.mutationStatus,
    action: action ?? this.action,
    reviewId: clearReviewId ? null : reviewId ?? this.reviewId,
    mutationError: clearMutationError
        ? null
        : mutationError ?? this.mutationError,
  );

  @override
  List<Object?> get props => [
    status,
    reviews,
    loadError,
    mutationStatus,
    action,
    reviewId,
    mutationError,
  ];
}
