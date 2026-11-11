import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomio/config/route/app_route.dart';
import 'package:roomio/config/route/push_notification_navigator.dart';
import 'package:roomio/features/chat/domain/repository/chat_repository.dart';
import 'package:roomio/features/notification/application/notification_device_sync.dart';
import 'package:roomio/injection_container.dart';

import '../chat/chat_test_support.dart';

void main() {
  const appointment = {
    'type': 'appointment',
    'appointment_id': 'appointment-1',
  };
  const chat = {'type': 'chat', 'sender_id': 'landlord-id'};
  late NotificationDeviceSync devices;
  late PushNotificationNavigator observer;
  late FakeChatRepository chats;
  late List<RouteSettings> opened;

  setUp(() async {
    await sl.reset();
    await initializeDependencies();
    await sl.unregister<ChatRepository>();
    chats = FakeChatRepository();
    sl.registerSingleton<ChatRepository>(chats);
    devices = sl<NotificationDeviceSync>();
    observer = sl<PushNotificationNavigator>();
    opened = [];
  });

  tearDown(() async {
    await chats.events.close();
    await sl.reset();
  });

  Future<void> launch(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: const Scaffold(body: Text('Startup')),
      navigatorObservers: [observer],
      onGenerateRoute: (settings) {
        opened.add(settings);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(body: Text(settings.name!)),
        );
      },
    ),
  );

  testWidgets('cold-start tap waits for the restored authenticated session', (
    tester,
  ) async {
    observer.onTap(appointment);
    await launch(tester);
    await tester.pumpAndSettle();
    expect(opened, isEmpty);

    devices.startSession(sessionToken('tenant-id'));
    observer.resolveStartup();
    await tester.pumpAndSettle();
    expect(opened.single.name, AppRoutes.appointments);
    expect(opened.single.arguments, {'appointmentId': 'appointment-1'});
  });

  testWidgets('a signed-out cold-start tap is discarded before a later login', (
    tester,
  ) async {
    observer.onTap(appointment);
    await launch(tester);
    observer.resolveStartup();
    devices.startSession(sessionToken('tenant-id'));
    observer.navigator!.pushNamed<void>(AppRoutes.home);
    await tester.pumpAndSettle();
    expect(opened.single.name, AppRoutes.home);
  });

  testWidgets('a tap during profile setup waits for Home', (tester) async {
    await launch(tester);
    observer.resolveStartup();
    devices.startSession(sessionToken('tenant-id'));
    observer.navigator!.pushNamed<void>(AppRoutes.createProfile);
    await tester.pumpAndSettle();
    observer.onTap(appointment);
    await tester.pumpAndSettle();
    expect(opened.single.name, AppRoutes.createProfile);

    observer.navigator!.pushNamed<void>(AppRoutes.home);
    await tester.pumpAndSettle();
    expect(opened.last.name, AppRoutes.appointments);
  });

  testWidgets(
    'chat tap opens the sender and foreground push is suppressed there',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await launch(tester);
      devices.startSession(sessionToken('tenant-id'));
      observer.resolveStartup();
      expect(observer.shouldShow(chat), isTrue);
      observer.onTap(chat);
      await tester.pumpAndSettle();

      expect(opened.single.name, AppRoutes.chat);
      expect(opened.single.arguments, chats.conversations.single);
      expect(observer.shouldShow(chat), isFalse);
      expect(
        observer.shouldShow({'type': 'chat', 'sender_id': 'other'}),
        isTrue,
      );
      expect(observer.shouldShow(appointment), isTrue);
      observer.onTap(chat);
      await tester.pumpAndSettle();
      expect(opened, hasLength(1));
    },
  );
}
