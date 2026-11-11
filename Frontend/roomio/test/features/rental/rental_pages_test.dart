import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:roomio/config/route/app_route.dart';
import 'package:roomio/config/theme/app_theme.dart';
import 'package:roomio/features/auth/presentation/pages/home_page.dart';
import 'package:roomio/features/rental/presentation/bloc/remote/remote_rental_bloc.dart';
import 'package:roomio/features/rental/presentation/pages/rentals_page.dart';
import 'package:roomio/features/rental/presentation/pages/rental_qr_code_page.dart';
import 'package:roomio/features/rental/presentation/pages/rental_verify_page.dart';
import 'package:roomio/features/rental/presentation/widgets/rental_cards.dart';
import 'package:roomio/injection_container.dart';
import '../room/room_test_support.dart' show detailJson;
import 'rental_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Be Vietnam Pro')
          ..addFont(rootBundle.load('assets/fonts/BeVietnamPro-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/BeVietnamPro-SemiBold.ttf'))
          ..addFont(rootBundle.load('assets/fonts/BeVietnamPro-Bold.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  late RentalTestApi api;
  final previewKey = GlobalKey();
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({'role': 'LANDLORD'});
    await sl.reset();
    await initializeDependencies();
    api = RentalTestApi();
    await sl.unregister<Dio>();
    sl.registerSingleton<Dio>(api.dio);
    api.responseFor = (request) {
      final path = request.uri.path;
      if (path.endsWith('/profile')) {
        return {
          'fullName': 'Nguyễn Văn An',
          'gender': 'Nam',
          'description': '',
          'is_verify': true,
        };
      }
      if (path.startsWith('/rooms/')) return detailJson;
      if (path.endsWith('/qr-code')) {
        return {'qr_token': '012345', 'expires_in_second': 60};
      }
      if (path.endsWith('/qr-code/verify')) {
        return {'message': 'Xác nhận thuê thành công', 'id_valid': true};
      }
      if (request.method == 'DELETE') return {'message': 'Đã kết thúc thuê'};
      if (path.endsWith('/my-rooms')) {
        return {
          'data': [rentedRoomJson],
        };
      }
      return {
        'data': [tenantJson],
      };
    };
  });
  tearDown(() async {
    await sl.reset();
    api.dispose();
  });

  Future<void> launch(
    WidgetTester tester, {
    String route = AppRoutes.rentals,
    Object? arguments,
    bool home = false,
    bool dark = false,
    double width = 390,
    double scale = 1,
    Route<dynamic>? Function(RouteSettings)? overrideRoute,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: previewKey,
        child: MaterialApp(
          theme: dark ? AppTheme.dark : AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          onGenerateRoute: (settings) =>
              overrideRoute?.call(settings) ??
              AppRoutes.onGenerateRoute(settings),
          home: home
              ? const HomePage()
              : Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        route,
                        arguments: arguments,
                      ),
                      child: const Text('Open'),
                    ),
                  ),
                ),
        ),
      ),
    );
    if (!home) await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> preview(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('RENTAL_PREVIEWS')) return;
    await tester.runAsync(() async {
      final boundary =
          previewKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('build/rental_previews')
        ..createSync(recursive: true);
      File(
        '${directory.path}/$name.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('Home opens landlord rental list', (tester) async {
    await launch(tester, home: true);
    await tester.ensureVisible(find.text('Khách đang thuê'));
    await tester.tap(find.text('Khách đang thuê'));
    await tester.pumpAndSettle();
    expect(find.byType(RentalsPage), findsOneWidget);
    expect(find.byType(TenantRentalCard), findsOneWidget);
  });

  testWidgets(
    'landlord ends a relation locally using rental id after confirmation',
    (tester) async {
      await launch(tester);
      await tester.tap(find.text('Kết thúc thuê'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quay lại'));
      await tester.pumpAndSettle();
      expect(
        api.requests.where((request) => request.method == 'DELETE'),
        isEmpty,
      );
      await tester.tap(find.text('Kết thúc thuê'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Kết thúc thuê'));
      await tester.pumpAndSettle();
      expect(
        api.requests.singleWhere((request) => request.method == 'DELETE').path,
        '/rental-id',
      );
      expect(
        api.requests.where((request) => request.method == 'GET').length,
        1,
      );
      expect(find.byType(TenantRentalCard), findsNothing);
    },
  );

  testWidgets(
    'missing relation id hides end action instead of using tenant or room id',
    (tester) async {
      api.responseFor = null;
      api.responseData = {
        'data': [tenantJson..remove('rental_id')],
      };
      await launch(tester);
      expect(find.byType(TenantRentalCard), findsOneWidget);
      expect(find.text('Kết thúc thuê'), findsNothing);
      expect(find.text('Xem phòng'), findsOneWidget);
    },
  );

  testWidgets(
    'tenant sees rented room without landlord actions and opens room detail',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({'role': 'TENANT'});
      await launch(tester);
      expect(find.byType(RentedRoomCard), findsOneWidget);
      expect(find.text('Kết thúc thuê'), findsNothing);
      await tester.tap(find.text('Xem phòng'));
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết phòng'), findsOneWidget);
      expect(api.requests.last.uri.path, '/rooms/room-id');
    },
  );

  testWidgets(
    'manual token requires six digits and preserves leading zero on POST',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({'role': 'TENANT'});
      await launch(tester, route: AppRoutes.rentalVerify);
      await tester.tap(find.text('Xác nhận thuê phòng'));
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng nhập đủ 6 chữ số.'), findsOneWidget);
      expect(api.requests, isEmpty);
      await tester.enterText(find.byType(TextFormField), '012345');
      await tester.tap(find.text('Xác nhận thuê phòng'));
      await tester.pumpAndSettle();
      expect(api.requests.single.method, 'POST');
      expect(api.requests.single.data, {'token': '012345'});
      expect(find.byType(RentalVerifyPage), findsNothing);
    },
  );

  testWidgets('false verification response stays on form and allows retry', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({'role': 'TENANT'});
    api.responseFor = null;
    api.responseData = {'message': 'Mã không hợp lệ', 'id_valid': false};
    await launch(tester, route: AppRoutes.rentalVerify);
    await tester.enterText(find.byType(TextFormField), '012345');
    await tester.tap(find.text('Xác nhận thuê phòng'));
    await tester.pumpAndSettle();
    expect(find.byType(RentalVerifyPage), findsOneWidget);
    expect(find.text('Mã không hợp lệ'), findsOneWidget);
    api.responseData = {'message': 'Confirmed', 'id_valid': true};
    await tester.tap(find.text('Xác nhận thuê phòng'));
    await tester.pumpAndSettle();
    expect(find.byType(RentalVerifyPage), findsNothing);
  });

  testWidgets(
    'scanner fills token but does not consume it until explicit confirmation',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({'role': 'TENANT'});
      await launch(
        tester,
        route: AppRoutes.rentalVerify,
        overrideRoute: (settings) => settings.name == AppRoutes.rentalScan
            ? MaterialPageRoute(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.pop(context, '012345'),
                    child: const Text('Scanned code'),
                  ),
                ),
              )
            : null,
      );
      await tester.tap(find.text('Quét mã QR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scanned code'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        '012345',
      );
      expect(api.requests, isEmpty);
    },
  );

  testWidgets('returning from successful verification reloads rented rooms', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({'role': 'TENANT'});
    await launch(tester);
    await tester.tap(find.text('Xác nhận thuê phòng'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '012345');
    await tester.tap(find.text('Xác nhận thuê phòng'));
    await tester.pumpAndSettle();
    expect(find.byType(RentalsPage), findsOneWidget);
    expect(
      api.requests
          .where((request) => request.uri.path.endsWith('/my-rooms'))
          .length,
      2,
    );
  });

  testWidgets(
    'QR hides at expiration and regeneration produces a fresh countdown',
    (tester) async {
      var now = DateTime.utc(2026, 10, 22);
      await sl.unregister<RemoteRentalBloc>();
      sl.registerFactory<RemoteRentalBloc>(
        () => rentalBloc(api.repository, now: () => now),
      );
      await launch(
        tester,
        route: AppRoutes.rentalQRCode,
        arguments: {'roomId': 'room-id', 'roomName': 'Room'},
      );
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('012345'), findsOneWidget);
      now = now.add(const Duration(seconds: 61));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('012345'), findsNothing);
      await tester.tap(find.text('Tạo mã mới'));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);
      expect(api.requests.length, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('room management opens QR with room id and name', (tester) async {
    await launch(tester, route: AppRoutes.roomDetail, arguments: 'room-id');
    await tester.ensureVisible(find.text('Tạo mã thuê phòng'));
    await tester.tap(find.text('Tạo mã thuê phòng'));
    await tester.pumpAndSettle();
    final page = tester.widget<RentalQRCodePage>(find.byType(RentalQRCodePage));
    expect(page.roomId, 'room-id');
    expect(page.roomName, 'Room');
    expect(api.requests.last.uri.path, '/rentals/room-id/qr-code');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('invalid QR arguments do not call backend', (tester) async {
    await launch(
      tester,
      route: AppRoutes.rentalQRCode,
      arguments: {'roomId': 10},
    );
    expect(find.textContaining('Thông tin phòng không hợp lệ'), findsOneWidget);
    expect(api.requests, isEmpty);
  });

  for (final route in [AppRoutes.rentalVerify, AppRoutes.rentalScan]) {
    testWidgets('landlord cannot open tenant route $route', (tester) async {
      await launch(tester, route: route);
      expect(find.text('Chức năng này dành cho khách thuê.'), findsOneWidget);
      expect(api.requests, isEmpty);
    });
  }

  testWidgets('tenant cannot generate landlord QR via a route argument', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({'role': 'TENANT'});
    await launch(
      tester,
      route: AppRoutes.rentalQRCode,
      arguments: {'roomId': 'room-id', 'roomName': 'Room', 'isLandlord': true},
    );
    expect(find.text('Chức năng này dành cho chủ trọ.'), findsOneWidget);
    expect(api.requests, isEmpty);
  });

  testWidgets('signed-out visitor cannot load rentals', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await launch(tester);
    expect(find.text('Vui lòng đăng nhập để tiếp tục.'), findsOneWidget);
    expect(api.requests, isEmpty);
  });

  testWidgets('scanner has a manual fallback on unsupported desktop', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({'role': 'TENANT'});
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await launch(tester, route: AppRoutes.rentalScan);
    expect(
      find.textContaining('Thiết bị này chưa hỗ trợ quét QR'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('list network error supports retry to empty state', (
    tester,
  ) async {
    api.error = DioException(
      requestOptions: RequestOptions(),
      type: DioExceptionType.connectionError,
    );
    await launch(tester);
    expect(
      find.text('Không thể kết nối máy chủ. Vui lòng kiểm tra mạng.'),
      findsOneWidget,
    );
    api.error = null;
    api.responseFor = null;
    api.responseData = {'data': []};
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có khách đang thuê phòng.'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    for (final route in [
      AppRoutes.rentals,
      AppRoutes.rentalVerify,
      AppRoutes.rentalQRCode,
    ]) {
      testWidgets(
        'layout $route ${dark ? "dark" : "light"} at 320px with large text',
        (tester) async {
          FlutterSecureStorage.setMockInitialValues({
            'role': route == AppRoutes.rentalVerify ? 'TENANT' : 'LANDLORD',
          });
          debugDisableShadows = false;
          await launch(
            tester,
            route: route,
            arguments: route == AppRoutes.rentalQRCode
                ? {'roomId': 'room-id', 'roomName': 'Phòng gần trường đại học'}
                : null,
            dark: dark,
            width: 320,
            scale: 1.3,
          );
          expect(tester.takeException(), isNull);
          await preview(
            tester,
            '${route.substring(1)}_${dark ? "dark" : "light"}',
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          debugDisableShadows = true;
        },
      );
    }
    testWidgets(
      'tenant list ${dark ? "dark" : "light"} at 320px with large text',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({'role': 'TENANT'});
        await launch(tester, dark: dark, width: 320, scale: 1.3);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
