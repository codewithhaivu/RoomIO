import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomio/config/route/app_route.dart';
import 'package:roomio/config/theme/app_theme.dart';
import 'package:roomio/features/auth/presentation/pages/home_page.dart';
import 'package:roomio/features/room/presentation/pages/room_detail_page.dart';
import 'package:roomio/features/room/presentation/pages/room_form_page.dart';
import 'package:roomio/features/room/presentation/pages/search_rooms_page.dart';
import 'package:roomio/features/room/presentation/widgets/room_card.dart';
import 'package:roomio/features/profile/presentation/widget/avatar_picker_widget.dart';
import 'package:roomio/features/profile/domain/entities/profile.dart';
import 'package:roomio/injection_container.dart';
import 'room_test_support.dart';
import 'room_location_test_support.dart';
import 'room_places_test_support.dart';
import 'package:roomio/features/room/domain/repository/room_places_repository.dart';
import 'package:roomio/features/room/domain/repository/room_location_repository.dart';
import 'package:roomio/features/room/domain/entities/room_location_error.dart';
import 'package:roomio/features/room/domain/entities/room_place_suggestion.dart';
import 'package:roomio/features/room/data/data_sources/remote/goong_places_api_service.dart';
import 'package:roomio/features/room/data/repository/room_places_repository_impl.dart';
import 'goong_test_data.dart';

Finder input(String label) => find.ancestor(
  of: find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  ),
  matching: find.byType(TextFormField),
);

