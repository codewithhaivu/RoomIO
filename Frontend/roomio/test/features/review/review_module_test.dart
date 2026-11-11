import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/review/data/data_sources/remote/review_api_service.dart';
import 'package:roomio/features/review/data/models/review.dart';
import 'package:roomio/features/review/data/repository/review_repository_impl.dart';
import 'package:roomio/features/review/domain/entities/review.dart';
import 'package:roomio/features/review/domain/repository/review_repository.dart';
import 'package:roomio/features/review/domain/usecases/get_reviews.dart';
import 'package:roomio/features/review/domain/usecases/post_review.dart';
import 'package:roomio/features/review/domain/usecases/update_review.dart';
import 'package:roomio/features/review/domain/usecases/delete_review.dart';
import 'package:roomio/features/review/presentation/bloc/review_bloc.dart';
import 'package:roomio/features/review/presentation/bloc/review_event.dart';
import 'package:roomio/features/review/presentation/bloc/review_state.dart';
import 'package:roomio/features/review/presentation/widgets/room_review_section.dart';
import 'package:roomio/features/review/presentation/widgets/review_input_dialog.dart';
import 'package:roomio/injection_container.dart';
import 'review_test_support.dart';

Future<void> load(ReviewBloc bloc) async {
  final loaded = bloc.stream.firstWhere(
    (state) => state.status == ReviewStatus.success,
  );
  bloc.add(const ReviewsRequested());
  await loaded;
}

