import 'package:roomio/features/review/domain/entities/review.dart';

class ReviewModelResponse extends ReviewResponse {
  const ReviewModelResponse({
    required super.idReview,
    required super.idTenant,
    required super.content,
    required super.rating,
    required super.createdAt,
  });

  factory ReviewModelResponse.fromJson(Map<String, dynamic> json) {
    final rawRating = json['rating'];
    final rating = rawRating is num
        ? rawRating.toDouble()
        : double.parse(rawRating as String);
    if (!rating.isFinite) throw const FormatException('Invalid review rating');
    return ReviewModelResponse(
      idReview: json['id_review'] as String,
      idTenant: json['id_tenant'] as String,
      content: json['content'] as String,
      rating: rating,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  ReviewResponse toEntity() => ReviewResponse(
    idReview: idReview,
    idTenant: idTenant,
    content: content,
    rating: rating,
    createdAt: createdAt,
  );
}

class ReviewModelRequest extends ReviewRequest {
  const ReviewModelRequest({required super.content, required super.rating});

  Map<String, dynamic> toJson() => {
    if (content != null) 'content': content,
    // The backend request schema represents ratings as strings.
    if (rating != null) 'rating': rating.toString(),
  };
}

class UserReviewModelResponse extends UserReviewResponse {
  const UserReviewModelResponse({
    required super.fullName,
    required super.avatar,
  });

  factory UserReviewModelResponse.fromJson(Map<String, dynamic> json) =>
      UserReviewModelResponse(
        fullName: json['full_name'] as String,
        avatar: json['avatar'] as String?,
      );

  UserReviewResponse toEntity() =>
      UserReviewResponse(fullName: fullName, avatar: avatar);
}

class ListReviewModelResponse extends ListReviewResponse {
  const ListReviewModelResponse({
    required List<ReviewModelResponse> super.data,
    required List<UserReviewModelResponse> super.userData,
  });

  factory ListReviewModelResponse.fromJson(Map<String, dynamic> json) =>
      ListReviewModelResponse(
        data: (json['data'] as List<dynamic>)
            .map(
              (item) =>
                  ReviewModelResponse.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        userData: (json['user_review'] as List<dynamic>)
            .map(
              (item) => UserReviewModelResponse.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList(),
      );

  ListReviewResponse toEntity() => ListReviewResponse(
    data: List.unmodifiable(
      data.cast<ReviewModelResponse>().map((item) => item.toEntity()),
    ),
    userData: List.unmodifiable(
      userData.cast<UserReviewModelResponse>().map((item) => item.toEntity()),
    ),
  );
}

class ReviewMessageModel {
  final String message;
  const ReviewMessageModel({required this.message});

  factory ReviewMessageModel.fromJson(Map<String, dynamic> json) =>
      ReviewMessageModel(message: json['message'] as String);
}
