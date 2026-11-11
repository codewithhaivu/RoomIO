import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomio/config/route/app_route.dart';
import 'package:roomio/features/review/presentation/widgets/review_input_dialog.dart';
import 'package:roomio/features/review/presentation/widgets/room_review_section.dart';
import 'package:roomio/features/room/presentation/bloc/remote/detail/remote_room_detail_bloc.dart';
import 'package:roomio/features/room/presentation/pages/room_detail_page.dart';
import 'package:roomio/injection_container.dart';
import '../room/room_test_support.dart';
import 'review_test_support.dart' show reviewJson;

void main() {
  late RoomTestApi api;
  late List<Map<String, dynamic>> reviews;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({
      'role': 'CUSTOMER',
      'access_token': 'account-access-token',
    });
    await sl.reset();
    await initializeDependencies();
    api = RoomTestApi();
    await sl.unregister<Dio>();
    sl.registerSingleton<Dio>(api.dio);
    reviews = [reviewJson()];
    api.responseFor = (request) {
      if (request.uri.path.startsWith('/reviews/')) {
        if (request.method == 'POST') {
          final body = request.data as Map<String, dynamic>;
          final created = {
            ...reviewJson(id: 'new-review'),
            'content': body['content'],
            'rating': body['rating'],
          };
          reviews.insert(0, created);
          return created;
        }
        return {
          'data': reviews,
          'user_review': [
            for (final _ in reviews)
              {'full_name': 'Khách thuê', 'avatar': null},
          ],
        };
      }
      return detailJson;
    };
  });

  tearDown(() async {
    await sl.reset();
    api.dispose();
  });

  Future<void> openRoom(WidgetTester tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        onGenerateRoute: AppRoutes.onGenerateRoute,
        home: const SizedBox.shrink(),
      ),
    );
    navigator.currentState!.pushNamed(
      AppRoutes.roomDetail,
      arguments: {'roomId': 'room-id'},
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'real room-detail route displays reviews below landlord and opens composer',
    (tester) async {
      await openRoom(tester);
      expect(find.byType(RoomReviewSection), findsOneWidget);
      expect(find.text('Đánh giá (1)'), findsOneWidget);
      expect(find.text('Phòng sạch'), findsOneWidget);
      expect(
        api.requests.where(
          (request) =>
              request.uri.path == '/reviews/room-id' && request.method == 'GET',
        ),
        hasLength(1),
      );
      await tester.ensureVisible(find.text('Viết đánh giá'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Đánh giá (1)')).dy,
        greaterThan(tester.getTopLeft(find.text('Thông tin chủ trọ')).dy),
      );
      await tester.tap(find.text('Viết đánh giá'));
      await tester.pumpAndSettle();
      expect(find.byType(ReviewInputDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tenant sees existing review actions and can submit without a profile ID',
    (tester) async {
      await openRoom(tester);
      expect(find.byTooltip('Quản lý đánh giá'), findsOneWidget);
      await tester.ensureVisible(find.text('Viết đánh giá'));
      await tester.tap(find.text('Viết đánh giá'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'Phòng ở rất thoải mái',
      );
      await tester.tap(find.byTooltip('5 sao'));
      await tester.tap(find.text('Gửi đánh giá'));
      await tester.pumpAndSettle();
      expect(find.byType(ReviewInputDialog), findsNothing);
      expect(find.text('Phòng ở rất thoải mái'), findsOneWidget);
      expect(find.text('Đánh giá (2)'), findsOneWidget);
      expect(find.byTooltip('Quản lý đánh giá'), findsNWidgets(2));
      final post = api.requests.singleWhere(
        (request) => request.method == 'POST',
      );
      expect(post.uri.path, '/reviews/room-id');
      expect(post.data, {'content': 'Phòng ở rất thoải mái', 'rating': '5.0'});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('landlord sees the embedded reviews without a compose button', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({
      'role': 'LANDLORD',
      'access_token': 'landlord-token',
    });
    await openRoom(tester);
    expect(find.text('Đánh giá (1)'), findsOneWidget);
    expect(find.text('Phòng sạch'), findsOneWidget);
    expect(find.text('Viết đánh giá'), findsNothing);
    expect(find.byTooltip('Quản lý đánh giá'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('public room detail loads reviews without a signed-in session', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => sl<RemoteRoomDetailBloc>(),
          child: const RoomDetailPage(roomId: 'room-id'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Phòng sạch'), findsOneWidget);
    expect(find.text('Viết đánh giá'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
