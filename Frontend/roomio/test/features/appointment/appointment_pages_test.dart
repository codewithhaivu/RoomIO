import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomio/config/route/app_route.dart';
import 'package:roomio/config/theme/app_theme.dart';
import 'package:roomio/features/appointment/data/models/appointment.dart';
import 'package:roomio/features/appointment/presentation/pages/appointment_form_page.dart';
import 'package:roomio/features/appointment/presentation/pages/appointments_page.dart';
import 'package:roomio/features/appointment/presentation/widgets/appointment_card.dart';
import 'package:roomio/features/appointment/presentation/widgets/appointment_date_time.dart';
import 'package:roomio/features/appointment/presentation/widgets/appointment_status_badge.dart';
import 'package:roomio/features/auth/presentation/pages/home_page.dart';
import 'package:roomio/injection_container.dart';
import '../room/room_test_support.dart' show detailJson;
import 'appointment_test_support.dart';

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
  final previewKey = GlobalKey();
  late AppointmentTestApi api;
  late Map<String, dynamic> data;
  late DateTime future;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({'role': 'CUSTOMER'});
    await sl.reset();
    await initializeDependencies();
    api = AppointmentTestApi();
    await sl.unregister<Dio>();
    sl.registerSingleton<Dio>(api.dio);
    future = DateTime.now().toUtc().add(const Duration(days: 2));
    data = appointmentJson..['meet_at'] = future.toIso8601String();
    api.responseFor = (options) {
      if (options.uri.path.endsWith('/profile')) {
        return {
          'fullName': 'Nguyễn Văn An',
          'gender': 'Nam',
          'description': 'Khách thuê',
          'is_verify': true,
        };
      }
      if (options.uri.path.contains('/rooms/')) return detailJson;
      if (options.method == 'GET') {
        return {
          'data': [data],
        };
      }
      if (options.method == 'POST') return data;
      return {'message': 'Đã cập nhật lịch hẹn'};
    };
  });
  tearDown(() async {
    await sl.reset();
    api.dispose();
  });

  Future<void> launch(
    WidgetTester tester, {
    String route = AppRoutes.appointments,
    Object? arguments,
    bool home = false,
    bool dark = false,
    double width = 390,
    double textScale = 1,
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
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          onGenerateRoute: AppRoutes.onGenerateRoute,
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

  Future<void> pickDate(WidgetTester tester) async {
    await tester.tap(find.text('Chọn ngày và giờ'));
    await tester.pumpAndSettle();
    final date = appointmentVietnamTime(future);
    tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(DateTime(date.year, date.month, date.day));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chọn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chọn'));
    await tester.pumpAndSettle();
  }

  Future<void> preview(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('APPOINTMENT_PREVIEWS')) return;
    await tester.runAsync(() async {
      final boundary =
          previewKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('build/appointment_previews')
        ..createSync(recursive: true);
      File(
        '${directory.path}/$name.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('room detail starts booking with fixed room id and room name', (
    tester,
  ) async {
    await launch(tester, route: AppRoutes.roomDetail, arguments: 'room-id');
    await tester.tap(find.text('Đặt lịch xem phòng'));
    await tester.pumpAndSettle();
    final page = tester.widget<AppointmentFormPage>(
      find.byType(AppointmentFormPage),
    );
    expect(page.roomId, 'room-id');
    expect(page.roomName, 'Room');
    expect(page.initialAppointment, isNull);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('notification route displays the matching handled appointment', (
    tester,
  ) async {
    data['status'] = 'CONFIRMED';
    await launch(tester, arguments: {'appointmentId': data['id_appointment']});
    expect(find.byType(AppointmentCard), findsOneWidget);
    expect(find.text('Đã xác nhận'), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
  });

  testWidgets('validates date, creates booking and returns to room detail', (
    tester,
  ) async {
    await launch(
      tester,
      route: AppRoutes.appointmentForm,
      arguments: {'roomId': 'room-id', 'roomName': 'Phòng gần trường đại học'},
    );
    await tester.tap(find.text('Gửi lịch hẹn'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng chọn ngày và giờ xem phòng.'), findsOneWidget);
    expect(api.requests, isEmpty);
    await pickDate(tester);
    await tester.tap(find.text('Gửi lịch hẹn'));
    await tester.pumpAndSettle();
    expect(find.byType(AppointmentFormPage), findsNothing);
    final request = api.requests.single;
    expect(request.method, 'POST');
    expect(request.data['id_room'], 'room-id');
    final date = appointmentVietnamTime(
      DateTime.parse(request.data['meet_at']),
    );
    expect(date.hour, 9);
    expect(date.minute, 0);
    expect(date.day, appointmentVietnamTime(future).day);
  });

  testWidgets('create conflict retains selected time and allows retry', (
    tester,
  ) async {
    await launch(
      tester,
      route: AppRoutes.appointmentForm,
      arguments: {'roomId': 'room-id', 'roomName': 'Phòng gần trường đại học'},
    );
    await pickDate(tester);
    final options = RequestOptions(path: '/appointments/');
    api.error = DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: options,
        statusCode: 409,
        data: {'detail': 'Lịch hẹn bị trùng'},
      ),
    );
    await tester.tap(find.text('Gửi lịch hẹn'));
    await tester.pumpAndSettle();
    expect(find.byType(AppointmentFormPage), findsOneWidget);
    expect(find.text('Lịch hẹn bị trùng'), findsOneWidget);
    expect(find.text('Chọn ngày và giờ'), findsNothing);
    api.error = null;
    await tester.tap(find.text('Gửi lịch hẹn'));
    await tester.pumpAndSettle();
    expect(api.requests.length, 2);
    expect(find.byType(AppointmentFormPage), findsNothing);
  });

  testWidgets(
    'tenant edits existing time and merges the result without another GET',
    (tester) async {
      await launch(tester);
      expect(find.text('Đổi lịch'), findsOneWidget);
      expect(find.text('Quản lý lịch hẹn'), findsNothing);
      await tester.tap(find.text('Đổi lịch'));
      await tester.pumpAndSettle();
      expect(
        find.text('${appointmentTime(future)} · ${appointmentDate(future)}'),
        findsOneWidget,
      );
      await tester.tap(find.text('Lưu lịch hẹn'));
      await tester.pumpAndSettle();
      final patch = api.requests.singleWhere(
        (request) => request.method == 'PATCH',
      );
      expect(patch.path, '/appointment-id');
      expect(patch.data['id_room'], 'room-id');
      expect(DateTime.parse(patch.data['meet_at']), future);
      expect(
        api.requests.where((request) => request.method == 'GET').length,
        1,
      );
    },
  );

  testWidgets('tenant cancellation requires confirmation and uses DELETE', (
    tester,
  ) async {
    await launch(tester);
    await tester.tap(find.text('Hủy lịch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quay lại'));
    await tester.pumpAndSettle();
    expect(
      api.requests.where((request) => request.method == 'DELETE'),
      isEmpty,
    );
    await tester.tap(find.text('Hủy lịch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(
      api.requests.where((request) => request.method == 'DELETE').single.path,
      '/appointment-id',
    );
    expect(api.requests.where((request) => request.method == 'GET').length, 1);
    expect(find.byType(AppointmentCard), findsNothing);
    await tester.tap(find.text('Đã xử lý'));
    await tester.pumpAndSettle();
    expect(find.byType(AppointmentCard), findsNothing);
  });

  for (final action in ['CONFIRMED', 'REJECTED']) {
    testWidgets(
      'landlord $action moves the item to handled locally without another GET',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({'role': 'LANDLORD'});
        await launch(tester);
        expect(find.text('Đổi lịch'), findsNothing);
        expect(find.text('Hủy lịch'), findsNothing);
        await tester.tap(
          find.text(action == 'CONFIRMED' ? 'Đồng ý' : 'Từ chối'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Xác nhận'));
        await tester.pumpAndSettle();
        expect(
          api.requests.singleWhere((request) => request.method == 'PATCH').path,
          '/appointment-id/$action',
        );
        expect(
          api.requests.where((request) => request.method == 'GET').length,
          1,
        );
        expect(find.byType(AppointmentCard), findsNothing);
        expect(find.text('Không có lịch hẹn chờ xử lý.'), findsOneWidget);
        await tester.tap(find.text('Đã xử lý'));
        await tester.pumpAndSettle();
        expect(
          find.text(action == 'CONFIRMED' ? 'Đã xác nhận' : 'Đã từ chối'),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(AppointmentCard),
            matching: find.byWidgetPredicate(
              (widget) => widget is ButtonStyleButton,
            ),
          ),
          findsNothing,
        );
        final badge = find.byType(AppointmentStatusBadge);
        final label = tester.widget<Text>(
          find.descendant(of: badge, matching: find.byType(Text)),
        );
        expect(
          label.style!.color,
          action == 'CONFIRMED' ? Colors.green.shade800 : Colors.red.shade800,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final role in ['CUSTOMER', 'LANDLORD']) {
    testWidgets(
      'processed appointments are read-only for $role and CANCELLED is not displayed',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({'role': role});
        api.responseFor = null;
        api.responseData = {
          'data': [
            {
              ...data,
              'id_appointment': 'confirmed-id',
              'name_room': 'Confirmed room',
              'status': 'CONFIRMED',
            },
            {
              ...data,
              'id_appointment': 'rejected-id',
              'name_room': 'Rejected room',
              'status': 'REJECTED',
            },
            {
              ...data,
              'id_appointment': 'cancelled-id',
              'name_room': 'Cancelled room',
              'status': 'CANCELLED',
            },
          ],
        };
        await launch(tester);
        expect(find.byType(AppointmentCard), findsNothing);
        await tester.tap(find.text('Đã xử lý'));
        await tester.pumpAndSettle();
        expect(find.text('Đã xác nhận'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Đã từ chối'),
          150,
          scrollable: find.descendant(
            of: find.byKey(const ValueKey(false)),
            matching: find.byType(Scrollable),
          ),
        );
        expect(find.text('Đã từ chối'), findsOneWidget);
        expect(find.text('Cancelled room'), findsNothing);
        expect(find.text('Đánh dấu hoàn tất'), findsNothing);
        expect(
          find.descendant(
            of: find.byType(AppointmentCard),
            matching: find.byWidgetPredicate(
              (widget) => widget is ButtonStyleButton,
            ),
          ),
          findsNothing,
        );
      },
    );
  }

  testWidgets(
    'failed landlord action keeps item pending and enables retry without reloading',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({'role': 'LANDLORD'});
      await launch(tester);
      api.error = DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.connectionError,
      );
      await tester.tap(find.text('Từ chối'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
      expect(find.byType(AppointmentCard), findsOneWidget);
      expect(find.text('Chờ phản hồi'), findsOneWidget);
      expect(
        api.requests.where((request) => request.method == 'GET').length,
        1,
      );
      api.error = null;
      await tester.tap(find.text('Từ chối'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
      expect(find.byType(AppointmentCard), findsNothing);
      expect(
        api.requests.where((request) => request.method == 'PATCH').length,
        2,
      );
      expect(
        api.requests.where((request) => request.method == 'GET').length,
        1,
      );
    },
  );

  testWidgets('room-scoped list excludes appointments for other rooms', (
    tester,
  ) async {
    api.responseData = {
      'data': [
        data,
        {
          ...data,
          'id_appointment': 'other-id',
          'id_room': 'other-room',
          'name_room': 'Other room',
        },
      ],
    };
    api.responseFor = null;
    await launch(tester, arguments: {'roomId': 'room-id'});
    expect(find.byType(AppointmentCard), findsOneWidget);
    expect(find.text('Other room'), findsNothing);
  });

  testWidgets('empty and network-error list states support recovery', (
    tester,
  ) async {
    api.responseFor = null;
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
    api.responseData = {'data': []};
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Tìm phòng để đặt lịch'), findsOneWidget);
  });

  testWidgets('invalid arguments fail safely without calling API', (
    tester,
  ) async {
    await launch(
      tester,
      route: AppRoutes.appointmentForm,
      arguments: {'roomId': 123},
    );
    expect(
      find.textContaining('Thông tin lịch hẹn không hợp lệ'),
      findsOneWidget,
    );
    expect(api.requests, isEmpty);
  });

  testWidgets('landlord cannot open booking form through a direct route', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({'role': 'LANDLORD'});
    await launch(
      tester,
      route: AppRoutes.appointmentForm,
      arguments: {'roomId': 'room-id', 'roomName': 'Room', 'isLandlord': false},
    );
    expect(find.text('Chức năng này dành cho khách thuê.'), findsOneWidget);
    expect(find.byType(AppointmentFormPage), findsNothing);
    expect(api.requests, isEmpty);
  });

  testWidgets('signed-out visitor cannot load appointments', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await launch(tester);
    expect(find.text('Vui lòng đăng nhập để tiếp tục.'), findsOneWidget);
    expect(api.requests, isEmpty);
  });

  testWidgets('Home opens the appointment list', (tester) async {
    await launch(tester, home: true);
    await tester.ensureVisible(find.text('Lịch hẹn xem phòng'));
    await tester.tap(find.text('Lịch hẹn xem phòng'));
    await tester.pumpAndSettle();
    expect(find.byType(AppointmentsPage), findsOneWidget);
  });

  for (final dark in [false, true]) {
    for (final role in ['CUSTOMER', 'LANDLORD']) {
      testWidgets(
        'list layout: $role, ${dark ? "dark" : "light"}, 320px and large text',
        (tester) async {
          FlutterSecureStorage.setMockInitialValues({'role': role});
          debugDisableShadows = false;
          await launch(tester, dark: dark, width: 320, textScale: 1.3);
          await tester.ensureVisible(find.byType(AppointmentCard));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await preview(
            tester,
            'list_${role.toLowerCase()}_${dark ? "dark" : "light"}',
          );
          debugDisableShadows = true;
        },
      );
    }

    testWidgets(
      'form layout: ${dark ? "dark" : "light"}, 320px and large text',
      (tester) async {
        debugDisableShadows = false;
        await launch(
          tester,
          route: AppRoutes.appointmentForm,
          arguments: {
            'roomId': 'room-id',
            'roomName': 'Phòng có tên dài tại khu vực gần trường đại học',
          },
          dark: dark,
          width: 320,
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
        await preview(tester, 'form_${dark ? "dark" : "light"}');
        debugDisableShadows = true;
      },
    );
  }

  testWidgets('past time in edit form is rejected until a new date is chosen', (
    tester,
  ) async {
    final old = AppointmentModelResponse.fromJson(
      data
        ..['meet_at'] = DateTime.now()
            .toUtc()
            .subtract(const Duration(days: 1))
            .toIso8601String(),
    );
    await launch(tester, route: AppRoutes.appointmentForm, arguments: old);
    await tester.tap(find.text('Lưu lịch hẹn'));
    await tester.pumpAndSettle();
    expect(
      find.text('Vui lòng chọn thời gian trong tương lai.'),
      findsOneWidget,
    );
    expect(api.requests, isEmpty);
  });
}
