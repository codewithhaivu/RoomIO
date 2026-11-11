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
import 'package:roomio/features/room/data/models/room_models.dart';
import 'package:roomio/injection_container.dart';
import 'room_test_support.dart';

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
  late RoomTestApi api;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({'role': 'LANDLORD'});
    await sl.reset();
    await initializeDependencies();
    api = RoomTestApi();
    await sl.unregister<Dio>();
    sl.registerSingleton<Dio>(api.dio);
    api.responseFor = (request) {
      if (request.uri.path.startsWith('/reviews/')) {
        return {'data': [], 'user_review': []};
      }
      if (request.uri.path.endsWith('/interior')) {
        return {
          'data': [
            {'id': 'interior-id', 'name': 'Giường ngủ'},
          ],
        };
      }
      if (request.uri.path.endsWith('/amenitie')) {
        return {
          'data': [
            {'id': 'amenity-id', 'name': 'Wifi'},
          ],
        };
      }
      if (request.path == '/me') {
        return {
          'rooms': [roomJson],
        };
      }
      return detailJson;
    };
  });
  tearDown(() async {
    await sl.reset();
    api.dispose();
  });

  for (final dark in [false, true]) {
    for (final route in [
      AppRoutes.myRooms,
      AppRoutes.roomForm,
      AppRoutes.searchRooms,
      AppRoutes.roomDetail,
    ]) {
      testWidgets(
        '$route renders at narrow width with ${dark ? "dark" : "light"} theme',
        (tester) async {
          debugDisableShadows = false;
          await tester.binding.setSurfaceSize(Size(dark ? 320 : 390, 844));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final previewKey = GlobalKey();
          final navigatorKey = GlobalKey<NavigatorState>();
          await tester.pumpWidget(
            RepaintBoundary(
              key: previewKey,
              child: MaterialApp(
                navigatorKey: navigatorKey,
                theme: dark ? AppTheme.dark : AppTheme.light,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(dark ? 1.3 : 1)),
                  child: child!,
                ),
                onGenerateRoute: AppRoutes.onGenerateRoute,
                home: const SizedBox.shrink(),
              ),
            ),
          );
          navigatorKey.currentState!.pushNamed(
            route,
            arguments: switch (route) {
              AppRoutes.roomForm => {'room': RoomModel.fromJson(roomJson)},
              AppRoutes.roomDetail => {'roomId': 'room-id'},
              _ => null,
            },
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (const bool.fromEnvironment('ROOM_PREVIEWS')) {
            await tester.runAsync(() async {
              final boundary =
                  previewKey.currentContext!.findRenderObject()
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 1);
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final directory = Directory('build/room_previews')
                ..createSync(recursive: true);
              File(
                '${directory.path}/${route.substring(1)}_${dark ? "dark" : "light"}.png',
              ).writeAsBytesSync(data!.buffer.asUint8List());
              image.dispose();
            });
          }
          // Scroll the main form/detail content as well to catch lower-page overflows.
          if (route == AppRoutes.roomForm &&
              const bool.fromEnvironment('ROOM_PREVIEWS')) {
            await tester.ensureVisible(find.text('Vị trí'));
            await tester.pumpAndSettle();
            await tester.runAsync(() async {
              final boundary =
                  previewKey.currentContext!.findRenderObject()
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 1);
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              File(
                'build/room_previews/room_form_location_${dark ? "dark" : "light"}.png',
              ).writeAsBytesSync(data!.buffer.asUint8List());
              image.dispose();
            });
          }
          final scrollable = find.byType(Scrollable).first;
          await tester.drag(scrollable, const Offset(0, -1300));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          debugDisableShadows = true;
        },
      );
    }
  }
}
