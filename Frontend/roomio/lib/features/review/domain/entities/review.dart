import 'package:equatable/equatable.dart';

class ReviewResponse extends Equatable {
  final String idReview;
  final String idTenant;
  final String content;
  final double rating;
  final DateTime createdAt;

  const ReviewResponse({
    required this.idReview,
    required this.idTenant,
    required this.content,
    required this.rating,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [idReview, idTenant, content, rating, createdAt];
}

class ReviewRequest extends Equatable {
  final String? content;
  final double? rating;

  const ReviewRequest({required this.content, required this.rating});

  @override
  List<Object?> get props => [content, rating];
}

class UserReviewResponse extends Equatable {
  final String fullName;
  final String? avatar;

  const UserReviewResponse({required this.fullName, required this.avatar});

  @override
  List<Object?> get props => [fullName, avatar];
}

class ListReviewResponse extends Equatable {
  final List<ReviewResponse> data;
  final List<UserReviewResponse> userData;

  const ListReviewResponse({required this.data, required this.userData});
  @override
  List<Object?> get props => [data, userData];
}
