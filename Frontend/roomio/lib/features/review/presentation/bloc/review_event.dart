import 'package:equatable/equatable.dart';

abstract class ReviewEvent extends Equatable {
  const ReviewEvent();

  @override
  List<Object?> get props => [];
}

class ReviewsRequested extends ReviewEvent {
  const ReviewsRequested();
}

class ReviewPostRequested extends ReviewEvent {
  final String content;
  final double rating;

  const ReviewPostRequested({required this.content, required this.rating});

  @override
  List<Object?> get props => [content, rating];
}

class ReviewUpdateRequested extends ReviewEvent {
  final String reviewId;
  final String? content;
  final double? rating;

  const ReviewUpdateRequested({
    required this.reviewId,
    this.content,
    this.rating,
  });

  @override
  List<Object?> get props => [reviewId, content, rating];
}

class ReviewDeleteRequested extends ReviewEvent {
  final String reviewId;

  const ReviewDeleteRequested({required this.reviewId});

  @override
  List<Object?> get props => [reviewId];
}
