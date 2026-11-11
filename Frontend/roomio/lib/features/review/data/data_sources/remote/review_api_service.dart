import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:roomio/core/constants/constants.dart';
import 'package:roomio/features/review/data/models/review.dart';

part 'review_api_service.g.dart';

@RestApi(baseUrl: reviewAPIBaseUrl)
abstract class ReviewApiService {
  factory ReviewApiService(Dio dio, {String baseUrl}) = _ReviewApiService;

  @GET('/{room_id}')
  Future<HttpResponse<ListReviewModelResponse>> getReviewInARoom(
    @Path('room_id') String roomId,
  );

  @PATCH('/{review_id}')
  Future<HttpResponse<ReviewModelResponse>> updateReviewInARoom(
    @Path('review_id') String reviewId,
    @Body() ReviewModelRequest request,
  );

  @DELETE('/{review_id}')
  Future<HttpResponse<ReviewMessageModel>> deleteReviewInARoom(
    @Path('review_id') String reviewId,
  );

  @POST('/{room_id}')
  Future<HttpResponse<ReviewModelResponse>> postReviewInARoom(
    @Body() ReviewModelRequest request,
    @Path('room_id') String roomId,
  );
}
