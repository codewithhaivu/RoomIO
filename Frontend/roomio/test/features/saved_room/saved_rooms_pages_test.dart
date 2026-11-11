import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomio/config/route/app_route.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/room/domain/repository/room_location_repository.dart';
import 'package:roomio/features/room/presentation/widgets/room_card.dart';
import 'package:roomio/features/saved_room/domain/repository/save_room_repository.dart';
import 'package:roomio/features/saved_room/presentation/cubit/saved_rooms_cubit.dart';
import 'package:roomio/features/saved_room/presentation/pages/saved_rooms_page.dart';
import 'package:roomio/injection_container.dart';
import '../room/room_test_support.dart' as room_support;
import '../room/room_location_test_support.dart';
import 'saved_room_test_support.dart';

void main() {
  late room_support.RoomTestApi api;
  late FakeSaveRoomRepository repository;
  late GlobalKey<NavigatorState> navigator;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({
      'role': 'CUSTOMER',
      'access_token': 'token',
    });
    await sl.reset();
    await initializeDependencies();
    repository = FakeSaveRoomRepository();
    await sl.unregister<SaveRoomRepository>();
    sl.registerSingleton<SaveRoomRepository>(repository);
    await sl.unregister<RoomLocationRepository>();
    sl.registerSingleton<RoomLocationRepository>(FakeRoomLocationRepository());
    api = room_support.RoomTestApi();
    await sl.unregister<Dio>();
    sl.registerSingleton<Dio>(api.dio);
    api.responseFor = (request) {
      if (request.path == '/locations') return {'data': []};
      if (request.path == '/nearby/position') {
        return {
          'rooms': [room_support.nearbyJson],
        };
      }
      if (request.path == '/profile') return {'fullName': 'Tenant'};
      return room_support.detailJson;
    };
    navigator = GlobalKey<NavigatorState>();
  });
  tearDown(() async {
    await sl.reset();
    api.dispose();
  });

  Future<void> open(WidgetTester tester, String route) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        onGenerateRoute: AppRoutes.onGenerateRoute,
        home: const SizedBox.shrink(),
      ),
    );
    navigator.currentState!.pushNamed(route);
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester) async {
    await open(tester, AppRoutes.searchRooms);
    await tester.tap(find.text('Vị trí của bạn'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Lưu phòng'));
  }

  testWidgets(
    'search and saved routes share one Cubit; unsave updates the covered search card',
    (tester) async {
      await search(tester);
      final shared = sl<SavedRoomsCubit>();
      await tester.tap(find.byTooltip('Lưu phòng'));
      await tester.pumpAndSettle();
      expect(repository.saves, [room.id]);
      expect(find.byTooltip('Bỏ lưu phòng'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(
        (tester.widget<Icon>(find.byIcon(Icons.favorite))).color,
        Colors.red,
      );
      expect(find.text('Chi tiết phòng'), findsNothing);
      await tester.tap(find.byTooltip('Phòng đã lưu'));
      await tester.pumpAndSettle();
      expect(find.byType(SavedRoomsPage), findsOneWidget);
      expect(sl<SavedRoomsCubit>(), same(shared));
      expect(find.byType(RoomCard), findsOneWidget);
      await tester.tap(find.byTooltip('Bỏ lưu phòng'));
      await tester.pumpAndSettle();
      expect(find.text('Bạn chưa lưu phòng nào.'), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Lưu phòng'));
      expect(find.byTooltip('Bỏ lưu phòng'), findsNothing);
      expect(shared.isClosed, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'heart changes before save completes; duplicate pending taps do not open detail',
    (tester) async {
      final pending = Completer<DataState<String>>();
      repository.onSave = (_) => pending.future;
      await search(tester);
      await tester.tap(find.byTooltip('Lưu phòng'));
      await tester.pump();
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      await tester.tap(find.byTooltip('Bỏ lưu phòng'));
      await tester.pump();
      expect(repository.saves, [room.id]);
      expect(find.text('Chi tiết phòng'), findsNothing);
      pending.complete(DataError(failure()));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Lưu phòng'), findsOneWidget);
      expect(find.text('Không thể thay đổi phòng đã lưu.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed unsave restores the card and shows a single error on the current route',
    (tester) async {
      await search(tester);
      await tester.tap(find.byTooltip('Lưu phòng'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Phòng đã lưu'));
      await tester.pumpAndSettle();
      final pending = Completer<DataState<String>>();
      repository.onUnsave = (_) => pending.future;
      await tester.tap(find.byTooltip('Bỏ lưu phòng'));
      await tester.pump();
      expect(find.text('Bạn chưa lưu phòng nào.'), findsOneWidget);
      expect(find.byType(RoomCard), findsNothing);
      pending.complete(DataError(failure()));
      await tester.pumpAndSettle();
      expect(find.byType(RoomCard), findsOneWidget);
      expect(find.byTooltip('Bỏ lưu phòng'), findsOneWidget);
      expect(find.text('Không thể thay đổi phòng đã lưu.'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('saved rooms support pull-to-refresh even when empty', (
    tester,
  ) async {
    await open(tester, AppRoutes.savedRooms);
    expect(find.text('Bạn chưa lưu phòng nào.'), findsOneWidget);
    repository.rooms = [room];
    await tester.drag(find.byType(ListView), const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(repository.gets, greaterThanOrEqualTo(2));
    expect(find.byType(RoomCard), findsOneWidget);
    await tester.tap(find.text(room.name));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết phòng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'initial fetch failure has retry and preserves empty list until recovery',
    (tester) async {
      repository.onGet = () async => DataError(failure(status: 500));
      await open(tester, AppRoutes.savedRooms);
      expect(find.text('Không thể thay đổi phòng đã lưu.'), findsOneWidget);
      repository.onGet = null;
      repository.rooms = [room];
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.byType(RoomCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Home entry opens saved-room route and landlord cannot enter it',
    (tester) async {
      await open(tester, AppRoutes.home);
      await tester.ensureVisible(find.text('Phòng đã lưu'));
      await tester.tap(find.text('Phòng đã lưu'));
      await tester.pumpAndSettle();
      expect(find.byType(SavedRoomsPage), findsOneWidget);
      FlutterSecureStorage.setMockInitialValues({'role': 'LANDLORD'});
      navigator.currentState!.pushNamed(AppRoutes.savedRooms);
      await tester.pumpAndSettle();
      expect(find.text('Chức năng này dành cho khách thuê.'), findsOneWidget);
      expect(repository.gets, 1);
    },
  );

  testWidgets('saved-room cards fit narrow screens with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repository.rooms = [room, otherRoom];
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        onGenerateRoute: AppRoutes.onGenerateRoute,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: const SizedBox.shrink(),
      ),
    );
    navigator.currentState!.pushNamed(AppRoutes.savedRooms);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