void main() {
  late RoomTestApi api;
  late FakeRoomLocationRepository device;
  late FakeRoomPlacesRepository places;
  var status = 'AVAILABLE';
  Map<String, dynamic> profile() => {
    'fullName': 'Nguyen Van A',
    'gender': 'Nam',
    'description': 'Hello',
    'avatar': 'https://example.com/avatar.jpg',
    'is_verify': true,
  };

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({'role': 'LANDLORD'});
    await sl.reset();
    await initializeDependencies();
    device = FakeRoomLocationRepository();
    await sl.unregister<RoomLocationRepository>();
    sl.registerSingleton<RoomLocationRepository>(device);
    places = FakeRoomPlacesRepository();
    await sl.unregister<RoomPlacesRepository>();
    sl.registerSingleton<RoomPlacesRepository>(places);
    api = RoomTestApi();
    await sl.unregister<Dio>();
    sl.registerSingleton<Dio>(api.dio);
    status = 'AVAILABLE';
    api.responseFor = (request) {
      final path = request.uri.path;
      if (path.startsWith('/reviews/')) {
        return {'data': [], 'user_review': []};
      }
      if (path.endsWith('/locations')) {
        return {
          'data': [
            {'location_id': 'thu-duc-id', 'name_district': 'Thủ Đức'},
            {'location_id': 'quan-1-id', 'name_district': 'Quận 1'},
          ],
        };
      }
      if (path.endsWith('/interior')) {
        return {
          'data': [
            {'id': 'interior-id', 'name': 'Bed'},
          ],
        };
      }
      if (path.endsWith('/amenitie')) {
        return {
          'data': [
            {'id': 'amenity-id', 'name': 'Wifi'},
          ],
        };
      }
      if (path.endsWith('/upload-avatar')) {
        return {
          'image_url': 'https://example.com/new-avatar.jpg',
          'public_id': 'new-avatar',
        };
      }
      if (path.endsWith('/profile')) return profile();
      if (path.endsWith('/me')) {
        return {
          'rooms': [roomJson..['status'] = status],
        };
      }
      if (path.endsWith('/RENTED')) {
        status = 'RENTED';
        return {'Message': 'Updated'};
      }
      if (path.endsWith('/nearby/position') ||
          path.endsWith('/nearby/district')) {
        return {
          'rooms': [nearbyJson],
        };
      }
      if (path.endsWith('/room-id')) {
        return detailJson..['room'] = (roomJson..['status'] = status);
      }
      return roomJson;
    };
  });

  tearDown(() async {
    await sl.reset();
    api.dispose();
  });

  Future<void> launch(
    WidgetTester tester, {
    String? route,
    Object? arguments,
    bool home = false,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        onGenerateRoute: AppRoutes.onGenerateRoute,
        home: home
            ? const HomePage()
            : Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      route!,
                      arguments: arguments,
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
      ),
    );
    if (!home) {
      await tester.tap(find.text('Open'));
    }
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String label, String value) async {
    await tester.ensureVisible(input(label));
    await tester.enterText(input(label), value);
  }

  testWidgets(
    'tenant Home uses GPS and opens room detail without management actions',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({'role': 'CUSTOMER'});
      await launch(tester, home: true);
      await tester.ensureVisible(find.text('Tìm phòng'));
      await tester.tap(find.text('Tìm phòng'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchRoomsPage), findsOneWidget);
      expect(find.text('Vĩ độ (latitude)'), findsNothing);
      expect(find.text('Kinh độ (longitude)'), findsNothing);
      await tester.tap(find.text('Vị trí của bạn'));
      await tester.pumpAndSettle();
      expect(device.gpsCalls, 1);
      expect(api.requests.last.queryParameters, {
        'latitude': 10.8,
        'longitude': 106.7,
        'radius': 10.0,
      });
      await tester.ensureVisible(find.text('Room'));
      await tester.pumpAndSettle();
      expect(find.text('Cách 1.50 km'), findsOneWidget);
      await tester.tap(find.text('Room'));
      await tester.pumpAndSettle();
      expect(find.byType(RoomDetailPage), findsOneWidget);
      expect(find.text('Quản lý phòng'), findsNothing);
      expect(find.text('Landlord'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'address search geocodes on submit and radius reuses selected location',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({'role': 'CUSTOMER'});
      await launch(tester, route: AppRoutes.searchRooms);
      final field = find.byKey(const ValueKey('room-location-search'));
      await tester.enterText(field, 'Đại học Thủ Đức');
      await tester.pumpAndSettle();
      expect(device.queries, isEmpty);
      expect(api.requests.map((request) => request.path), ['/locations']);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(device.queries, ['Đại học Thủ Đức']);
      await tester.ensureVisible(find.text('3 km'));
      await tester.tap(find.text('3 km'));
      await tester.pumpAndSettle();
      expect(api.requests.last.queryParameters, {
        'latitude': 10.8,
        'longitude': 106.7,
        'radius': 3.0,
      });
      expect(device.queries.length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('API suggestions filter locally and search by selected area', (
    tester,
  ) async {
    await launch(tester, route: AppRoutes.searchRooms);
    expect(device.queries, isEmpty);
    expect(api.requests.map((request) => request.path), ['/locations']);
    final field = find.byKey(const ValueKey('room-location-search'));
    await tester.enterText(field, 'tHủ');
    await tester.pumpAndSettle();
    expect(find.text('Quận 1'), findsNothing);
    expect(api.requests.length, 1);
    await tester.ensureVisible(find.text('Thủ Đức'));
    await tester.tap(find.text('Thủ Đức'));
    await tester.pumpAndSettle();
    expect(device.queries, isEmpty);
    expect(api.requests.last.path, '/nearby/district');
    expect(api.requests.last.queryParameters, {
      'location_id': 'thu-duc-id',
      'district': 'Thủ Đức',
      'radius': 10.0,
    });
    await tester.ensureVisible(find.text('3 km'));
    await tester.tap(find.text('3 km'));
    await tester.pumpAndSettle();
    expect(api.requests.last.queryParameters, {
      'location_id': 'thu-duc-id',
      'district': 'Thủ Đức',
      'radius': 3.0,
    });
    await tester.scrollUntilVisible(field, -250);
    await tester.enterText(field, 'Quận 1');
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(api.requests.last.queryParameters['location_id'], 'quan-1-id');
    expect(api.requests.where((r) => r.path == '/locations').length, 1);
    expect(device.queries, isEmpty);
  });

  testWidgets(
    'denied GPS permission displays recovery without calling room API',
    (tester) async {
      device.failure = RoomLocationIssue.permissionDeniedForever;
      await launch(tester, route: AppRoutes.searchRooms);
      await tester.tap(find.text('Vị trí của bạn'));
      await tester.pumpAndSettle();
      expect(api.requests.map((request) => request.path), ['/locations']);
      await tester.ensureVisible(find.text('Mở cài đặt'));
      await tester.tap(find.text('Mở cài đặt'));
      await tester.pumpAndSettle();
      expect(device.settingsOpened, [RoomLocationSettings.app]);
      device.failure = null;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(api.requests.last.path, '/nearby/position');
    },
  );

  testWidgets('suggestion failure shows retry without hardcoded locations', (
    tester,
  ) async {
    api.error = DioException(
      requestOptions: RequestOptions(path: '/locations'),
      type: DioExceptionType.connectionError,
    );
    await launch(tester, route: AppRoutes.searchRooms);
    expect(find.text('Thủ Đức'), findsNothing);
    await tester.ensureVisible(find.text('Thử lại'));
    api.error = null;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Thủ Đức'));
    expect(find.text('Thủ Đức'), findsOneWidget);
    expect(api.requests.where((r) => r.path == '/locations').length, 2);
    await tester.enterText(
      find.byKey(const ValueKey('room-location-search')),
      'Không có khu vực này',
    );
    await tester.pumpAndSettle();
    expect(api.requests.length, 2);
    expect(find.text('Thủ Đức'), findsNothing);
    expect(
      find.text('Không có khu vực phù hợp với tên đã nhập.'),
      findsOneWidget,
    );
  });

  testWidgets('landlord Home opens my rooms, changes status and reloads list', (
    tester,
  ) async {
    await launch(tester, home: true);
    await tester.ensureVisible(find.text('Danh sách phòng'));
    await tester.tap(find.text('Danh sách phòng'));
    await tester.pumpAndSettle();
    expect(find.byType(RoomCard), findsOneWidget);
    await tester.ensureVisible(find.text('Đổi trạng thái'));
    await tester.tap(find.text('Đổi trạng thái'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đã cho thuê'));
    await tester.pumpAndSettle();
    expect(find.text('Đã cho thuê'), findsOneWidget);
    expect(api.requests.where((r) => r.path == '/me').length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'editing prefills form, selects catalogs by name and retains existing photos',
    (tester) async {
      await launch(tester, route: AppRoutes.myRooms);
      await tester.ensureVisible(find.text('Sửa phòng'));
      await tester.tap(find.text('Sửa phòng'));
      await tester.pumpAndSettle();
      expect(find.byType(RoomFormPage), findsOneWidget);
      expect(
        tester.widget<TextFormField>(input('Tên phòng')).controller!.text,
        'Room',
      );
      await enter(tester, 'Tên phòng', 'Updated room');
      await tester.ensureVisible(find.widgetWithText(FilterChip, 'Wifi'));
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Wifi'))
            .selected,
        isTrue,
      );
      await tester.tap(find.widgetWithText(FilterChip, 'Wifi'));
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();
      final update = api.requests.singleWhere((r) => r.method == 'PATCH');
      expect(update.data['name'], 'Updated room');
      expect(update.data['amenities'], isEmpty);
      expect(update.data['interiors'], ['interior-id']);
      expect(update.data['images'], [imageJson]);
      expect(api.requests.any((r) => r.path == '/images/upload'), isFalse);
      expect(api.requests.where((r) => r.path == '/me').length, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('create form requires fields and at least one photo', (
    tester,
  ) async {
    await launch(tester, route: AppRoutes.roomForm);
    await tester.tap(find.text('Đăng phòng'));
    await tester.pumpAndSettle();
    expect(api.requests.where((r) => r.method == 'POST'), isEmpty);
    await enter(tester, 'Tên phòng', 'New room');
    await enter(tester, 'Diện tích (m²)', '25');
    await enter(tester, 'Giá thuê (đ/tháng)', '4000000');
    await tester.ensureVisible(find.text('Sử dụng vị trí hiện tại'));
    await tester.tap(find.text('Sử dụng vị trí hiện tại'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng phòng'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng chọn ít nhất một ảnh phòng.'), findsOneWidget);
    expect(api.requests.where((r) => r.method == 'POST'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'form Goong V2 selection submits resolved coordinates and existing amenities',
    (tester) async {
      final goongRequests = <RequestOptions>[];
      final goongDio = Dio(BaseOptions(baseUrl: 'https://rsapi.goong.io/'));
      addTearDown(() => goongDio.close(force: true));
      goongDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            goongRequests.add(options);
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: options.uri.path.endsWith('/autocomplete')
                    ? goongAutocompleteJson
                    : goongDetailJson,
              ),
            );
          },
        ),
      );
      await sl.unregister<RoomPlacesRepository>();
      sl.registerSingleton<RoomPlacesRepository>(
        RoomPlacesRepositoryImpl(
          GoongPlacesApiService(dio: goongDio, apiKey: 'widget-test-key'),
        ),
      );
      await launch(tester, route: AppRoutes.myRooms);
      await tester.ensureVisible(find.text('Sửa phòng'));
      await tester.tap(find.text('Sửa phòng'));
      await tester.pumpAndSettle();
      expect(find.text('Vĩ độ (latitude)'), findsNothing);
      expect(find.text('Kinh độ (longitude)'), findsNothing);
      final address = find.byKey(const ValueKey('room-form-address'));
      await tester.ensureVisible(address);
      await tester.enterText(address, 'Võ Văn');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(goongRequests.single.queryParameters['input'], 'Võ Văn');
      expect(find.text('Goong Maps'), findsOneWidget);
      await tester.ensureVisible(
        find.text(FakeRoomPlacesRepository.suggestion.description),
      );
      await tester.tap(
        find.text(FakeRoomPlacesRepository.suggestion.description),
      );
      await tester.pumpAndSettle();
      expect(goongRequests.last.uri.path, '/v2/place/detail');
      expect(goongRequests.last.queryParameters['place_id'], 'goong-place-id');
      await tester.ensureVisible(find.widgetWithText(FilterChip, 'Wifi'));
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Wifi'))
            .selected,
        isTrue,
      );
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();
      final update = api.requests.singleWhere(
        (request) => request.method == 'PATCH',
      );
      expect(update.data['location'], {
        'name': FakeRoomPlacesRepository.selected.name,
        'latitude': 10.85,
        'longitude': 106.75,
      });
      expect(update.data['amenities'], ['amenity-id']);
      expect(update.data['interiors'], ['interior-id']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('form waits 350 ms and only searches at least three characters', (
    tester,
  ) async {
    await launch(tester, route: AppRoutes.roomForm);
    final address = find.byKey(const ValueKey('room-form-address'));
    await tester.ensureVisible(address);
    await tester.enterText(address, 'Võ');
    await tester.pump(const Duration(milliseconds: 400));
    expect(places.queries, isEmpty);
    await tester.enterText(address, 'VõV');
    await tester.pump(const Duration(milliseconds: 349));
    expect(places.queries, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(places.queries, ['VõV']);
    expect(
      find.text(FakeRoomPlacesRepository.suggestion.description),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('form shows an empty address result without crashing', (
    tester,
  ) async {
    places.suggestionsFor = (_) async => [];
    await launch(tester, route: AppRoutes.roomForm);
    final address = find.byKey(const ValueKey('room-form-address'));
    await tester.ensureVisible(address);
    await tester.enterText(address, 'Không tìm thấy');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(
      find.text('Chưa tìm thấy địa chỉ. Hãy nhập thêm tên đường hoặc phường.'),
      findsOneWidget,
    );
    expect(find.text('Goong Maps'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('form displays a retry action on address network failure', (
    tester,
  ) async {
    places.failure = RoomPlacesIssue.unavailable;
    await launch(tester, route: AppRoutes.roomForm);
    final address = find.byKey(const ValueKey('room-form-address'));
    await tester.ensureVisible(address);
    await tester.enterText(address, 'Võ Văn Ngân');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(
      find.text('Không tải được gợi ý. Vui lòng kiểm tra kết nối và thử lại.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Thử lại'));
    places.failure = null;
    await tester.tap(find.text('Thử lại'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(
      find.text(FakeRoomPlacesRepository.suggestion.description),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'editing a selected address invalidates old coordinates and blocks submission',
    (tester) async {
      await launch(tester, route: AppRoutes.myRooms);
      await tester.ensureVisible(find.text('Sửa phòng'));
      await tester.tap(find.text('Sửa phòng'));
      await tester.pumpAndSettle();
      final address = find.byKey(const ValueKey('room-form-address'));
      await tester.ensureVisible(address);
      await tester.enterText(address, 'New address');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();
      expect(
        api.requests.where((request) => request.method == 'PATCH'),
        isEmpty,
      );
      expect(
        find.text('Chọn địa chỉ từ gợi ý hoặc sử dụng vị trí hiện tại.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'form GPS reverse geocodes the address and submits matching coordinates',
    (tester) async {
      await launch(tester, route: AppRoutes.myRooms);
      await tester.ensureVisible(find.text('Sửa phòng'));
      await tester.tap(find.text('Sửa phòng'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sử dụng vị trí hiện tại'));
      await tester.tap(find.text('Sử dụng vị trí hiện tại'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextFormField>(
        find.byKey(const ValueKey('room-form-address')),
      );
      expect(field.controller!.text, '12 Đường Võ Văn Ngân, Thủ Đức');
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();
      final update = api.requests.singleWhere(
        (request) => request.method == 'PATCH',
      );
      expect(update.data['location'], {
        'name': '12 Đường Võ Văn Ngân, Thủ Đức',
        'latitude': 10.8,
        'longitude': 106.7,
      });
    },
  );

  testWidgets('tenant cannot open landlord form by route arguments', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({'role': 'CUSTOMER'});
    await launch(tester, route: AppRoutes.roomForm);
    expect(find.text('Chức năng này dành cho chủ trọ.'), findsOneWidget);
    expect(find.byType(RoomFormPage), findsNothing);
    expect(api.requests, isEmpty);
  });

  testWidgets('invalid detail route is handled without a cast exception', (
    tester,
  ) async {
    await launch(
      tester,
      route: AppRoutes.roomDetail,
      arguments: {'roomId': 123},
    );
    expect(
      find.text('Thông tin phòng không hợp lệ. Vui lòng mở lại từ danh sách.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile edit receives existing avatar and saves unchanged URL', (
    tester,
  ) async {
    await launch(tester, home: true);
    await tester.ensureVisible(find.text('Chỉnh sửa hồ sơ'));
    await tester.tap(find.text('Chỉnh sửa hồ sơ'));
    await tester.pumpAndSettle();
    final picker = tester.widget<AvatarPickerWidget>(
      find.byType(AvatarPickerWidget),
    );
    expect(picker.imageUrl, 'https://example.com/avatar.jpg');
    final avatar = tester.widget<CircleAvatar>(
      find.descendant(
        of: find.byType(AvatarPickerWidget),
        matching: find.byType(CircleAvatar),
      ),
    );
    expect(avatar.foregroundImage, isA<NetworkImage>());
    expect((avatar.foregroundImage as NetworkImage).url, picker.imageUrl);
    await tester.ensureVisible(find.text('Lưu thay đổi'));
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();
    final update = api.requests.singleWhere((r) => r.method == 'PATCH');
    expect(update.data['avatar'], 'https://example.com/avatar.jpg');
    expect(api.requests.any((r) => r.path.contains('upload-avatar')), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new profile photo previews locally then uploads before saving', (
    tester,
  ) async {
    await launch(
      tester,
      route: AppRoutes.updateProfile,
      arguments: {
        'role': 'LANDLORD',
        'profile': const ProfileEntity(
          name: 'Nguyen Van A',
          gender: 'Nam',
          avartarUrl: 'https://example.com/avatar.jpg',
        ),
      },
    );
    tester
        .widget<AvatarPickerWidget>(find.byType(AvatarPickerWidget))
        .onImageSelected(api.imageFile);
    await tester.pump();
    final avatar = tester.widget<CircleAvatar>(
      find.descendant(
        of: find.byType(AvatarPickerWidget),
        matching: find.byType(CircleAvatar),
      ),
    );
    expect(avatar.foregroundImage, isA<FileImage>());
    expect((avatar.foregroundImage as FileImage).file.path, api.imageFile.path);
    await tester.ensureVisible(find.text('Lưu thay đổi'));
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();
    expect(api.requests.map((r) => r.method), ['POST', 'PATCH']);
    expect(
      api.requests.last.data['avatar'],
      'https://example.com/new-avatar.jpg',
    );
    expect(tester.takeException(), isNull);
  });
}