void main() {
  group('Review data contract', () {
    late ReviewTestApi api;
    setUp(() => api = ReviewTestApi());
    tearDown(() => api.dio.close(force: true));

    test(
      'GET maps string/numeric ratings, dates and aligned author entities',
      () async {
        api.data = {
          'data': [reviewJson(), reviewJson(id: 'review-2', rating: 5)],
          'user_review': [
            {'full_name': 'An', 'avatar': null},
            {'full_name': 'Bình', 'avatar': ''},
          ],
        };
        final result = await api.repository.getReviews('room-1');
        expect(result, isA<DataSuccess<ListReviewResponse>>());
        expect(result.data!.data.first.rating, 4.5);
        expect(result.data!.data.last.rating, 5.0);
        expect(
          result.data!.data.first.createdAt,
          DateTime.utc(2026, 10, 27, 8),
        );
        expect(result.data!.data.first, isNot(isA<ReviewModelResponse>()));
        expect(result.data!.userData.last.fullName, 'Bình');
        expect(api.requests.single.method, 'GET');
        expect(api.requests.single.path, '/room-1');
      },
    );

    test(
      'POST sends string rating; PATCH sends a body and omits absent fields',
      () async {
        api.data = reviewJson();
        api.statusCode = 201;
        expect(
          await api.repository.postReview('room-1', 'Phòng sạch', 4.5),
          isA<DataSuccess<ReviewResponse>>(),
        );
        expect(api.requests.last.method, 'POST');
        expect(api.requests.last.path, '/room-1');
        expect(api.requests.last.data, {
          'content': 'Phòng sạch',
          'rating': '4.5',
        });
        api.statusCode = 200;
        expect(
          await api.repository.updateReview('review-1', null, 5),
          isA<DataSuccess<ReviewResponse>>(),
        );
        expect(api.requests.last.method, 'PATCH');
        expect(api.requests.last.path, '/review-1');
        expect(api.requests.last.data, {'rating': '5.0'});
        await api.repository.updateReview('review-1', 'Mới', null);
        expect(api.requests.last.data, {'content': 'Mới'});
      },
    );

    test('DELETE returns the backend message', () async {
      api.data = {'message': 'Xóa đánh giá thành công'};
      final result = await api.repository.deleteReview('review-1');
      expect(result.data, 'Xóa đánh giá thành công');
      expect(api.requests.single.method, 'DELETE');
      expect(api.requests.single.path, '/review-1');
    });

    test(
      'all four APIs preserve permission errors and response detail',
      () async {
        api.error = forbidden();
        final results = await Future.wait([
          api.repository.getReviews('room-1'),
          api.repository.postReview('room-1', 'Nội dung', 5),
          api.repository.updateReview('review-1', 'Mới', null),
          api.repository.deleteReview('review-1'),
        ]);
        for (final result in results) {
          expect(result.error, same(api.error));
          expect(result.error!.response!.statusCode, 403);
        }
      },
    );

    test(
      'malformed response becomes DataError instead of escaping into Bloc',
      () async {
        api.data = reviewJson(rating: 'not-a-number');
        final result = await api.repository.postReview('room-1', 'Nội dung', 5);
        expect(result, isA<DataError<ReviewResponse>>());
        expect(result.error!.error, isA<FormatException>());
      },
    );
  });

  group('ReviewBloc', () {
    late FakeReviewRepository repository;
    late ReviewBloc bloc;
    setUp(() {
      repository = FakeReviewRepository();
      bloc = repository.bloc('room-1');
    });
    tearDown(() => bloc.close());

    test('403 keeps existing reviews and allows retry', () async {
      await load(bloc);
      repository.mutationError = forbidden();
      final failed = bloc.stream.firstWhere(
        (state) => state.mutationStatus == ReviewMutationStatus.failure,
      );
      bloc.add(const ReviewPostRequested(content: 'Nhận xét', rating: 5));
      await failed;
      expect(bloc.state.reviews, reviewList);
      expect(bloc.state.status, ReviewStatus.success);
      expect(bloc.state.mutationError!.response!.statusCode, 403);
      repository.mutationError = null;
      final done = bloc.stream.firstWhere(
        (state) => state.mutationStatus == ReviewMutationStatus.success,
      );
      bloc.add(const ReviewPostRequested(content: 'Nhận xét', rating: 5));
      await done;
      expect(bloc.state.reviews.data.first.idReview, 'new-review');
    });

    test(
      'duplicate submissions are ignored while a write is pending',
      () async {
        await load(bloc);
        repository.pendingPost = Completer<DataState<ReviewResponse>>();
        final writing = bloc.stream.firstWhere((state) => state.isMutating);
        bloc.add(const ReviewPostRequested(content: 'Nhận xét', rating: 5));
        await writing;
        final failed = bloc.stream.firstWhere(
          (state) => state.mutationStatus == ReviewMutationStatus.failure,
        );
        bloc.add(const ReviewPostRequested(content: 'Nhận xét', rating: 5));
        bloc.add(const ReviewDeleteRequested(reviewId: 'review-1'));
        await Future<void>.delayed(Duration.zero);
        expect(repository.posts, 1);
        expect(repository.deletes, 0);
        repository.pendingPost!.complete(DataError(forbidden()));
        await failed;
      },
    );

    test('a stale GET cannot replace a newer refresh', () async {
      repository.deferLoads = true;
      bloc.add(const ReviewsRequested());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const ReviewsRequested());
      await Future<void>.delayed(Duration.zero);
      final loaded = bloc.stream.firstWhere(
        (state) => state.status == ReviewStatus.success,
      );
      repository.loads[1].complete(DataSuccess(reviewList));
      await loaded;
      repository.loads[0].complete(
        const DataSuccess(ListReviewResponse(data: [], userData: [])),
      );
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.reviews.data, [review]);
    });

    test(
      'successful write remains successful if subsequent refresh fails',
      () async {
        await load(bloc);
        repository.loadError = DioException(
          requestOptions: RequestOptions(path: '/room-1'),
          type: DioExceptionType.connectionError,
        );
        final failedRefresh = bloc.stream.firstWhere(
          (state) => state.status == ReviewStatus.failure,
        );
        bloc.add(const ReviewPostRequested(content: 'Nhận xét', rating: 5));
        await failedRefresh;
        expect(bloc.state.mutationStatus, ReviewMutationStatus.success);
        expect(bloc.state.reviews.data.first.idReview, 'new-review');
        expect(bloc.state.reviews.userData.first, author);
        expect(repository.posts, 1);
      },
    );

    test('update and delete reconcile reviews with their authors', () async {
      await load(bloc);
      final updated = bloc.stream.firstWhere(
        (state) =>
            state.status == ReviewStatus.success &&
            state.mutationStatus == ReviewMutationStatus.success,
      );
      bloc.add(
        const ReviewUpdateRequested(
          reviewId: 'review-1',
          content: 'Đã sửa',
          rating: 3,
        ),
      );
      await updated;
      final refreshed = bloc.stream.firstWhere(
        (state) => state.status == ReviewStatus.success && repository.gets >= 2,
      );
      await refreshed;
      expect(bloc.state.reviews.data.single.content, 'Đã sửa');
      expect(bloc.state.reviews.userData.single, author);
      final deleted = bloc.stream.firstWhere(
        (state) =>
            state.action == ReviewAction.delete &&
            state.mutationStatus == ReviewMutationStatus.success,
      );
      bloc.add(const ReviewDeleteRequested(reviewId: 'review-1'));
      await deleted;
      expect(bloc.state.reviews.data, isEmpty);
      expect(bloc.state.reviews.userData, isEmpty);
    });

    test('invalid drafts never reach the API', () async {
      await load(bloc);
      final failed = bloc.stream.firstWhere(
        (state) => state.mutationStatus == ReviewMutationStatus.failure,
      );
      bloc.add(const ReviewPostRequested(content: '   ', rating: 0));
      await failed;
      expect(repository.posts, 0);
      expect(bloc.state.reviews, reviewList);
    });
  });

  group('Embedded widgets', () {
    late FakeReviewRepository repository;
    setUp(() async {
      await sl.reset();
      repository = FakeReviewRepository();
      sl.registerFactoryParam<ReviewBloc, String, dynamic>(
        (roomId, _) => repository.bloc(roomId),
      );
    });
    tearDown(() => sl.reset());

    Future<void> showSection(
      WidgetTester tester, {
      String roomId = 'room-1',
      bool canPostReview = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RoomReviewSection(
                roomId: roomId,
                canPostReview: canPostReview,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'guests read reviews; signed-in tenants see management actions',
      (tester) async {
        await showSection(tester);
        expect(find.text('Phòng sạch'), findsOneWidget);
        expect(find.text('Viết đánh giá'), findsNothing);
        expect(find.byTooltip('Quản lý đánh giá'), findsNothing);
        await showSection(tester, canPostReview: true);
        expect(find.byTooltip('Quản lý đánh giá'), findsOneWidget);
      },
    );

    testWidgets(
      '403 leaves the draft open; successful retry closes and refreshes',
      (tester) async {
        await showSection(tester, canPostReview: true);
        await tester.tap(find.text('Viết đánh giá'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField),
          'Tôi từng thuê ở đây',
        );
        await tester.tap(find.byTooltip('5 sao'));
        repository.mutationError = forbidden();
        await tester.tap(find.text('Gửi đánh giá'));
        await tester.pumpAndSettle();
        expect(find.byType(ReviewInputDialog), findsOneWidget);
        expect(find.text('Tôi từng thuê ở đây'), findsOneWidget);
        expect(
          find.text(
            repository.mutationError!.response!.data['detail'] as String,
          ),
          findsOneWidget,
        );
        repository.mutationError = null;
        await tester.tap(find.text('Gửi đánh giá'));
        await tester.pumpAndSettle();
        expect(find.byType(ReviewInputDialog), findsNothing);
        expect(find.text('Tôi từng thuê ở đây'), findsOneWidget);
        expect(repository.posts, 2);
      },
    );

    for (final action in ['edit', 'delete']) {
      testWidgets(
        '$action delegates permission checks to backend and preserves reviews on 403',
        (tester) async {
          const message = 'Chỉ tác giả mới được sửa hoặc xóa đánh giá này.';
          repository.mutationError = forbidden();
          repository.mutationError!.response!.data = {'detail': message};
          await showSection(tester, canPostReview: true);
          await tester.ensureVisible(find.byTooltip('Quản lý đánh giá'));
          await tester.tap(find.byTooltip('Quản lý đánh giá'));
          await tester.pumpAndSettle();
          await tester.tap(
            find.text(action == 'edit' ? 'Sửa đánh giá' : 'Xóa đánh giá'),
          );
          await tester.pumpAndSettle();
          if (action == 'edit') {
            await tester.enterText(
              find.byType(TextFormField),
              'Bản sửa chưa lưu',
            );
            await tester.tap(find.text('Lưu thay đổi'));
            await tester.pumpAndSettle();
            expect(repository.updates, 1);
            expect(find.byType(ReviewInputDialog), findsOneWidget);
            expect(find.text('Bản sửa chưa lưu'), findsOneWidget);
          } else {
            await tester.tap(find.text('Xóa'));
            await tester.pumpAndSettle();
            expect(repository.deletes, 1);
            expect(find.byType(AlertDialog), findsNothing);
          }
          expect(find.text(message), findsOneWidget);
          expect(find.text('Phòng sạch'), findsOneWidget);
          expect(repository.reviews, reviewList);
          expect(repository.gets, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets('room changes replace the scoped Bloc and reload data', (
      tester,
    ) async {
      await showSection(tester);
      repository.reviews = const ListReviewResponse(data: [], userData: []);
      await showSection(tester, roomId: 'room-2');
      expect(find.text('Phòng sạch'), findsNothing);
      expect(find.text('Chưa có đánh giá nào cho phòng này.'), findsOneWidget);
      expect(repository.gets, 2);
    });

    testWidgets('review dialog fits a narrow viewport', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await showSection(tester, canPostReview: true);
      await tester.ensureVisible(find.text('Viết đánh giá'));
      await tester.tap(find.text('Viết đánh giá'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  test(
    'DI resolves review layers and creates an independent Bloc per section',
    () async {
      await sl.reset();
      addTearDown(() => sl.reset());
      await initializeDependencies();
      expect(sl<ReviewApiService>(), same(sl<ReviewApiService>()));
      expect(sl<ReviewRepository>(), isA<ReviewRepositoryImpl>());
      expect(sl<GetReviewsUseCase>(), isA<GetReviewsUseCase>());
      expect(sl<PostReviewUseCase>(), isA<PostReviewUseCase>());
      expect(sl<UpdateReviewUseCase>(), isA<UpdateReviewUseCase>());
      expect(sl<DeleteReviewUseCase>(), isA<DeleteReviewUseCase>());
      final first = sl<ReviewBloc>(param1: 'room-1');
      final second = sl<ReviewBloc>(param1: 'room-2');
      expect(first, isNot(same(second)));
      expect(first.roomId, 'room-1');
      expect(second.roomId, 'room-2');
      await first.close();
      await second.close();
    },
  );
}
